import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/api_config.dart';
import '../models/ai_models.dart';
import 'auth_service.dart';

enum AiSocketStatus {
  offline,
  connecting,
  connected,
  loading,
  ready,
  error;

  String get displayName {
    switch (this) {
      case AiSocketStatus.offline:
        return 'Desconectado';
      case AiSocketStatus.connecting:
        return 'Conectando...';
      case AiSocketStatus.connected:
        return 'Conectado';
      case AiSocketStatus.loading:
        return 'Altair pensando...';
      case AiSocketStatus.ready:
        return 'Listo';
      case AiSocketStatus.error:
        return 'Error de conexión';
    }
  }
}

class AiSocketService extends ChangeNotifier {
  static const String _storageKey = 'drapemind_ai_sessions_v2';
  final AuthService _authService;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  Timer? _thinkingTickerTimer;

  int _reconnectAttempt = 0;
  String? _queuedMessage;
  int _responseStartedAt = 0;
  int _thinkingElapsedMs = 0;

  String? _currentThought;
  final List<String> _liveThoughtSteps = [];
  AiSocketStatus _status = AiSocketStatus.offline;

  List<ChatSession> _sessions = [];
  String? _activeSessionId;
  List<AgentTraceStep> _toolActivity = [];

  AiSocketService({required AuthService authService}) : _authService = authService {
    _loadSessionsFromStorage();
  }

  // --- GETTERS ---
  AiSocketStatus get status => _status;
  String? get currentThought => _currentThought;
  List<String> get liveThoughtSteps => List.unmodifiable(_liveThoughtSteps);
  int get thinkingElapsedMs => _thinkingElapsedMs;
  double get thinkingElapsedSeconds => _thinkingElapsedMs / 1000.0;
  String get thinkingElapsedFormatted => '${(_thinkingElapsedMs / 1000.0).toStringAsFixed(1)}s';

  List<ChatSession> get sessions => List.unmodifiable(_sessions);
  ChatSession get currentSession {
    if (_sessions.isEmpty) {
      final initial = ChatSession.create(title: 'Asesoría Inicial');
      _sessions.add(initial);
      _activeSessionId = initial.id;
      return initial;
    }
    return _sessions.firstWhere(
      (s) => s.id == _activeSessionId,
      orElse: () => _sessions.first,
    );
  }

  List<ChatMessage> get messages => currentSession.messages;
  List<AgentTraceStep> get toolActivity => List.unmodifiable(_toolActivity);
  bool get isBusy => currentSession.messages.any((m) => m.pending);
  int? get sessionId => currentSession.backendSessionId;

  // --- MULTI-CHAT & 24H STORAGE ---
  Future<void> _loadSessionsFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final List list = jsonDecode(raw);
        final loaded = list
            .map((item) => ChatSession.fromJson(item as Map<String, dynamic>))
            .where((s) => !s.isExpired) // Eliminar chats mayores a 24 horas
            .toList();

        if (loaded.isNotEmpty) {
          _sessions = loaded;
          _activeSessionId = _sessions.first.id;
          notifyListeners();
          return;
        }
      }
    } catch (e) {
      debugPrint('[AiSocketService] Error cargando sesiones de SharedPreferences: $e');
    }

    // Inicializar sesión por defecto
    final initial = ChatSession.create(title: 'Asesoría Atelier');
    _sessions = [initial];
    _activeSessionId = initial.id;
    notifyListeners();
  }

  Future<void> _saveSessionsToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Filtrar expirados de más de 24 horas antes de persistir
      _sessions.removeWhere((s) => s.isExpired);
      final raw = jsonEncode(_sessions.map((s) => s.toJson()).toList());
      await prefs.setString(_storageKey, raw);
    } catch (e) {
      debugPrint('[AiSocketService] Error guardando sesiones: $e');
    }
  }

  /// Crea una nueva sesión de chat separada
  void createNewSession({String? title}) {
    final newSession = ChatSession.create(
      title: title ?? 'Conversación #${_sessions.length + 1}',
    );
    _sessions.insert(0, newSession);
    _activeSessionId = newSession.id;
    _toolActivity = [];
    _liveThoughtSteps.clear();
    _currentThought = null;
    _saveSessionsToStorage();
    notifyListeners();
  }

  /// Cambia a otra conversación existente
  void switchSession(String sessionId) {
    if (_activeSessionId == sessionId) return;
    if (_sessions.any((s) => s.id == sessionId)) {
      _activeSessionId = sessionId;
      _toolActivity = [];
      _liveThoughtSteps.clear();
      _currentThought = null;
      notifyListeners();
    }
  }

  /// Elimina una sesión del historial
  void deleteSession(String sessionId) {
    _sessions.removeWhere((s) => s.id == sessionId);
    if (_sessions.isEmpty) {
      createNewSession(title: 'Nueva Conversación');
    } else if (_activeSessionId == sessionId) {
      _activeSessionId = _sessions.first.id;
    }
    _saveSessionsToStorage();
    notifyListeners();
  }

  /// Reinicia los mensajes de la sesión actual
  void clearConversation() {
    currentSession.messages = [
      ChatMessage(
        id: 'welcome-${DateTime.now().millisecondsSinceEpoch}',
        role: 'assistant',
        content: 'Nueva conversación lista. ¿Qué look deseas diseñar hoy?',
      ),
    ];
    currentSession.backendSessionId = null;
    currentSession.updatedAt = DateTime.now();
    _toolActivity = [];
    _liveThoughtSteps.clear();
    _currentThought = null;
    _responseStartedAt = 0;
    _saveSessionsToStorage();
    notifyListeners();
  }

  // --- WEBSOCKET CONNECTION ---
  void connect() {
    final token = _authService.token;
    if (token == null || token.isEmpty) return;
    if (_status == AiSocketStatus.connected || _status == AiSocketStatus.connecting) return;

    _clearReconnect();
    _status = AiSocketStatus.connecting;
    notifyListeners();

    try {
      final wsUri = Uri.parse(ApiConfig.aiWsUrl);
      _channel = WebSocketChannel.connect(wsUri);

      _subscription = _channel!.stream.listen(
        (data) {
          try {
            final Map<String, dynamic> event = jsonDecode(data.toString());
            _handleEvent(event);
          } catch (e) {
            debugPrint('[AiSocketService] Error decodificando evento: $e');
          }
        },
        onError: (error) {
          debugPrint('[AiSocketService] WebSocket error: $error');
          _status = AiSocketStatus.error;
          _stopThinkingTicker();
          if (currentSession.messages.isNotEmpty && currentSession.messages.last.role == 'assistant' && currentSession.messages.last.pending) {
            final last = currentSession.messages.last;
            if (last.content.isEmpty) {
              last.content = 'Error de comunicación con Altair AI. Revisa tu conexión o inicia sesión.';
              last.error = true;
            }
            last.pending = false;
            last.durationMs = DateTime.now().millisecondsSinceEpoch - _responseStartedAt;
            _saveSessionsToStorage();
          }
          notifyListeners();
        },
        onDone: () {
          debugPrint('[AiSocketService] WebSocket cerrado.');
          _cleanupSocket();
          _stopThinkingTicker();
          if (currentSession.messages.isNotEmpty && currentSession.messages.last.role == 'assistant' && currentSession.messages.last.pending) {
            final last = currentSession.messages.last;
            if (last.content.isEmpty) {
              last.content = 'Conexión cerrada. Vuelve a iniciar sesión si tu token expiró.';
              last.error = true;
            }
            last.pending = false;
            last.durationMs = DateTime.now().millisecondsSinceEpoch - _responseStartedAt;
            _saveSessionsToStorage();
          }
          if (_authService.isAuthenticated) {
            _status = AiSocketStatus.offline;
            notifyListeners();
            _scheduleReconnect();
          } else {
            _status = AiSocketStatus.offline;
            notifyListeners();
          }
        },
      );

      _reconnectAttempt = 0;
      _channel!.sink.add(jsonEncode({'type': 'auth', 'token': token}));
      _startHeartbeat();
    } catch (e) {
      debugPrint('[AiSocketService] Error conectando WebSocket: $e');
      _status = AiSocketStatus.error;
      _stopThinkingTicker();
      notifyListeners();
      _scheduleReconnect();
    }
  }

  void disconnect() {
    _clearReconnect();
    _stopHeartbeat();
    _stopThinkingTicker();
    _cleanupSocket();
    _status = AiSocketStatus.offline;
    notifyListeners();
  }

  // --- SEND MESSAGE & LIVE THINKING TICKER ---
  void sendMessage(String content) {
    final clean = content.trim();
    if (clean.isEmpty || isBusy) return;

    final userMsgId = 'user-${DateTime.now().millisecondsSinceEpoch}';
    final assistantMsgId = 'assistant-${DateTime.now().millisecondsSinceEpoch}';

    // Auto nombrar el título de la sesión si es la primera pregunta
    if (currentSession.messages.length <= 1) {
      currentSession.title = clean.length > 28 ? '${clean.substring(0, 28)}...' : clean;
    }

    currentSession.messages.add(ChatMessage(
      id: userMsgId,
      role: 'user',
      content: clean,
    ));

    currentSession.messages.add(ChatMessage(
      id: assistantMsgId,
      role: 'assistant',
      content: '',
      pending: true,
    ));

    currentSession.updatedAt = DateTime.now();

    _toolActivity = [];
    _liveThoughtSteps.clear();
    _currentThought = 'Analizando solicitud...';
    _responseStartedAt = DateTime.now().millisecondsSinceEpoch;
    _thinkingElapsedMs = 0;

    _startThinkingTicker();
    _saveSessionsToStorage();
    notifyListeners();

    if (_status == AiSocketStatus.connected || _status == AiSocketStatus.ready) {
      _sendChat(clean);
    } else {
      _queuedMessage = clean;
      connect();
    }
  }

  void _startThinkingTicker() {
    _stopThinkingTicker();
    _thinkingTickerTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_responseStartedAt > 0) {
        _thinkingElapsedMs = DateTime.now().millisecondsSinceEpoch - _responseStartedAt;
        notifyListeners();
      }
    });
  }

  void _stopThinkingTicker() {
    _thinkingTickerTimer?.cancel();
    _thinkingTickerTimer = null;
  }

  void _sendChat(String content) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({
        'type': 'chat',
        'message': content,
        'session_id': currentSession.backendSessionId,
      }));
    }
  }

  // --- EVENT HANDLER ---
  void _handleEvent(Map<String, dynamic> event) {
    final type = event['type']?.toString();

    if (type == 'connected') {
      _status = AiSocketStatus.connected;
      notifyListeners();
      if (_queuedMessage != null) {
        final msg = _queuedMessage!;
        _queuedMessage = null;
        _sendChat(msg);
      }
      return;
    }

    if (type == 'thought') {
      final text = event['content']?.toString() ?? event['text']?.toString() ?? '';
      if (text.isNotEmpty) {
        _currentThought = text;
        if (!_liveThoughtSteps.contains(text)) {
          _liveThoughtSteps.add(text);
        }
        _startTrace(text);
        _finishTrace(text, 'Completado');
        notifyListeners();
      }
      return;
    }

    if (type == 'model_status') {
      final statusStr = event['status']?.toString();
      _status = statusStr == 'loading' ? AiSocketStatus.loading : AiSocketStatus.ready;
      if (event['session_id'] != null) {
        currentSession.backendSessionId = int.tryParse(event['session_id'].toString());
      }
      if (statusStr == 'loading') {
        _startTrace('Altair iniciando razonamiento...');
      } else {
        _finishTrace('Altair iniciando razonamiento...', 'Listo');
      }
      notifyListeners();
      return;
    }

    if (type == 'tool_start') {
      final name = event['name']?.toString() ?? 'tool';
      final formatted = _formatToolName(name);
      _currentThought = formatted;
      _startTrace(formatted);
      notifyListeners();
      return;
    }

    if (type == 'tool_result') {
      final name = event['name']?.toString() ?? 'tool';
      _finishTrace(_formatToolName(name), _resultSummary(event['result']));
      notifyListeners();
      return;
    }

    if (type == 'presentation') {
      if (currentSession.messages.isNotEmpty && currentSession.messages.last.role == 'assistant') {
        final last = currentSession.messages.last;
        last.presentationMode = AiPresentationMode.fromString(event['mode']?.toString());
        last.responseTitle = event['title']?.toString();

        if (event['notices'] is List) {
          last.notices = (event['notices'] as List)
              .map((n) => AiNotice.fromJson(n as Map<String, dynamic>))
              .toList();
        }

        if (event['response_meta'] is Map) {
          last.responseMeta = AiResponseMeta.fromJson(event['response_meta'] as Map<String, dynamic>);
        }

        if (event['suggested_actions'] is List) {
          last.suggestedActions = (event['suggested_actions'] as List)
              .map((a) => AiSuggestedAction.fromJson(a as Map<String, dynamic>))
              .toList();
        }
        notifyListeners();
      }
      return;
    }

    if (type == 'token') {
      final content = event['content']?.toString() ?? '';
      _startTrace('compose_response');
      if (currentSession.messages.isNotEmpty && currentSession.messages.last.role == 'assistant') {
        currentSession.messages.last.content += content;
        notifyListeners();
      }
      return;
    }

    if (type == 'done') {
      _stopThinkingTicker();
      _finishTrace('compose_response', 'Respuesta preparada');
      if (event['session_id'] != null) {
        currentSession.backendSessionId = int.tryParse(event['session_id'].toString());
      }
      _status = AiSocketStatus.ready;
      _currentThought = null;

      if (currentSession.messages.isNotEmpty && currentSession.messages.last.role == 'assistant') {
        final last = currentSession.messages.last;
        last.pending = false;

        if (event['tools'] is List) {
          last.tools = (event['tools'] as List).map((t) => t.toString()).toList();
        }

        if (event['action_items'] is List) {
          last.actionItems = (event['action_items'] as List)
              .map((item) => AiActionItem.fromJson(item as Map<String, dynamic>))
              .toList();
        }

        last.trace = _toolActivity.map((step) => step.copyWith()).toList();

        if (event['presentation_mode'] != null) {
          last.presentationMode = AiPresentationMode.fromString(event['presentation_mode'].toString());
        }
        if (event['response_title'] != null) {
          last.responseTitle = event['response_title'].toString();
        }
        if (event['notices'] is List) {
          last.notices = (event['notices'] as List)
              .map((n) => AiNotice.fromJson(n as Map<String, dynamic>))
              .toList();
        }
        if (event['response_meta'] is Map) {
          last.responseMeta = AiResponseMeta.fromJson(event['response_meta'] as Map<String, dynamic>);
        }
        if (event['suggested_actions'] is List) {
          last.suggestedActions = (event['suggested_actions'] as List)
              .map((a) => AiSuggestedAction.fromJson(a as Map<String, dynamic>))
              .toList();
        }
        last.durationMs = event['duration_ms'] is int
            ? event['duration_ms']
            : (DateTime.now().millisecondsSinceEpoch - _responseStartedAt);

        currentSession.updatedAt = DateTime.now();
        _saveSessionsToStorage();
        notifyListeners();
      }
      return;
    }

    if (type == 'error') {
      _stopThinkingTicker();
      _status = AiSocketStatus.error;
      _currentThought = null;
      final msg = event['message']?.toString() ?? 'No se pudo completar la consulta.';
      if (msg.contains('expirada') || msg.contains('inválida') || msg.contains('inactivo') || msg.contains('sesión')) {
        _clearReconnect();
        _reconnectAttempt = 999;
      }
      for (final step in _toolActivity) {
        if (step.state == 'running') {
          _finishTrace(step.name, 'Proceso interrumpido');
        }
      }
      if (currentSession.messages.isNotEmpty && currentSession.messages.last.role == 'assistant' && currentSession.messages.last.pending) {
        final last = currentSession.messages.last;
        last.content = msg;
        last.pending = false;
        last.error = true;
        last.trace = _toolActivity.map((step) => step.copyWith()).toList();
        last.durationMs = DateTime.now().millisecondsSinceEpoch - _responseStartedAt;
      }
      currentSession.updatedAt = DateTime.now();
      _saveSessionsToStorage();
      notifyListeners();
    }
  }

  String _formatToolName(String raw) {
    switch (raw) {
      case 'get_my_cart':
        return 'Inspeccionando perchero del cliente';
      case 'recommend_outfit':
        return 'Diseñando outfit con stock real';
      case 'search_products':
        return 'Consultando catálogo y stock del atelier';
      case 'get_trending_pieces':
        return 'Buscando complementos de alta calidad (Q4/Q5)';
      case 'get_my_orders':
        return 'Consultando pedidos y compras registradas';
      case 'get_my_reservations':
        return 'Verificando reservas de 48 horas en showroom';
      case 'optimize_outfit_skill':
        return 'Estrategia de inversión y calidad textil';
      default:
        return raw.replaceAll('_', ' ');
    }
  }

  String _resultSummary(dynamic result) {
    if (result is List) return '${result.length} resultados verificados';
    if (result is Map) return 'Datos verificados';
    return 'Completado';
  }

  void _startTrace(String name) {
    if (_toolActivity.any((step) => step.name == name)) return;
    _toolActivity.add(AgentTraceStep(
      name: name,
      state: 'running',
      startedAt: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  void _finishTrace(String name, String summary) {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (int i = 0; i < _toolActivity.length; i++) {
      if (_toolActivity[i].name == name && _toolActivity[i].state == 'running') {
        _toolActivity[i] = _toolActivity[i].copyWith(
          state: 'done',
          summary: summary,
          durationMs: max(0, now - _toolActivity[i].startedAt),
        );
      }
    }
  }

  void _scheduleReconnect() {
    _clearReconnect();
    if (_reconnectAttempt >= 5) {
      debugPrint('[AiSocketService] Límite de reconexiones alcanzado. Inicia sesión nuevamente.');
      _status = AiSocketStatus.offline;
      notifyListeners();
      return;
    }
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

  void _cleanupSocket() {
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
