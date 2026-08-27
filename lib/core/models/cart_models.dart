import '../config/api_config.dart';

class CartItem {
  final int id;
  final int varianteId;
  final int productoId;
  final String nombre;
  final String sku;
  final String color;
  final String talla;
  final int cantidad;
  final double precioUnitario;
  final double subtotal;
  final int stockDisponible;
  final String? imagen;

  CartItem({
    required this.id,
    required this.varianteId,
    required this.productoId,
    required this.nombre,
    required this.sku,
    required this.color,
    required this.talla,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
    this.stockDisponible = 0,
    this.imagen,
  });

  String get fullImageUrl => ApiConfig.resolveMediaUrl(imagen);

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      varianteId: json['variante_id'] is int
          ? json['variante_id']
          : int.parse(json['variante_id'].toString()),
      productoId: json['producto_id'] is int
          ? json['producto_id']
          : int.parse((json['producto_id'] ?? json['id']).toString()),
      nombre: json['nombre'] ?? '',
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
      stockDisponible: json['stock_disponible'] is int
          ? json['stock_disponible']
          : int.tryParse(json['stock_disponible'].toString()) ?? 0,
      imagen: json['imagen'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'variante_id': varianteId,
        'producto_id': productoId,
        'nombre': nombre,
        'sku': sku,
        'color': color,
        'talla': talla,
        'cantidad': cantidad,
        'precio_unitario': precioUnitario,
        'subtotal': subtotal,
        'stock_disponible': stockDisponible,
        'imagen': imagen,
      };
}

class Cart {
  final int id;
  final String estado;
  final List<CartItem> items;
  final int totalItems;
  final double subtotal;

  Cart({
    required this.id,
    this.estado = 'ACTIVO',
    this.items = const [],
    this.totalItems = 0,
    this.subtotal = 0.0,
  });

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  factory Cart.fromJson(Map<String, dynamic> json) {
    List<CartItem> parsedItems = [];
    if (json['items'] is List) {
      parsedItems = (json['items'] as List)
          .map((i) => CartItem.fromJson(i as Map<String, dynamic>))
          .toList();
    }

    return Cart(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      estado: json['estado'] ?? 'ACTIVO',
      items: parsedItems,
      totalItems: json['total_items'] is int
          ? json['total_items']
          : int.tryParse(json['total_items'].toString()) ?? parsedItems.length,
      subtotal: json['subtotal'] is num
          ? (json['subtotal'] as num).toDouble()
          : double.tryParse(json['subtotal'].toString()) ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'estado': estado,
        'items': items.map((i) => i.toJson()).toList(),
        'total_items': totalItems,
        'subtotal': subtotal,
      };
}

class BatchCartItemRequest {
  final int varianteId;
  final int cantidad;

  BatchCartItemRequest({required this.varianteId, this.cantidad = 1});

  Map<String, dynamic> toJson() => {
        'variante_id': varianteId,
        'cantidad': cantidad,
      };
}
