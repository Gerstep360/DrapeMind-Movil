import '../config/api_config.dart';

class SizeDimensionMetric {
  final double chest;
  final double shoulders;
  final double length;
  final double waist;
  final double hip;
  final double foot;

  SizeDimensionMetric({
    required this.chest,
    required this.shoulders,
    required this.length,
    required this.waist,
    required this.hip,
    required this.foot,
  });

  factory SizeDimensionMetric.fromJson(Map<String, dynamic> json) {
    return SizeDimensionMetric(
      chest: (json['chest'] as num?)?.toDouble() ?? 100.0,
      shoulders: (json['shoulders'] as num?)?.toDouble() ?? 45.0,
      length: (json['length'] as num?)?.toDouble() ?? 70.0,
      waist: (json['waist'] as num?)?.toDouble() ?? 84.0,
      hip: (json['hip'] as num?)?.toDouble() ?? 100.0,
      foot: (json['foot'] as num?)?.toDouble() ?? 26.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'chest': chest,
    'shoulders': shoulders,
    'length': length,
    'waist': waist,
    'hip': hip,
    'foot': foot,
  };
}

class ArConfigModel {
  final int productoId;
  final bool supported;
  final String mode;
  final String? assetUrl;
  final String instructions;
  final Map<String, SizeDimensionMetric> sizeMetrics;
  final double fabricElasticity;
  final String fitCategory;
  final List<String> availableSizes;
  final String? recommendedSize;
  final String material;

  ArConfigModel({
    required this.productoId,
    required this.supported,
    required this.mode,
    this.assetUrl,
    required this.instructions,
    required this.sizeMetrics,
    required this.fabricElasticity,
    required this.fitCategory,
    required this.availableSizes,
    this.recommendedSize,
    required this.material,
  });

  String get fullAssetUrl => ApiConfig.resolveMediaUrl(assetUrl);

  factory ArConfigModel.fromJson(Map<String, dynamic> json) {
    final rawMetrics = json['size_metrics'] as Map<String, dynamic>? ?? {};
    final metrics = <String, SizeDimensionMetric>{};
    rawMetrics.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        metrics[key] = SizeDimensionMetric.fromJson(value);
      }
    });

    return ArConfigModel(
      productoId: json['producto_id'] is int
          ? json['producto_id']
          : int.tryParse(json['producto_id'].toString()) ?? 0,
      supported: json['supported'] == true,
      mode: json['mode']?.toString() ?? '2d-overlay',
      assetUrl: json['asset_url']?.toString(),
      instructions: json['instructions']?.toString() ?? '',
      sizeMetrics: metrics,
      fabricElasticity: (json['fabric_elasticity'] as num?)?.toDouble() ?? 0.05,
      fitCategory: json['fit_category']?.toString() ?? 'regular',
      availableSizes: (json['available_sizes'] as List? ?? [])
          .map((s) => s.toString())
          .toList(),
      recommendedSize: json['recommended_size']?.toString(),
      material: json['material']?.toString() ?? 'Tejido DrapeMind',
    );
  }
}
