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
  final bool healthy;
  final bool managed;
  final bool running;
  final int activeRequests;
  final int? idleSeconds;
  final int idleTimeoutSeconds;
  final String model;
  final bool modelExists;
  final bool mmprojExists;
  final String? executable;
  final String platform;

  AiRuntimeStatus({
    required this.healthy,
    required this.managed,
    required this.running,
    required this.activeRequests,
    this.idleSeconds,
    required this.idleTimeoutSeconds,
    required this.model,
    required this.modelExists,
    required this.mmprojExists,
    this.executable,
    required this.platform,
  });

  factory AiRuntimeStatus.fromJson(Map<String, dynamic> json) {
    return AiRuntimeStatus(
      healthy: json['healthy'] ?? false,
      managed: json['managed'] ?? false,
      running: json['running'] ?? false,
      activeRequests: json['active_requests'] is int
          ? json['active_requests']
          : int.tryParse(json['active_requests']?.toString() ?? '0') ?? 0,
      idleSeconds: json['idle_seconds'] is int
          ? json['idle_seconds']
          : int.tryParse(json['idle_seconds']?.toString() ?? ''),
      idleTimeoutSeconds: json['idle_timeout_seconds'] is int
          ? json['idle_timeout_seconds']
          : int.tryParse(json['idle_timeout_seconds']?.toString() ?? '600') ??
                600,
      model: json['model']?.toString() ?? '',
      modelExists: json['model_exists'] ?? false,
      mmprojExists: json['mmproj_exists'] ?? false,
      executable: json['executable']?.toString(),
      platform: json['platform']?.toString() ?? 'windows',
    );
  }
}
