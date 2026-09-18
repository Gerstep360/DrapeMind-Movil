class AtelierNotification {
  final int id;
  final int? usuarioId;
  final String titulo;
  final String mensaje;
  final String tipo;
  final Map<String, dynamic> dataPayload;
  bool leido;
  final DateTime? leidoEn;
  final DateTime createdAt;

  AtelierNotification({
    required this.id,
    this.usuarioId,
    required this.titulo,
    required this.mensaje,
    required this.tipo,
    required this.dataPayload,
    this.leido = false,
    this.leidoEn,
    required this.createdAt,
  });

  factory AtelierNotification.fromJson(Map<String, dynamic> json) => AtelierNotification(
    id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
    usuarioId: json['usuario_id'] != null ? int.tryParse(json['usuario_id'].toString()) : null,
    titulo: json['titulo']?.toString() ?? 'Notificación',
    mensaje: json['mensaje']?.toString() ?? '',
    tipo: json['tipo']?.toString() ?? 'GENERAL',
    dataPayload: json['data_payload'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(json['data_payload'])
        : (json['data'] is Map<String, dynamic> ? Map<String, dynamic>.from(json['data']) : {}),
    leido: json['leido'] == true,
    leidoEn: json['leido_en'] != null ? DateTime.tryParse(json['leido_en'].toString()) : null,
    createdAt: json['created_at'] != null
        ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
        : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'usuario_id': usuarioId,
    'titulo': titulo,
    'mensaje': mensaje,
    'tipo': tipo,
    'data_payload': dataPayload,
    'leido': leido,
    'leido_en': leidoEn?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };
}
