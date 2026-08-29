enum OrderStatus {
  pendientePago,
  pagado,
  preparando,
  listo,
  enviado,
  entregado,
  cancelado;

  static OrderStatus fromString(String? status) {
    switch (status?.toUpperCase()) {
      case 'PAGADO':
        return OrderStatus.pagado;
      case 'PREPARANDO':
        return OrderStatus.preparando;
      case 'LISTO':
        return OrderStatus.listo;
      case 'ENVIADO':
        return OrderStatus.enviado;
      case 'ENTREGADO':
        return OrderStatus.entregado;
      case 'CANCELADO':
        return OrderStatus.cancelado;
      default:
        return OrderStatus.pendientePago;
    }
  }

  String toServerString() {
    switch (this) {
      case OrderStatus.pendientePago:
        return 'PENDIENTE_PAGO';
      case OrderStatus.pagado:
        return 'PAGADO';
      case OrderStatus.preparando:
        return 'PREPARANDO';
      case OrderStatus.listo:
        return 'LISTO';
      case OrderStatus.enviado:
        return 'ENVIADO';
      case OrderStatus.entregado:
        return 'ENTREGADO';
      case OrderStatus.cancelado:
        return 'CANCELADO';
    }
  }

  String get displayName {
    switch (this) {
      case OrderStatus.pendientePago:
        return 'Pendiente de Pago';
      case OrderStatus.pagado:
        return 'Pagado';
      case OrderStatus.preparando:
        return 'En Preparación';
      case OrderStatus.listo:
        return 'Listo para Retiro';
      case OrderStatus.enviado:
        return 'En Camino';
      case OrderStatus.entregado:
        return 'Entregado';
      case OrderStatus.cancelado:
        return 'Cancelado';
    }
  }
}

enum DeliveryType {
  delivery,
  recojo,
  tienda;

  static DeliveryType fromString(String? type) {
    switch (type?.toUpperCase()) {
      case 'DELIVERY':
        return DeliveryType.delivery;
      case 'TIENDA':
        return DeliveryType.tienda;
      default:
        return DeliveryType.recojo;
    }
  }

  String toServerString() {
    switch (this) {
      case DeliveryType.delivery:
        return 'DELIVERY';
      case DeliveryType.recojo:
        return 'RECOJO';
      case DeliveryType.tienda:
        return 'TIENDA';
    }
  }

  String get displayName {
    switch (this) {
      case DeliveryType.delivery:
        return 'Envío a Domicilio';
      case DeliveryType.recojo:
        return 'Recojo en Showroom';
      case DeliveryType.tienda:
        return 'Compra en Tienda';
    }
  }
}

class OrderItem {
  final int id;
  final int pedidoId;
  final int varianteId;
  final int productoId;
  final String nombre;
  final String sku;
  final String color;
  final String talla;
  final int cantidad;
  final double precioUnitario;
  final double subtotal;

  OrderItem({
    required this.id,
    required this.pedidoId,
    required this.varianteId,
    required this.productoId,
    required this.nombre,
    required this.sku,
    required this.color,
    required this.talla,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      pedidoId: json['pedido_id'] is int
          ? json['pedido_id']
          : int.tryParse(json['pedido_id'].toString()) ?? 0,
      varianteId: json['variante_id'] is int
          ? json['variante_id']
          : int.tryParse(json['variante_id'].toString()) ?? 0,
      productoId: json['producto_id'] is int
          ? json['producto_id']
          : int.tryParse(json['producto_id'].toString()) ?? 0,
      nombre: json['nombre'] ?? json['producto_nombre'] ?? '',
      sku: json['sku'] ?? '',
      color: json['color'] ?? '',
      talla: json['talla'] ?? '',
      cantidad: json['cantidad'] is int
          ? json['cantidad']
          : int.tryParse(json['cantidad'].toString()) ?? 1,
      precioUnitario: json['precio_unitario'] is num
          ? (json['precio_unitario'] as num).toDouble()
          : double.tryParse(json['precio_unitario'].toString()) ?? 0.0,
      subtotal: json['subtotal'] is num
          ? (json['subtotal'] as num).toDouble()
          : double.tryParse(json['subtotal'].toString()) ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'pedido_id': pedidoId,
    'variante_id': varianteId,
    'producto_id': productoId,
    'nombre': nombre,
    'sku': sku,
    'color': color,
    'talla': talla,
    'cantidad': cantidad,
    'precio_unitario': precioUnitario,
    'subtotal': subtotal,
  };
}

class Order {
  final int id;
  final String codigoPublico;
  final OrderStatus estado;
  final String canal;
  final DeliveryType tipoEntrega;
  final double subtotal;
  final double descuento;
  final double costoEnvio;
  final double total;
  final DateTime createdAt;
  final DateTime? paidAt;
  final DateTime? completedAt;
  final List<OrderItem> items;

  Order({
    required this.id,
    required this.codigoPublico,
    required this.estado,
    this.canal = 'MOBILE',
    this.tipoEntrega = DeliveryType.recojo,
    required this.subtotal,
    this.descuento = 0.0,
    this.costoEnvio = 0.0,
    required this.total,
    required this.createdAt,
    this.paidAt,
    this.completedAt,
    this.items = const [],
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    List<OrderItem> parsedItems = [];
    if (json['items'] is List) {
      parsedItems = (json['items'] as List)
          .map((i) => OrderItem.fromJson(i as Map<String, dynamic>))
          .toList();
    }

    return Order(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      codigoPublico: json['codigo_publico']?.toString() ?? '',
      estado: OrderStatus.fromString(json['estado']?.toString()),
      canal: json['canal']?.toString() ?? 'MOBILE',
      tipoEntrega: DeliveryType.fromString(json['tipo_entrega']?.toString()),
      subtotal: json['subtotal'] is num
          ? (json['subtotal'] as num).toDouble()
          : double.tryParse(json['subtotal'].toString()) ?? 0.0,
      descuento: json['descuento'] is num
          ? (json['descuento'] as num).toDouble()
          : double.tryParse(json['descuento'].toString()) ?? 0.0,
      costoEnvio: json['costo_envio'] is num
          ? (json['costo_envio'] as num).toDouble()
          : double.tryParse(json['costo_envio'].toString()) ?? 0.0,
      total: json['total'] is num
          ? (json['total'] as num).toDouble()
          : double.tryParse(json['total'].toString()) ?? 0.0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      paidAt: json['paid_at'] != null
          ? DateTime.tryParse(json['paid_at'].toString())
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'].toString())
          : null,
      items: parsedItems,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'codigo_publico': codigoPublico,
    'estado': estado.toServerString(),
    'canal': canal,
    'tipo_entrega': tipoEntrega.toServerString(),
    'subtotal': subtotal,
    'descuento': descuento,
    'costo_envio': costoEnvio,
    'total': total,
    'created_at': createdAt.toIso8601String(),
    'paid_at': paidAt?.toIso8601String(),
    'completed_at': completedAt?.toIso8601String(),
    'items': items.map((i) => i.toJson()).toList(),
  };
}

class CheckoutRequest {
  final DeliveryType tipoEntrega;
  final int? direccionId;
  final double? costoEnvio;
  final String? observacion;

  CheckoutRequest({
    required this.tipoEntrega,
    this.direccionId,
    this.costoEnvio,
    this.observacion,
  });

  Map<String, dynamic> toJson() => {
    'tipo_entrega': tipoEntrega.toServerString(),
    if (direccionId != null) 'direccion_id': direccionId,
    if (costoEnvio != null) 'costo_envio': costoEnvio,
    if (observacion != null && observacion!.isNotEmpty)
      'observacion': observacion,
  };
}
