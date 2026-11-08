import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:drapemind_mobile/core/config/api_config.dart';
import 'package:drapemind_mobile/core/models/notification_model.dart';
import 'package:drapemind_mobile/core/models/realtime_models.dart';
import 'package:drapemind_mobile/core/services/events_socket_service.dart';
import 'package:drapemind_mobile/core/services/navigation_service.dart';
import 'package:drapemind_mobile/segundo_parcial/cu05_acceso/cu05_auth_service.dart';

class PushNotificationService extends ChangeNotifier {
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
  bool get pushEnabled => _deviceToken != null && _registered;
  String? _owner;
  bool _disposed = false;
  String? pushError;
  final List<StreamSubscription<dynamic>> _firebaseSubscriptions = [];
  Future<void> enablePush() async {
    try {
      final status = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (status.authorizationStatus == AuthorizationStatus.denied) {
        _deviceToken = null;
        pushError =
            'Permite las notificaciones de DrapeMind en los ajustes del teléfono.';
      } else {
        _deviceToken = await FirebaseMessaging.instance.getToken();
        await registerDeviceWithBackend();
      }
    } catch (_) {
      pushError =
          'No pudimos activar los avisos. Revisa tu conexión e intenta nuevamente.';
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> _refreshForAccount() async {
    final owner = _owner;
    if (owner == null ||
        !_authService.isAuthenticated ||
        _authService.isPlatformAdmin) {
      return;
    }
    try {
      final status = await FirebaseMessaging.instance.getNotificationSettings();
      _deviceToken = status.authorizationStatus == AuthorizationStatus.denied
          ? null
          : await FirebaseMessaging.instance.getToken();
    } catch (_) {
      pushError = 'No pudimos activar los avisos en este dispositivo.';
    }
    if (_disposed || owner != _owner) return;
    _eventsService.connect();
    await registerDeviceWithBackend();
    if (!_disposed && owner == _owner) await fetchNotifications();
  }

  Future<void> _beforeLogout() async {
    await unregisterDeviceFromBackend();
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
    _deviceToken = null;
  }

  void _accountChanged() {
    final user = _authService.currentUser;
    final owner = user == null ? null : '${user.tenantId}_${user.id}';
    if (owner == _owner) return;
    _owner = owner;
    _registered = false;
    _notifications = [];
    _recentNotificationTimestamps.clear();
    unawaited(_refreshForAccount());
    _isLoading = false;
    notifyListeners();
  }

  PushNotificationService({
    required AuthService authService,
    required EventsSocketService eventsService,
  }) : _authService = authService,
       _eventsService = eventsService {
    _authService.addListener(_accountChanged);
    _authService.beforeLogout.add(_beforeLogout);
    _initDevice();
  }

  Future<void> _initDevice() async {
    final prefs = await SharedPreferences.getInstance();
    // Only provider-issued tokens can receive push. Never invent a fallback token.
    await prefs.remove('dm_device_push_token');
    // Inicialización del SDK de Firebase Messaging en Android/iOS
    try {
      final messaging = FirebaseMessaging.instance;
      final permission = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final realFcmToken =
          permission.authorizationStatus == AuthorizationStatus.denied
          ? null
          : await messaging.getToken();
      if (realFcmToken != null && realFcmToken.isNotEmpty) {
        _deviceToken = realFcmToken;
        await prefs.setString('dm_device_push_token', realFcmToken);
      }

      _firebaseSubscriptions.add(
        messaging.onTokenRefresh.listen((newToken) async {
          final permission = await messaging.getNotificationSettings();
          if (_disposed ||
              permission.authorizationStatus == AuthorizationStatus.denied) {
            return;
          }
          _deviceToken = newToken;
          prefs.setString('dm_device_push_token', newToken);
          if (_authService.isAuthenticated) {
            registerDeviceWithBackend();
          }
        }),
      );

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
        '[PushNotificationService] Firebase no está disponible: ${e.runtimeType}',
      );
    }

    if (_authService.isAuthenticated) {
      await registerDeviceWithBackend();
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
    if (!_authService.isAuthenticated) return;
    final tenantId = int.tryParse(msg.data['tenant_id']?.toString() ?? '');
    if (tenantId == null) return;
    if (msg.data['action'] == 'DISMISS_NOTIFICATION') {
      if (tenantId == _authService.currentUser?.tenantId) {
        final id = int.tryParse(msg.data['notification_id']?.toString() ?? '');
        for (final item in _notifications) {
          if (item.id == id) item.leido = true;
        }
        notifyListeners();
      }
      return;
    }
    if (tenantId != _authService.currentUser?.tenantId) {
      final context = NavigationService.context;
      if (context != null &&
          context.mounted &&
          _authService.currentUser?.isUniversalCustomer == true) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(
              '${msg.data['tenant_name'] ?? 'Otra tienda'} · ${msg.data['title'] ?? 'Tienes un aviso'}',
            ),
            action: SnackBarAction(
              label: 'Abrir tienda',
              onPressed: () => _handleNotificationTapFromBackground(msg),
            ),
          ),
        );
      }
      return; // A different store's alert never enters the current store inbox.
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
    notifyListeners();

    // No se crea modal superpuesto invasivo dentro de la app para no interrumpir la experiencia
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
      notifyListeners();

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
            notifyListeners();
          }
        }
      }
    }
  }

  Future<void> registerDeviceWithBackend() async {
    final token = _authService.token;
    if (token == null || token.isEmpty || _deviceToken == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      var deviceId = prefs.getString('dm_physical_device_id');
      if (deviceId == null) {
        deviceId = base64Url.encode(
          List<int>.generate(24, (_) => Random.secure().nextInt(256)),
        );
        await prefs.setString('dm_physical_device_id', deviceId);
      }
      if (token != _authService.token) return;
      final url = Uri.parse('${ApiConfig.apiV1Url}/devices/register');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'token': _deviceToken,
          'dispositivo_id': deviceId,
          'plataforma': Platform.operatingSystem,
          'modelo': 'DrapeMind (${Platform.operatingSystemVersion})',
        }),
      );
      if (token == _authService.token) {
        _registered = response.statusCode == 200;
        pushError = _registered
            ? null
            : 'No pudimos vincular este dispositivo. Intenta nuevamente.';
        if (!_disposed) notifyListeners();
      }
    } catch (e) {
      debugPrint('[PushNotificationService] Error registrando dispositivo: $e');
    }
  }

  Future<void> unregisterDeviceFromBackend() async {
    final token = _authService.token;
    if (token == null || token.isEmpty || _deviceToken == null) return;

    try {
      final url = Uri.parse('${ApiConfig.apiV1Url}/devices/unregister');
      await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'token': _deviceToken}),
      );
    } catch (e) {
      debugPrint(
        '[PushNotificationService] Error desregistrando dispositivo: $e',
      );
    }
  }

  Future<void> fetchNotifications() async {
    final token = _authService.token;
    if (token == null || token.isEmpty) return;

    _isLoading = true;
    notifyListeners();

    try {
      final url = Uri.parse('${ApiConfig.apiV1Url}/notifications?limit=40');
      final res = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200 && token == _authService.token) {
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
      notifyListeners();
    }
  }

  Future<void> markAsRead(int notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index].leido = true;
      notifyListeners();
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
    notifyListeners();

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
    _authService.beforeLogout.remove(_beforeLogout);
    for (final subscription in _firebaseSubscriptions) {
      subscription.cancel();
    }
    _authService.removeListener(_accountChanged);
    _eventSubscription?.cancel();
    super.dispose();
  }
}
