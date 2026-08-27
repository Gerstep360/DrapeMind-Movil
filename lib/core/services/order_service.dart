import '../models/order_models.dart';
import '../network/api_client.dart';

class OrderService {
  final ApiClient _apiClient;

  OrderService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// Retrieve the current user's order history
  Future<List<Order>> getMyOrders() async {
    final response = await _apiClient.get('/orders');
    if (response is List) {
      return response
          .map((o) => Order.fromJson(o as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Get specific order details
  Future<Order> getOrderDetail(int orderId) async {
    final response = await _apiClient.get('/orders/$orderId');
    return Order.fromJson(response as Map<String, dynamic>);
  }

  /// Create an order from active cart (checkout)
  Future<Order> checkout(CheckoutRequest request) async {
    final response = await _apiClient.post(
      '/orders/checkout',
      body: request.toJson(),
    );
    return Order.fromJson(response as Map<String, dynamic>);
  }

  /// Cancel an order (if in pending state)
  Future<Order> cancelOrder(int orderId) async {
    final response = await _apiClient.patch(
      '/orders/$orderId/status',
      body: {'estado': 'CANCELADO'},
    );
    return Order.fromJson(response as Map<String, dynamic>);
  }
}
