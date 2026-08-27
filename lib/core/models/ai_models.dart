import '../config/api_config.dart';

enum AiActionType {
  agregar,
  quitar,
  reemplazar,
  verPedido,
  verReserva;

  static AiActionType fromString(String? action) {
    switch (action?.toUpperCase()) {
      case 'QUITAR':
        return AiActionType.quitar;
      case 'REEMPLAZAR':
        return AiActionType.reemplazar;
      case 'VER_PEDIDO':
        return AiActionType.verPedido;
      case 'VER_RESERVA':
        return AiActionType.verReserva;
      default:
        return AiActionType.agregar;
    }
  }

  String toServerString() {
    switch (this) {
      case AiActionType.agregar:
        return 'AGREGAR';
      case AiActionType.quitar:
        return 'QUITAR';
      case AiActionType.reemplazar:
        return 'REEMPLAZAR';
      case AiActionType.verPedido:
        return 'VER_PEDIDO';
      case AiActionType.verReserva:
        return 'VER_RESERVA';
    }
  }
}

class AiActionItem {
  final int id;
  final int? varianteId;
  final int? itemId;
  final String nombre;
  final double precio;
  final String? color;
  final String? talla;
  final String? sku;
  final String? imagen;
  final AiActionType accion;
  final String? motivo;

  AiActionItem({
    required this.id,
    this.varianteId,
    this.itemId,
    required this.nombre,
    required this.precio,
    this.color,
    this.talla,
    this.sku,
    this.imagen,
    this.accion = AiActionType.agregar,
    this.motivo,
  });

  String get fullImageUrl => ApiConfig.resolveMediaUrl(imagen);

  factory AiActionItem.fromJson(Map<String, dynamic> json) {
    return AiActionItem(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      varianteId: json['variante_id'] != null
          ? int.tryParse(json['variante_id'].toString())
          : null,
      itemId: json['item_id'] != null
          ? int.tryParse(json['item_id'].toString())
          : null,
      nombre: json['nombre']?.toString() ?? '',
      precio: json['precio'] is num
          ? (json['precio'] as num).toDouble()
          : double.tryParse(json['precio'].toString()) ?? 0.0,
      color: json['color']?.toString(),
      talla: json['talla']?.toString(),
      sku: json['sku']?.toString(),
      imagen: json['imagen']?.toString(),
      accion: AiActionType.fromString(json['accion']?.toString()),
      motivo: json['motivo']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (varianteId != null) 'variante_id': varianteId,
        if (itemId != null) 'item_id': itemId,
        'nombre': nombre,
        'precio': precio,
        'color': color,
        'talla': talla,
        'sku': sku,
        'imagen': imagen,
        'accion': accion.toServerString(),
        'motivo': motivo,
      };
}

enum AiPresentationMode {
  text,
  cards,
  mixed;

  static AiPresentationMode fromString(String? mode) {
    switch (mode?.toLowerCase()) {
      case 'cards':
        return AiPresentationMode.cards;
      case 'mixed':
        return AiPresentationMode.mixed;
      default:
        return AiPresentationMode.text;
    }
  }
}

class AiNotice {
  final String type; // 'info' | 'warning'
  final String title;
  final String message;

  AiNotice({
    required this.type,
    required this.title,
    required this.message,
  });

  factory AiNotice.fromJson(Map<String, dynamic> json) {
    return AiNotice(
      type: json['type']?.toString() ?? 'info',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'title': title,
        'message': message,
      };
}

class AiResponseMeta {
  final String? kind;
  final double? totalBob;
  final double? budgetBob;
  final double? budgetRemainingBob;
  final int? itemCount;
  final String? occasion;
  final bool? canAddAll;

  AiResponseMeta({
    this.kind,
    this.totalBob,
    this.budgetBob,
    this.budgetRemainingBob,
    this.itemCount,
    this.occasion,
    this.canAddAll,
  });

  factory AiResponseMeta.fromJson(Map<String, dynamic> json) {
    return AiResponseMeta(
      kind: json['kind']?.toString(),
      totalBob: json['total_bob'] is num
          ? (json['total_bob'] as num).toDouble()
          : double.tryParse(json['total_bob']?.toString() ?? ''),
      budgetBob: json['budget_bob'] is num
          ? (json['budget_bob'] as num).toDouble()
          : double.tryParse(json['budget_bob']?.toString() ?? ''),
      budgetRemainingBob: json['budget_remaining_bob'] is num
          ? (json['budget_remaining_bob'] as num).toDouble()
          : double.tryParse(json['budget_remaining_bob']?.toString() ?? ''),
      itemCount: json['item_count'] is int
          ? json['item_count']
          : int.tryParse(json['item_count']?.toString() ?? ''),
      occasion: json['occasion']?.toString(),
      canAddAll: json['can_add_all'] is bool ? json['can_add_all'] : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'total_bob': totalBob,
        'budget_bob': budgetBob,
        'budget_remaining_bob': budgetRemainingBob,
        'item_count': itemCount,
        'occasion': occasion,
        'can_add_all': canAddAll,
      };
}

class AiSuggestedAction {
  final String label;
  final String prompt;

  AiSuggestedAction({required this.label, required this.prompt});

  factory AiSuggestedAction.fromJson(Map<String, dynamic> json) {
    return AiSuggestedAction(
      label: json['label']?.toString() ?? '',
      prompt: json['prompt']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'prompt': prompt,
      };
}

class AgentTraceStep {
  final String name;
  final String state; // 'running' | 'done'
  final String? summary;
  final int startedAt;
  final int? durationMs;

  AgentTraceStep({
    required this.name,
    required this.state,
    this.summary,
    required this.startedAt,
    this.durationMs,
  });

  AgentTraceStep copyWith({
    String? state,
    String? summary,
    int? durationMs,
  }) {
    return AgentTraceStep(
      name: name,
      state: state ?? this.state,
      summary: summary ?? this.summary,
      startedAt: startedAt,
      durationMs: durationMs ?? this.durationMs,
    );
  }

  factory AgentTraceStep.fromJson(Map<String, dynamic> json) {
    return AgentTraceStep(
      name: json['name']?.toString() ?? '',
      state: json['state']?.toString() ?? 'done',
      summary: json['summary']?.toString(),
      startedAt: json['started_at'] is int ? json['started_at'] : 0,
      durationMs: json['duration_ms'] is int ? json['duration_ms'] : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'state': state,
        'summary': summary,
        'started_at': startedAt,
        'duration_ms': durationMs,
      };
}

class ChatMessage {
  final String id;
  final String role; // 'user' | 'assistant'
  String content;
  bool pending;
  bool error;
  List<String> tools;
  List<AiActionItem> actionItems;
  List<AgentTraceStep> trace;
  AiPresentationMode presentationMode;
  String? responseTitle;
  List<AiNotice> notices;
  AiResponseMeta? responseMeta;
  List<AiSuggestedAction> suggestedActions;
  int? durationMs;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.pending = false,
    this.error = false,
    this.tools = const [],
    this.actionItems = const [],
    this.trace = const [],
    this.presentationMode = AiPresentationMode.text,
    this.responseTitle,
    this.notices = const [],
    this.responseMeta,
    this.suggestedActions = const [],
    this.durationMs,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id']?.toString() ?? 'msg-${DateTime.now().millisecondsSinceEpoch}',
      role: json['role']?.toString() ?? 'assistant',
      content: json['content']?.toString() ?? '',
      pending: json['pending'] == true,
      error: json['error'] == true,
      tools: (json['tools'] as List? ?? []).map((t) => t.toString()).toList(),
      actionItems: (json['action_items'] as List? ?? [])
          .map((a) => AiActionItem.fromJson(a as Map<String, dynamic>))
          .toList(),
      trace: (json['trace'] as List? ?? [])
          .map((t) => AgentTraceStep.fromJson(t as Map<String, dynamic>))
          .toList(),
      presentationMode: AiPresentationMode.fromString(json['presentation_mode']?.toString()),
      responseTitle: json['response_title']?.toString(),
      notices: (json['notices'] as List? ?? [])
          .map((n) => AiNotice.fromJson(n as Map<String, dynamic>))
          .toList(),
      responseMeta: json['response_meta'] != null
          ? AiResponseMeta.fromJson(json['response_meta'] as Map<String, dynamic>)
          : null,
      suggestedActions: (json['suggested_actions'] as List? ?? [])
          .map((s) => AiSuggestedAction.fromJson(s as Map<String, dynamic>))
          .toList(),
      durationMs: json['duration_ms'] is int ? json['duration_ms'] : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'content': content,
        'pending': pending,
        'error': error,
        'tools': tools,
        'action_items': actionItems.map((a) => a.toJson()).toList(),
        'trace': trace.map((t) => t.toJson()).toList(),
        'presentation_mode': presentationMode.name,
        'response_title': responseTitle,
        'notices': notices.map((n) => n.toJson()).toList(),
        'response_meta': responseMeta?.toJson(),
        'suggested_actions': suggestedActions.map((s) => s.toJson()).toList(),
        'duration_ms': durationMs,
        'created_at': createdAt.toIso8601String(),
      };
}

class ChatSession {
  final String id;
  String title;
  final DateTime createdAt;
  DateTime updatedAt;
  List<ChatMessage> messages;
  int? backendSessionId;

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
    this.backendSessionId,
  });

  bool get isExpired => DateTime.now().difference(updatedAt).inHours >= 24;

  factory ChatSession.create({String? title}) {
    final now = DateTime.now();
    return ChatSession(
      id: 'session-${now.millisecondsSinceEpoch}',
      title: title ?? 'Conversación Atelier',
      createdAt: now,
      updatedAt: now,
      messages: [
        ChatMessage(
          id: 'welcome-${now.millisecondsSinceEpoch}',
          role: 'assistant',
          content:
              'Saludos, soy Altair, tu Personal Stylist de DrapeMind Atelier. Puedo analizar tu perchero, diseñar propuestas por ocasión y equilibrar tu guardarropa con stock y datos reales.',
        ),
      ],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'backend_session_id': backendSessionId,
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id']?.toString() ?? 'session-${DateTime.now().millisecondsSinceEpoch}',
      title: json['title']?.toString() ?? 'Conversación Atelier',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      backendSessionId: json['backend_session_id'] != null
          ? int.tryParse(json['backend_session_id'].toString())
          : null,
      messages: (json['messages'] as List? ?? [])
          .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }
}
