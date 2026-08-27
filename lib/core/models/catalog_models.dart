import '../config/api_config.dart';

class Category {
  final int id;
  final String nombre;
  final String slug;
  final String? descripcion;
  final int? parentId;
  final bool activo;

  Category({
    required this.id,
    required this.nombre,
    required this.slug,
    this.descripcion,
    this.parentId,
    this.activo = true,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      nombre: json['nombre'] ?? '',
      slug: json['slug'] ?? '',
      descripcion: json['descripcion'],
      parentId: json['parent_id'],
      activo: json['activo'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'slug': slug,
        'descripcion': descripcion,
        'parent_id': parentId,
        'activo': activo,
      };
}

class ProductVariant {
  final int id;
  final int productoId;
  final String sku;
  final String color;
  final String? codigoColor;
  final String talla;
  final int stockTotal;
  final int stockReservado;
  final int stockDisponible;
  final String? imagen;
  final bool activo;

  ProductVariant({
    required this.id,
    required this.productoId,
    required this.sku,
    required this.color,
    this.codigoColor,
    required this.talla,
    required this.stockTotal,
    required this.stockReservado,
    required this.stockDisponible,
    this.imagen,
    this.activo = true,
  });

  String get fullImageUrl => ApiConfig.resolveMediaUrl(imagen);

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      productoId: json['producto_id'] is int
          ? json['producto_id']
          : int.parse((json['producto_id'] ?? json['id']).toString()),
      sku: json['sku'] ?? '',
      color: json['color'] ?? '',
      codigoColor: json['codigo_color'],
      talla: json['talla'] ?? '',
      stockTotal: json['stock_total'] is int
          ? json['stock_total']
          : int.tryParse(json['stock_total'].toString()) ?? 0,
      stockReservado: json['stock_reservado'] is int
          ? json['stock_reservado']
          : int.tryParse(json['stock_reservado'].toString()) ?? 0,
      stockDisponible: json['stock_disponible'] is int
          ? json['stock_disponible']
          : int.tryParse(json['stock_disponible'].toString()) ?? 0,
      imagen: json['imagen'],
      activo: json['activo'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'producto_id': productoId,
        'sku': sku,
        'color': color,
        'codigo_color': codigoColor,
        'talla': talla,
        'stock_total': stockTotal,
        'stock_reservado': stockReservado,
        'stock_disponible': stockDisponible,
        'imagen': imagen,
        'activo': activo,
      };
}

class Product {
  final int id;
  final int categoriaId;
  final String nombre;
  final String? descripcion;
  final String? marca;
  final String? material;
  final double precio;
  final double? costoReferencia;
  final int calidadNivel;
  final String generoObjetivo;
  final String? descripcionAi;
  final List<String>? tagsAi;
  final List<String> imagenes;
  final bool activo;
  final DateTime createdAt;
  final int stockDisponible;
  final List<ProductVariant> variantes;

  Product({
    required this.id,
    required this.categoriaId,
    required this.nombre,
    this.descripcion,
    this.marca,
    this.material,
    required this.precio,
    this.costoReferencia,
    this.calidadNivel = 3,
    this.generoObjetivo = 'UNISEX',
    this.descripcionAi,
    this.tagsAi,
    this.imagenes = const [],
    this.activo = true,
    required this.createdAt,
    this.stockDisponible = 0,
    this.variantes = const [],
  });

  String get mainImageUrl {
    if (imagenes.isNotEmpty) {
      return ApiConfig.resolveMediaUrl(imagenes.first);
    }
    if (variantes.isNotEmpty && variantes.first.imagen != null) {
      return variantes.first.fullImageUrl;
    }
    return '';
  }

  List<String> get allImageUrls =>
      imagenes.map((img) => ApiConfig.resolveMediaUrl(img)).toList();

  factory Product.fromJson(Map<String, dynamic> json) {
    List<String> parsedImages = [];
    if (json['imagenes'] is List) {
      for (final it in json['imagenes']) {
        if (it is String) {
          parsedImages.add(it);
        } else if (it is Map && it['url'] != null) {
          parsedImages.add(it['url'].toString());
        }
      }
    }

    List<ProductVariant> parsedVariants = [];
    if (json['variantes'] is List) {
      parsedVariants = (json['variantes'] as List)
          .map((v) => ProductVariant.fromJson(v as Map<String, dynamic>))
          .toList();
    }

    List<String>? parsedTags;
    if (json['tags_ai'] is List) {
      parsedTags = (json['tags_ai'] as List).map((t) => t.toString()).toList();
    }

    return Product(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      categoriaId: json['categoria_id'] is int
          ? json['categoria_id']
          : int.tryParse(json['categoria_id'].toString()) ?? 0,
      nombre: json['nombre'] ?? '',
      descripcion: json['descripcion'],
      marca: json['marca'],
      material: json['material'],
      precio: json['precio'] is num
          ? (json['precio'] as num).toDouble()
          : double.tryParse(json['precio'].toString()) ?? 0.0,
      costoReferencia: json['costo_referencia'] is num
          ? (json['costo_referencia'] as num).toDouble()
          : null,
      calidadNivel: json['calidad_nivel'] is int
          ? json['calidad_nivel']
          : int.tryParse(json['calidad_nivel'].toString()) ?? 3,
      generoObjetivo: json['genero_objetivo'] ?? 'UNISEX',
      descripcionAi: json['descripcion_ai'],
      tagsAi: parsedTags,
      imagenes: parsedImages,
      activo: json['activo'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      stockDisponible: json['stock_disponible'] is int
          ? json['stock_disponible']
          : int.tryParse(json['stock_disponible'].toString()) ?? 0,
      variantes: parsedVariants,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'categoria_id': categoriaId,
        'nombre': nombre,
        'descripcion': descripcion,
        'marca': marca,
        'material': material,
        'precio': precio,
        'costo_referencia': costoReferencia,
        'calidad_nivel': calidadNivel,
        'genero_objetivo': generoObjetivo,
        'descripcion_ai': descripcionAi,
        'tags_ai': tagsAi,
        'imagenes': imagenes,
        'activo': activo,
        'created_at': createdAt.toIso8601String(),
        'stock_disponible': stockDisponible,
        'variantes': variantes.map((v) => v.toJson()).toList(),
      };
}
