import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';


import 'package:drapemind_mobile/core/config/api_config.dart';
import 'package:drapemind_mobile/core/models/notification_model.dart';
import 'package:drapemind_mobile/core/models/realtime_models.dart';
import 'package:drapemind_mobile/core/services/events_socket_service.dart';
import 'package:drapemind_mobile/core/services/navigation_service.dart';
import 'package:drapemind_mobile/paquetes/acceso_gestion_usuarios/datos/servicios/auth_service.dart';

class PushNotificationService extends ChangeNotifier {
  final AuthService _authService;
  final EventsSocketService _eventsService;
  StreamSubscription<RealtimeEvent>? _eventSubscription;

  List<AtelierNotification> _notifications = [];
  List<AtelierNotification> get notifications => List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.leido).length;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _deviceToken;
  String? get deviceToken => _deviceToken;

  PushNotificationService({
    required AuthService authService,
    required EventsSocketService eventsService,
  })  : _authService = authService,
        _eventsService = eventsService {
    _initDevice();
  }

  Future<void> _initDevice() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString('dm_device_push_token');
    if (token == null || token.isEmpty) {
      final rand = Random.secure();
      final bytes = List<int>.generate(24, (_) => rand.nextInt(256));
      final generated = base64Url.encode(bytes);
      token = 'fcm_android_${Platform.operatingSystem}_$generated';
      await prefs.setString('dm_device_push_token', token);
    }
    _deviceToken = token;

    // Inicialización del SDK de Firebase Messaging en Android/iOS
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final realFcmToken = await messaging.getToken();
      if (realFcmToken != null && realFcmToken.isNotEmpty) {
        _deviceToken = realFcmToken;
        await prefs.setString('dm_device_push_token', realFcmToken);
      }

      messaging.onTokenRefresh.listen((newToken) {
        _deviceToken = newToken;
        prefs.setString('dm_device_push_token', newToken);
        if (_authService.isAuthenticated) {
          registerDeviceWithBackend();
        }
      });

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _handleFcmMessage(message);
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleNotificationTapFromBackground(message);
      });

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTapFromBackground(initialMessage);
      }
    } catch (e) {
      debugPrint('[PushNotificationService] Firebase Messaging activo en canal local: $e');
    }

    if (_authService.isAuthenticated) {
      await registerDeviceWithBackend();
      await fetchNotifications();
    }

    _listenRealtimeEvents();
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
    final rawId = msg.data['notification_id']?.toString() ?? msg.messageId ?? '';
    final title = msg.notification?.title ?? msg.data['title'] ?? msg.data['titulo'] ?? 'Notificación Atelier';
    final body = msg.notification?.body ?? msg.data['body'] ?? msg.data['mensaje'] ?? '';
    final dedupeKey = rawId.isNotEmpty ? 'id_$rawId' : 'text_${title}_$body';

    if (_isDuplicateNotification(dedupeKey)) {
      debugPrint('[PushNotificationService] FCM duplicado ignorado: $dedupeKey');
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
    debugPrint('[PushNotificationService] Tap recibido en notificacion de fondo: ${msg.data}');
    final payload = msg.data;
    String screen = (payload['screen'] ?? payload['url'] ?? payload['enlace'] ?? '').toString();
    if (screen.isEmpty) {
      final tipo = (payload['type'] ?? payload['tipo'] ?? '').toString().toUpperCase();
      if (tipo.contains('PEDIDO') || tipo.contains('ORDER') || tipo.contains('PAGO')) {
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
    final payloadMap = event.raw;
    if (event.type == 'notification') {
      final rawId = payloadMap['id']?.toString() ?? '';
      final title = payloadMap['title'] ?? payloadMap['titulo'] ?? 'Notificación';
      final body = payloadMap['body'] ?? payloadMap['mensaje'] ?? '';
      final dedupeKey = rawId.isNotEmpty ? 'id_$rawId' : 'text_${title}_$body';

      if (_isDuplicateNotification(dedupeKey)) {
        debugPrint('[PushNotificationService] Evento WebSocket duplicado ignorado: $dedupeKey');
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
        'tipo': payloadMap['notification_type'] ?? payloadMap['tipo'] ?? 'GENERAL',
        'data_payload': payloadMap['data'] ?? payloadMap['payload'] ?? {},
        'leido': false,
        'created_at': payloadMap['created_at'] ?? DateTime.now().toIso8601String(),
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
      final url = Uri.parse('${ApiConfig.apiV1Url}/devices/register');
      await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'token': _deviceToken,
          'dispositivo_id': 'dm_${Platform.operatingSystem}_terminal',
          'plataforma': Platform.operatingSystem,
          'modelo': 'DrapeMind Atelier Client (${Platform.operatingSystemVersion})',
        }),
      );
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
      debugPrint('[PushNotificationService] Error desregistrando dispositivo: $e');
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

      if (res.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(res.body);
        final List items = data['items'] ?? [];
        _notifications = items.map((x) => AtelierNotification.fromJson(x)).toList();
      }
    } catch (e) {
      debugPrint('[PushNotificationService] Error consultando notificaciones: $e');
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
      final url = Uri.parse('${ApiConfig.apiV1Url}/notifications/$notificationId/read?originating_token=${_deviceToken ?? ""}');
      await http.patch(
        url,
        headers: {'Authorization': 'Bearer $token'},
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
      final url = Uri.parse('${ApiConfig.apiV1Url}/notifications/read-all?originating_token=${_deviceToken ?? ""}');
      await http.post(
        url,
        headers: {'Authorization': 'Bearer $token'},
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
    _eventSubscription?.cancel();
    super.dispose();
  }
}
