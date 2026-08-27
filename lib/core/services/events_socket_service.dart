import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/api_config.dart';
import '../models/realtime_models.dart';
import 'auth_service.dart';

class EventsSocketService extends ChangeNotifier {
  final AuthService _authService;
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  int _reconnectAttempt = 0;

  final _eventStreamController = StreamController<RealtimeEvent>.broadcast();
  Stream<RealtimeEvent> get onEvent => _eventStreamController.stream;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  EventsSocketService({required AuthService authService}) : _authService = authService;

  void connect() {
    final token = _authService.token;
    if (token == null || token.isEmpty || _isConnected) return;

    _clearReconnect();
    try {
      final wsUri = Uri.parse(ApiConfig.eventsWsUrl);
      _channel = WebSocketChannel.connect(wsUri);

      _subscription = _channel!.stream.listen(
        (data) {
          try {
            final Map<String, dynamic> json = jsonDecode(data.toString());
            final event = RealtimeEvent.fromJson(json);
            _eventStreamController.add(event);
          } catch (e) {
            debugPrint('[EventsSocketService] Error parseando evento: $e');
          }
        },
        onError: (error) {
          debugPrint('[EventsSocketService] Error en WebSocket: $error');
          _isConnected = false;
          notifyListeners();
        },
        onDone: () {
          _isConnected = false;
          notifyListeners();
          _cleanup();
          if (_authService.isAuthenticated) {
            _scheduleReconnect();
          }
        },
      );

      _isConnected = true;
      _reconnectAttempt = 0;
      notifyListeners();

      // Auth handshake
      _channel!.sink.add(jsonEncode({'type': 'auth', 'token': token}));
      _startHeartbeat();
    } catch (e) {
      debugPrint('[EventsSocketService] Error conectando: $e');
      _isConnected = false;
      notifyListeners();
      _scheduleReconnect();
    }
  }

  void disconnect() {
    _clearReconnect();
    _stopHeartbeat();
    _cleanup();
    _isConnected = false;
    notifyListeners();
  }

  void _scheduleReconnect() {
    _clearReconnect();
    final delaySeconds = min(30, pow(2, _reconnectAttempt++).toInt());
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () => connect());
  }

  void _clearReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (_channel != null) {
        try {
          _channel!.sink.add(jsonEncode({'type': 'ping'}));
        } catch (_) {}
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _cleanup() {
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
  }

  @override
  void dispose() {
    disconnect();
    _eventStreamController.close();
    super.dispose();
  }
}
