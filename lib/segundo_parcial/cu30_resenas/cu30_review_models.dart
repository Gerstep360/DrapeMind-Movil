class ProductReviewItem {
  final int id;
  final int productoId;
  final int usuarioId;
  final int calificacion;
  final String? titulo;
  final String comentario;
  final bool compraVerificada;
  final String usuarioNombre;
  final String creadoEn;
  final String? actualizadoEn;

  ProductReviewItem({
    required this.id,
    required this.productoId,
    required this.usuarioId,
    required this.calificacion,
    this.titulo,
    required this.comentario,
    required this.compraVerificada,
    required this.usuarioNombre,
    required this.creadoEn,
    this.actualizadoEn,
  });

  factory ProductReviewItem.fromJson(Map<String, dynamic> json) {
    return ProductReviewItem(
      id: json['id'] as int,
      productoId: json['producto_id'] as int,
      usuarioId: json['usuario_id'] as int,
      calificacion: json['calificacion'] as int,
      titulo: json['titulo'] as String?,
      comentario: json['comentario'] as String? ?? '',
      compraVerificada: json['compra_verificada'] as bool? ?? false,
      usuarioNombre: json['usuario_nombre'] as String? ?? 'Cliente',
      creadoEn: json['creado_en'] as String? ?? '',
      actualizadoEn: json['actualizado_en'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'producto_id': productoId,
      'usuario_id': usuarioId,
      'calificacion': calificacion,
      'titulo': titulo,
      'comentario': comentario,
      'compra_verificada': compraVerificada,
      'usuario_nombre': usuarioNombre,
      'creado_en': creadoEn,
      'actualizado_en': actualizadoEn,
    };
  }
}

class ProductReviewsResponse {
  final int productoId;
  final double promedio;
  final int total;
  final Map<String, int> distribucion;
  final List<ProductReviewItem> resenas;
  final ProductReviewItem? miResena;

  ProductReviewsResponse({
    required this.productoId,
    required this.promedio,
    required this.total,
    required this.distribucion,
    required this.resenas,
    this.miResena,
  });

  factory ProductReviewsResponse.fromJson(Map<String, dynamic> json) {
    final rawDist = json['distribucion'] as Map<String, dynamic>? ?? {};
    final dist = rawDist.map((k, v) => MapEntry(k, (v as num).toInt()));

    final rawList = json['resenas'] as List<dynamic>? ?? [];
    final resenas = rawList
        .map((e) => ProductReviewItem.fromJson(e as Map<String, dynamic>))
        .toList();

    ProductReviewItem? miResena;
    if (json['mi_resena'] != null) {
      miResena = ProductReviewItem.fromJson(
        json['mi_resena'] as Map<String, dynamic>,
      );
    }

    return ProductReviewsResponse(
      productoId: json['producto_id'] as int,
      promedio: (json['promedio'] as num?)?.toDouble() ?? 0.0,
      total: json['total'] as int? ?? 0,
      distribucion: dist,
      resenas: resenas,
      miResena: miResena,
    );
  }
}
