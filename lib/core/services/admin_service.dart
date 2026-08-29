import '../models/admin_metrics_models.dart';
import '../models/catalog_models.dart';
import '../models/order_models.dart';
import '../models/reservation_models.dart';
import '../network/api_client.dart';

class AdminService {
  final ApiClient _apiClient;

  AdminService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// Create a new product
  Future<Product> createProduct(Map<String, dynamic> productData) async {
    final response = await _apiClient.post(
      '/admin/products',
      body: productData,
    );
    return Product.fromJson(response as Map<String, dynamic>);
  }

  /// Update an existing product
  Future<Product> updateProduct(
    int id,
    Map<String, dynamic> productData,
  ) async {
    final response = await _apiClient.put(
      '/admin/products/$id',
      body: productData,
    );
    return Product.fromJson(response as Map<String, dynamic>);
  }

  /// Add a variant to a product
  Future<ProductVariant> createVariant(
    int productId,
    Map<String, dynamic> variantData,
  ) async {
    final response = await _apiClient.post(
      '/admin/products/$productId/variants',
      body: variantData,
    );
    return ProductVariant.fromJson(response as Map<String, dynamic>);
  }

  /// Adjust stock for inventory
  Future<void> adjustInventory({
    required int varianteId,
    required int nuevoStockTotal,
    required String observacion,
  }) async {
    await _apiClient.post(
      '/admin/inventory/adjustments',
      body: {
        'variante_id': varianteId,
        'nuevo_stock_total': nuevoStockTotal,
        'observacion': observacion,
      },
    );
  }

  /// List all store reservations (admin/seller view)
  Future<List<Reservation>> getAdminReservations({String? state}) async {
    final queryParams = state != null ? {'state': state} : null;
    final response = await _apiClient.get(
      '/admin/reservations',
      queryParams: queryParams,
    );
    if (response is List) {
      return response
          .map((r) => Reservation.fromJson(r as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// List all store orders (admin/seller view)
  Future<List<Order>> getAdminOrders({String? state}) async {
    final queryParams = state != null ? {'state': state} : null;
    final response = await _apiClient.get(
      '/admin/orders',
      queryParams: queryParams,
    );
    if (response is List) {
      return response
          .map((o) => Order.fromJson(o as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Update order status
  Future<Order> updateOrderStatus(int orderId, OrderStatus newStatus) async {
    final response = await _apiClient.patch(
      '/orders/$orderId/status',
      body: {'estado': newStatus.toServerString()},
    );
    return Order.fromJson(response as Map<String, dynamic>);
  }

  /// Confirm in-store cash payment
  Future<Order> confirmCashPayment(int orderId) async {
    final response = await _apiClient.post(
      '/orders/$orderId/cash-confirm',
      body: {},
    );
    return Order.fromJson(response as Map<String, dynamic>);
  }

  /// Get sales and inventory metrics
  Future<SalesInventoryMetrics> getMetrics() async {
    final response = await _apiClient.get('/admin/metrics/sales-inventory');
    return SalesInventoryMetrics.fromJson(response as Map<String, dynamic>);
  }

  /// Get AI Engine runtime status
  Future<AiRuntimeStatus> getAiRuntimeStatus() async {
    final response = await _apiClient.get('/admin/ai/runtime');
    return AiRuntimeStatus.fromJson(response as Map<String, dynamic>);
  }

  /// Start AI Engine manually
  Future<AiRuntimeStatus> startAi() async {
    final response = await _apiClient.post('/admin/ai/runtime/start', body: {});
    return AiRuntimeStatus.fromJson(response as Map<String, dynamic>);
  }

  /// Stop AI Engine manually
  Future<AiRuntimeStatus> stopAi() async {
    final response = await _apiClient.post('/admin/ai/runtime/stop', body: {});
    return AiRuntimeStatus.fromJson(response as Map<String, dynamic>);
  }
}
