import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:drapemind_mobile/core/config/api_config.dart';
import 'package:drapemind_mobile/core/models/notification_model.dart';
import 'package:drapemind_mobile/core/models/realtime_models.dart';
import 'package:drapemind_mobile/core/services/events_socket_service.dart';
import 'package:drapemind_mobile/core/services/navigation_service.dart';
import 'package:drapemind_mobile/segundo_parcial/cu05_acceso/cu05_auth_service.dart';

class PushNotificationService extends ChangeNotifier
    with WidgetsBindingObserver {
  final AuthService _authService;
  final EventsSocketService _eventsService;
  StreamSubscription<RealtimeEvent>? _eventSubscription;

  List<AtelierNotification> _notifications = [];
  List<AtelierNotification> get notifications =>
      List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.leido).length;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _deviceToken;
  String? get deviceToken => _deviceToken;
  bool _registered = false;
  Completer<void>? _registration;
  String? _registeredIdentity, _lastAttemptIdentity;
  DateTime? _lastAttempt;
  int _generation = 0;
  Timer? _retry;

  bool get pushEnabled => _deviceToken != null && _registered;
  String? _owner;
  bool _disposed = false;
  bool _loggingOut = false;
  void _publish() {
    if (!_disposed) notifyListeners();
  }

  String? pushError;
  final List<StreamSubscription<dynamic>> _firebaseSubscriptions = [];

  Future<String?> _fetchFcmTokenWithRetry({int maxRetries = 1}) async {
    if (_disposed) return null;
    try {
      final token = await FirebaseMessaging.instance.getToken().timeout(
        const Duration(seconds: 8),
      );
      return _disposed || token == null || token.isEmpty ? null : token;
    } catch (_) {
      return null;
    }
  }

  Future<bool> enablePush() async {
    _isLoading = true;
    _publish();
    try {
      final messaging = FirebaseMessaging.instance;
      final status = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (status.authorizationStatus == AuthorizationStatus.denied) {
        _deviceToken = null;
        pushError =
            'Permite las notificaciones de DrapeMind en los ajustes del teléfono.';
        _isLoading = false;
        _publish();
        return false;
      }

      final token = await _fetchFcmTokenWithRetry(maxRetries: 4);
      if (token != null && token.isNotEmpty) {
        _deviceToken = token;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('dm_device_push_token', token);
      }
      await registerDeviceWithBackend();
      pushError = _registered
          ? null
          : 'No se pudo sincronizar con el servidor.';
      return _registered;
    } catch (e) {
      pushError =
          'No pudimos activar los avisos ($e). Revisa tu conexión e intenta nuevamente.';
      return false;
    } finally {
      _isLoading = false;
      if (!_disposed) _publish();
    }
  }

  Future<void> _refreshForAccount() async {
    final scope = _owner;
    if (scope == null ||
        !_authService.isAuthenticated ||
        _authService.isPlatformAdmin) {
      return;
    }
    try {
      if (_deviceToken == null || _deviceToken!.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        _deviceToken = prefs.getString('dm_device_push_token');
      }
      if (_deviceToken == null || _deviceToken!.isEmpty) {
        _deviceToken = await _fetchFcmTokenWithRetry(maxRetries: 3);
        if (_deviceToken != null && _deviceToken!.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('dm_device_push_token', _deviceToken!);
        }
      }
    } catch (e) {
      debugPrint(
        '[PushNotificationService] _refreshForAccount token error: $e',
      );
    }
    if (_disposed || scope != _owner) return;
    if (_authService.isAuthenticated) {
      _eventsService.connect();
    }
    await registerDeviceWithBackend();
    if (!_disposed && _authService.isAuthenticated) {
      await fetchNotifications();
    }
  }

  Future<void> _beforeLogout() async {
    _loggingOut = true;
    _generation++;
    await _registration?.future;
    await unregisterDeviceFromBackend();
    // Nota: Conservamos el token local para que el hardware mantenga su canal FCM
  }

  void _accountChanged() {
    final user = _authService.currentUser;
    final owner = user == null ? null : '${user.tenantId}_${user.id}';
    if (_disposed || owner == _owner) return;
    _loggingOut = false;
    _generation++;
    _owner = owner;
    _registered = false;
    _notifications = [];
    _recentNotificationTimestamps.clear();
    unawaited(_refreshForAccount());
    _isLoading = false;
    _publish();
  }

  PushNotificationService({
    required AuthService authService,
    required EventsSocketService eventsService,
  }) : _authService = authService,
       _eventsService = eventsService {
    WidgetsBinding.instance.addObserver(this);
    _retry = Timer.periodic(const Duration(seconds: 60), (_) {
      if (_authService.isAuthenticated &&
          !_authService.isPlatformAdmin &&
          !_disposed) {
        unawaited(registerDeviceWithBackend());
        unawaited(fetchNotifications());
      }
    });
    _authService.addListener(_accountChanged);
    _authService.beforeLogout.add(_beforeLogout);
    final user = _authService.currentUser;
    _owner = user == null ? null : '${user.tenantId}_${user.id}';
    _initDevice();
  }

  Future<void> _initDevice() async {
    final prefs = await SharedPreferences.getInstance();
    // Recuperar token previamente guardado si existe
    final cachedToken = prefs.getString('dm_device_push_token');
    if (cachedToken != null && cachedToken.isNotEmpty) {
      _deviceToken = cachedToken;
      debugPrint('[PushNotificationService] Token en caché cargado');
    }

    // Inicialización del SDK de Firebase Messaging en Android/iOS
    try {
      final messaging = FirebaseMessaging.instance;
      final permission = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint(
        '[PushNotificationService] Permiso notificaciones: ${permission.authorizationStatus}',
      );

      _firebaseSubscriptions.add(
        messaging.onTokenRefresh.listen((newToken) async {
          if (_disposed || newToken.isEmpty) return;
          debugPrint('[PushNotificationService] onTokenRefresh disparado');
          _deviceToken = newToken;
          final p = await SharedPreferences.getInstance();
          await p.setString('dm_device_push_token', newToken);
          await registerDeviceWithBackend();
        }),
      );

      final realFcmToken = await _fetchFcmTokenWithRetry(maxRetries: 4);
      if (realFcmToken != null && realFcmToken.isNotEmpty) {
        _deviceToken = realFcmToken;
        await prefs.setString('dm_device_push_token', realFcmToken);
      } else {
        debugPrint(
          '[PushNotificationService] getToken() pendiente o sin respuesta',
        );
      }

      _firebaseSubscriptions.add(
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          _handleFcmMessage(message);
        }),
      );

      _firebaseSubscriptions.add(
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          _handleNotificationTapFromBackground(message);
        }),
      );

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTapFromBackground(initialMessage);
      }
    } catch (e) {
      debugPrint(
        '[PushNotificationService] Firebase Messaging no disponible: $e',
      );
    }

    await registerDeviceWithBackend();
    if (_authService.isAuthenticated) {
      await fetchNotifications();
    }

    _listenRealtimeEvents();
    _accountChanged();
  }

  final Map<String, int> _recentNotificationTimestamps = {};

  bool _isDuplicateNotification(String key) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _recentNotificationTimestamps.removeWhere((_, time) => now - time > 60000);
    if (_recentNotificationTimestamps.containsKey(key)) {
      return true;
    }
    _recentNotificationTimestamps[key] = now;
    return false;
  }

  void _handleFcmMessage(RemoteMessage msg) {
    if (msg.data['action'] == 'DISMISS_NOTIFICATION') {
      final id = int.tryParse(msg.data['notification_id']?.toString() ?? '');
      if (id != null) {
        for (final item in _notifications) {
          if (item.id == id) item.leido = true;
        }
        _publish();
      }
      return;
    }

    final rawId =
        msg.data['notification_id']?.toString() ?? msg.messageId ?? '';
    final title =
        msg.notification?.title ??
        msg.data['title'] ??
        msg.data['titulo'] ??
        'Notificación Atelier';
    final body =
        msg.notification?.body ?? msg.data['body'] ?? msg.data['mensaje'] ?? '';
    final dedupeKey = rawId.isNotEmpty ? 'id_$rawId' : 'text_${title}_$body';

    if (_isDuplicateNotification(dedupeKey)) {
      debugPrint(
        '[PushNotificationService] FCM duplicado ignorado: $dedupeKey',
      );
      return;
    }

    final intId = int.tryParse(rawId) ?? Random().nextInt(1000000);
    if (_notifications.any((n) => n.id == intId && intId != 0)) {
      return;
    }

    final notifMap = {
      'id': intId,
      'titulo': title,
      'mensaje': body,
      'tipo': msg.data['type'] ?? msg.data['tipo'] ?? 'GENERAL',
      'data_payload': msg.data,
      'leido': false,
      'created_at': DateTime.now().toIso8601String(),
    };

    final newNotif = AtelierNotification.fromJson(notifMap);
    _notifications.insert(0, newNotif);
    _publish();

    // Mostrar aviso emergente dentro de la app si está abierta en primer plano
    final context = NavigationService.context;
    if (context != null && context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('$title\n$body'),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Ver',
            onPressed: () => _handleNotificationTapFromBackground(msg),
          ),
        ),
      );
    }
  }

  void _handleNotificationTapFromBackground(RemoteMessage msg) {
    final payload = msg.data;
    String screen =
        (payload['screen'] ?? payload['url'] ?? payload['enlace'] ?? '')
            .toString();
    if (screen.isEmpty) {
      final tipo = (payload['type'] ?? payload['tipo'] ?? '')
          .toString()
          .toUpperCase();
      if (tipo.contains('PEDIDO') ||
          tipo.contains('ORDER') ||
          tipo.contains('PAGO')) {
        screen = '/orders';
      } else if (tipo.contains('RESERVA')) {
        screen = '/reservations';
      } else if (tipo.contains('AI') || tipo.contains('ALTAIR')) {
        screen = '/chat';
      } else if (tipo.contains('CATALOG') || tipo.contains('PROMO')) {
        screen = '/catalog';
      } else {
        screen = '/notifications';
      }
    }
    NavigationService.navigateTo(screen: screen, data: payload);
  }

  void _listenRealtimeEvents() {
    _eventSubscription?.cancel();
    _eventSubscription = _eventsService.onEvent.listen((event) {
      _handleRealtimeEvent(event);
    });
  }

  void _handleRealtimeEvent(RealtimeEvent event) {
    if (!_authService.isAuthenticated) return;
    final payloadMap = event.raw;
    final origin = payloadMap['data'];
    if (origin is Map &&
        origin['tenant_id'] != null &&
        origin['tenant_id'].toString() !=
            _authService.currentUser?.tenantId.toString()) {
      return;
    }
    if (payloadMap['silent'] == true) return;
    if (event.type == 'notification') {
      final rawId = payloadMap['id']?.toString() ?? '';
      final title =
          payloadMap['title'] ?? payloadMap['titulo'] ?? 'Notificación';
      final body = payloadMap['body'] ?? payloadMap['mensaje'] ?? '';
      final dedupeKey = rawId.isNotEmpty ? 'id_$rawId' : 'text_${title}_$body';

      if (_isDuplicateNotification(dedupeKey)) {
        debugPrint(
          '[PushNotificationService] Evento WebSocket duplicado ignorado: $dedupeKey',
        );
        return;
      }

      final intId = int.tryParse(rawId) ?? Random().nextInt(1000000);
      if (_notifications.any((n) => n.id == intId && intId != 0)) {
        return;
      }

      final notifMap = {
        'id': intId,
        'titulo': title,
        'mensaje': body,
        'tipo':
            payloadMap['notification_type'] ?? payloadMap['tipo'] ?? 'GENERAL',
        'data_payload': payloadMap['data'] ?? payloadMap['payload'] ?? {},
        'leido': false,
        'created_at':
            payloadMap['created_at'] ?? DateTime.now().toIso8601String(),
      };

      final newNotif = AtelierNotification.fromJson(notifMap);
      _notifications.insert(0, newNotif);
      _publish();

      // No se crea modal superpuesto invasivo dentro de la app para no interrumpir la experiencia
    } else if (event.type == 'notification_dismissed') {
      // Silenciamiento tras lectura emitido desde un dispositivo hermano
      final rawId = payloadMap['notification_id'];
      if (rawId != null) {
        final notifId = int.tryParse(rawId.toString());
        if (notifId != null) {
          final index = _notifications.indexWhere((n) => n.id == notifId);
          if (index != -1) {
            _notifications[index].leido = true;
            _publish();
          }
        }
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_disposed) {
      unawaited(registerDeviceWithBackend());
      unawaited(fetchNotifications());
    }
  }

  Future<void> registerDeviceWithBackend() async {
    if (_disposed ||
        _loggingOut ||
        !_authService.isAuthenticated ||
        _authService.isPlatformAdmin) {
      return;
    }
    if (_registration != null) {
      await _registration!.future;
      if (_disposed) return;
    }
    if (_registration != null) return;
    final token = _authService.token, user = _authService.currentUser;
    if (token == null || user == null) return;
    final generation = _generation;
    final attempt = '${user.tenantId}:${user.id}:${_deviceToken ?? ""}';
    if (_registeredIdentity == attempt && _registered) return;
    if (_lastAttemptIdentity == attempt &&
        _lastAttempt != null &&
        DateTime.now().difference(_lastAttempt!).inSeconds < 20) {
      return;
    }
    _lastAttemptIdentity = attempt;
    _lastAttempt = DateTime.now();
    final done = Completer<void>();
    _registration = done;
    try {
      final prefs = await SharedPreferences.getInstance();
      _deviceToken ??= prefs.getString('dm_device_push_token');
      if (_deviceToken == null || _deviceToken!.isEmpty) {
        _deviceToken = await _fetchFcmTokenWithRetry(maxRetries: 2);
      }
      if (_deviceToken == null || generation != _generation || _disposed) {
        return;
      }
      await prefs.setString('dm_device_push_token', _deviceToken!);
      var deviceId = prefs.getString('dm_physical_device_id');
      if (deviceId == null) {
        deviceId = base64Url.encode(
          List<int>.generate(24, (_) => Random.secure().nextInt(256)),
        );
        await prefs.setString('dm_physical_device_id', deviceId);
      }
      String model = 'DrapeMind · ${Platform.operatingSystem}';
      try {
        final info = DeviceInfoPlugin();
        if (Platform.isAndroid) {
          final device = await info.androidInfo;
          model = '${device.brand} ${device.model}';
        } else if (Platform.isIOS) {
          final device = await info.iosInfo;
          model = device.model;
        }
      } catch (_) {
        /* Device details are optional. */
      }
      if (generation != _generation || _disposed) return;
      final response = await http
          .post(
            Uri.parse('${ApiConfig.apiV1Url}/devices/register'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'token': _deviceToken,
              'dispositivo_id': deviceId,
              'plataforma': Platform.operatingSystem,
              'modelo': model.substring(0, min(100, model.length)),
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (generation != _generation || _disposed) return;
      _registered = response.statusCode == 200;
      if (_registered) {
        _registeredIdentity = '${user.tenantId}:${user.id}:$_deviceToken';
      }
      pushError = _registered
          ? null
          : 'Tus avisos se actualizarán automáticamente al recuperar conexión.';
    } catch (_) {
      if (generation == _generation) {
        pushError =
            'Tus avisos se actualizarán automáticamente al recuperar conexión.';
      }
    } finally {
      if (identical(_registration, done)) _registration = null;
      done.complete();
      if (!_disposed) _publish();
    }
  }

  Future<void> unregisterDeviceFromBackend() async {
    final token = _authService.token;
    if (token == null || token.isEmpty || _deviceToken == null) return;

    try {
      final url = Uri.parse('${ApiConfig.apiV1Url}/devices/unregister');
      await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'token': _deviceToken}),
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint(
        '[PushNotificationService] Error desregistrando dispositivo: $e',
      );
    }
  }

  Future<void> fetchNotifications() async {
    final generation = _generation;
    final token = _authService.token;
    if (_disposed || token == null || token.isEmpty) return;

    _isLoading = true;
    _publish();

    try {
      final url = Uri.parse('${ApiConfig.apiV1Url}/notifications?limit=40');
      final res = await http
          .get(url, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 15));

      if (!_disposed &&
          generation == _generation &&
          res.statusCode == 200 &&
          token == _authService.token) {
        final Map<String, dynamic> data = jsonDecode(res.body);
        final List items = data['items'] ?? [];
        _notifications = items
            .map((x) => AtelierNotification.fromJson(x))
            .toList();
      }
    } catch (e) {
      debugPrint(
        '[PushNotificationService] Error consultando notificaciones: $e',
      );
    } finally {
      _isLoading = false;
      _publish();
    }
  }

  Future<void> markAsRead(int notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index].leido = true;
      _publish();
    }

    final token = _authService.token;
    if (token == null || token.isEmpty) return;

    try {
      final url = Uri.parse(
        '${ApiConfig.apiV1Url}/notifications/$notificationId/read',
      );
      await http.patch(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          if (_deviceToken != null) 'X-Device-Token': _deviceToken!,
        },
      );
    } catch (e) {
      debugPrint('[PushNotificationService] Error marcando leida: $e');
    }
  }

  Future<void> markAllAsRead() async {
    for (final notif in _notifications) {
      notif.leido = true;
    }
    _publish();

    final token = _authService.token;
    if (token == null || token.isEmpty) return;

    try {
      final url = Uri.parse('${ApiConfig.apiV1Url}/notifications/read-all');
      await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          if (_deviceToken != null) 'X-Device-Token': _deviceToken!,
        },
      );
    } catch (e) {
      debugPrint('[PushNotificationService] Error marcando todas leidas: $e');
    }
  }

  void onNotificationTapped(AtelierNotification notif) {
    markAsRead(notif.id);
    final screen = notif.dataPayload['screen']?.toString() ?? '/notifications';
    NavigationService.navigateTo(screen: screen, data: notif.dataPayload);
  }

  @override
  void dispose() {
    _disposed = true;
    _retry?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _authService.beforeLogout.remove(_beforeLogout);
    for (final subscription in _firebaseSubscriptions) {
      subscription.cancel();
    }
    _authService.removeListener(_accountChanged);
    _eventSubscription?.cancel();
    super.dispose();
  }
}
