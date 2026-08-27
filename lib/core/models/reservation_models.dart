enum ReservationStatus {
  pendiente,
  confirmada,
  retirada,
  vencida,
  cancelada,
  convertida;

  static ReservationStatus fromString(String? status) {
    switch (status?.toUpperCase()) {
      case 'CONFIRMADA':
        return ReservationStatus.confirmada;
      case 'RETIRADA':
        return ReservationStatus.retirada;
      case 'VENCIDA':
        return ReservationStatus.vencida;
      case 'CANCELADA':
        return ReservationStatus.cancelada;
      case 'CONVERTIDA':
        return ReservationStatus.convertida;
      default:
        return ReservationStatus.pendiente;
    }
  }

  String toServerString() {
    switch (this) {
      case ReservationStatus.pendiente:
        return 'PENDIENTE';
      case ReservationStatus.confirmada:
        return 'CONFIRMADA';
      case ReservationStatus.retirada:
        return 'RETIRADA';
      case ReservationStatus.vencida:
        return 'VENCIDA';
      case ReservationStatus.cancelada:
        return 'CANCELADA';
      case ReservationStatus.convertida:
        return 'CONVERTIDA';
    }
  }

  String get displayName {
    switch (this) {
      case ReservationStatus.pendiente:
        return 'Pendiente';
      case ReservationStatus.confirmada:
        return 'Confirmada';
      case ReservationStatus.retirada:
        return 'Retirada';
      case ReservationStatus.vencida:
        return 'Vencida';
      case ReservationStatus.cancelada:
        return 'Cancelada';
      case ReservationStatus.convertida:
        return 'Convertida en Pedido';
    }
  }
}

class Reservation {
  final int id;
  final String codigoPublico;
  final ReservationStatus estado;
  final DateTime fechaReserva;
  final DateTime venceAt;
  final String? observacion;
  final int? usuarioId;
  final int? varianteId;

  Reservation({
    required this.id,
    required this.codigoPublico,
    required this.estado,
    required this.fechaReserva,
    required this.venceAt,
    this.observacion,
    this.usuarioId,
    this.varianteId,
  });

  bool get isExpired => DateTime.now().isAfter(venceAt);

  factory Reservation.fromJson(Map<String, dynamic> json) {
    return Reservation(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      codigoPublico: json['codigo_publico']?.toString() ?? '',
      estado: ReservationStatus.fromString(json['estado']?.toString()),
      fechaReserva: json['fecha_reserva'] != null
          ? DateTime.tryParse(json['fecha_reserva'].toString()) ?? DateTime.now()
          : DateTime.now(),
      venceAt: json['vence_at'] != null
          ? DateTime.tryParse(json['vence_at'].toString()) ??
              DateTime.now().add(const Duration(hours: 48))
          : DateTime.now().add(const Duration(hours: 48)),
      observacion: json['observacion'],
      usuarioId: json['usuario_id'],
      varianteId: json['variante_id'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'codigo_publico': codigoPublico,
        'estado': estado.toServerString(),
        'fecha_reserva': fechaReserva.toIso8601String(),
        'vence_at': venceAt.toIso8601String(),
        'observacion': observacion,
        if (usuarioId != null) 'usuario_id': usuarioId,
        if (varianteId != null) 'variante_id': varianteId,
      };
}
