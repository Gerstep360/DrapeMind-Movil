class SalesMetrics {
  final int pedidosEntregados;
  final double ingresos;

  SalesMetrics({required this.pedidosEntregados, required this.ingresos});

  factory SalesMetrics.fromJson(Map<String, dynamic> json) {
    return SalesMetrics(
      pedidosEntregados: json['pedidos_entregados'] is int
          ? json['pedidos_entregados']
          : int.tryParse(json['pedidos_entregados']?.toString() ?? '0') ?? 0,
      ingresos: json['ingresos'] is num
          ? (json['ingresos'] as num).toDouble()
          : double.tryParse(json['ingresos']?.toString() ?? '0.0') ?? 0.0,
    );
  }
}

class InventoryMetrics {
  final int variantes;
  final int unidadesDisponibles;
  final int stockBajo;

  InventoryMetrics({
    required this.variantes,
    required this.unidadesDisponibles,
    required this.stockBajo,
  });

  factory InventoryMetrics.fromJson(Map<String, dynamic> json) {
    return InventoryMetrics(
      variantes: json['variantes'] is int
          ? json['variantes']
          : int.tryParse(json['variantes']?.toString() ?? '0') ?? 0,
      unidadesDisponibles: json['unidades_disponibles'] is int
          ? json['unidades_disponibles']
          : int.tryParse(json['unidades_disponibles']?.toString() ?? '0') ?? 0,
      stockBajo: json['stock_bajo'] is int
          ? json['stock_bajo']
          : int.tryParse(json['stock_bajo']?.toString() ?? '0') ?? 0,
    );
  }
}

class SalesInventoryMetrics {
  final SalesMetrics ventas;
  final InventoryMetrics inventario;

  SalesInventoryMetrics({required this.ventas, required this.inventario});

  factory SalesInventoryMetrics.fromJson(Map<String, dynamic> json) {
    return SalesInventoryMetrics(
      ventas: SalesMetrics.fromJson(
        json['ventas'] is Map ? json['ventas'] as Map<String, dynamic> : {},
      ),
      inventario: InventoryMetrics.fromJson(
        json['inventario'] is Map
            ? json['inventario'] as Map<String, dynamic>
            : {},
      ),
    );
  }
}

class AiRuntimeStatus {
  final String provider;
  final bool configured;
  final bool healthy;
  final String model;
  AiRuntimeStatus({
    required this.provider,
    required this.configured,
    required this.healthy,
    required this.model,
  });
  factory AiRuntimeStatus.fromJson(Map<String, dynamic> json) =>
      AiRuntimeStatus(
        provider: json['provider']?.toString() ?? 'nvidia',
        configured: json['configured'] == true,
        healthy: json['healthy'] == true,
        model: json['model']?.toString() ?? '',
      );
}
