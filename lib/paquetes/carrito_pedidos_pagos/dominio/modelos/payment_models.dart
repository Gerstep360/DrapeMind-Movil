enum PaymentMethod {
  qr,
  tarjeta,
  efectivo,
  transferencia;

  static PaymentMethod fromString(String? method) {
    switch (method?.toUpperCase()) {
      case 'TARJETA':
        return PaymentMethod.tarjeta;
      case 'EFECTIVO':
        return PaymentMethod.efectivo;
      case 'TRANSFERENCIA':
        return PaymentMethod.transferencia;
      default:
        return PaymentMethod.qr;
    }
  }

  String toServerString() {
    switch (this) {
      case PaymentMethod.qr:
        return 'QR';
      case PaymentMethod.tarjeta:
        return 'TARJETA';
      case PaymentMethod.efectivo:
        return 'EFECTIVO';
      case PaymentMethod.transferencia:
        return 'TRANSFERENCIA';
    }
  }

  String get displayName {
    switch (this) {
      case PaymentMethod.qr:
        return 'Pago Simple QR';
      case PaymentMethod.tarjeta:
        return 'Tarjeta de Débito / Crédito';
      case PaymentMethod.efectivo:
        return 'Efectivo en Showroom';
      case PaymentMethod.transferencia:
        return 'Transferencia Bancaria';
    }
  }
}

enum PaymentStatus {
  pendiente,
  procesando,
  aprobado,
  rechazado,
  reembolsado;

  static PaymentStatus fromString(String? status) {
    switch (status?.toUpperCase()) {
      case 'PROCESANDO':
        return PaymentStatus.procesando;
      case 'APROBADO':
        return PaymentStatus.aprobado;
      case 'RECHAZADO':
        return PaymentStatus.rechazado;
      case 'REEMBOLSADO':
        return PaymentStatus.reembolsado;
      default:
        return PaymentStatus.pendiente;
    }
  }

  String toServerString() {
    switch (this) {
      case PaymentStatus.pendiente:
        return 'PENDIENTE';
      case PaymentStatus.procesando:
        return 'PROCESANDO';
      case PaymentStatus.aprobado:
        return 'APROBADO';
      case PaymentStatus.rechazado:
        return 'RECHAZADO';
      case PaymentStatus.reembolsado:
        return 'REEMBOLSADO';
    }
  }

  String get displayName {
    switch (this) {
      case PaymentStatus.pendiente:
        return 'Pendiente';
      case PaymentStatus.procesando:
        return 'Procesando';
      case PaymentStatus.aprobado:
        return 'Aprobado';
      case PaymentStatus.rechazado:
        return 'Rechazado';
      case PaymentStatus.reembolsado:
        return 'Reembolsado';
    }
  }
}

class Payment {
  final int id;
  final int pedidoId;
  final PaymentMethod metodo;
  final String proveedor;
  final double monto;
  final String moneda;
  final PaymentStatus estado;
  final String referenciaExterna;
  final String? qrPayload;
  final DateTime? createdAt;
  final DateTime? paidAt;

  Payment({
    required this.id,
    required this.pedidoId,
    required this.metodo,
    this.proveedor = 'MANUAL',
    required this.monto,
    this.moneda = 'BOB',
    required this.estado,
    this.referenciaExterna = '',
    this.qrPayload,
    this.createdAt,
    this.paidAt,
  });

  bool get isPaid => estado == PaymentStatus.aprobado;

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      pedidoId: json['pedido_id'] is int
          ? json['pedido_id']
          : int.tryParse(json['pedido_id'].toString()) ?? 0,
      metodo: PaymentMethod.fromString(json['metodo']?.toString()),
      proveedor: json['proveedor']?.toString() ?? 'MANUAL',
      monto: json['monto'] is num
          ? (json['monto'] as num).toDouble()
          : double.tryParse(json['monto'].toString()) ?? 0.0,
      moneda: json['moneda']?.toString() ?? 'BOB',
      estado: PaymentStatus.fromString(json['estado']?.toString()),
      referenciaExterna: json['referencia_externa']?.toString() ?? '',
      qrPayload: json['qr_payload']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      paidAt: json['paid_at'] != null
          ? DateTime.tryParse(json['paid_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'pedido_id': pedidoId,
    'metodo': metodo.toServerString(),
    'proveedor': proveedor,
    'monto': monto,
    'moneda': moneda,
    'estado': estado.toServerString(),
    'referencia_externa': referenciaExterna,
    'qr_payload': qrPayload,
    'created_at': createdAt?.toIso8601String(),
    'paid_at': paidAt?.toIso8601String(),
  };
}

class PaymentCreate {
  final int pedidoId;
  final PaymentMethod metodo;

  PaymentCreate({required this.pedidoId, required this.metodo});

  Map<String, dynamic> toJson() => {
    'pedido_id': pedidoId,
    'metodo': metodo.toServerString(),
  };
}
