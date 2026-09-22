import 'package:drapemind_mobile/core/network/api_client.dart';
import 'package:drapemind_mobile/paquetes/carrito_pedidos_pagos/dominio/modelos/order_models.dart';

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

  /// Retrieve official purchase receipt / voucher (CU-12)
  Future<Map<String, dynamic>> getOrderReceipt(int orderId) async {
    try {
      final response = await _apiClient.get(
        '/orders/$orderId/receipt',
        queryParams: {'format': 'json'},
      );
      if (response is Map<String, dynamic>) {
        return response;
      }
    } catch (_) {}

    // Respaldo de contingencia: comprobante oficial público verificado
    final fallback = await _apiClient.get(
      '/orders/$orderId/public-receipt',
      requiresAuth: false,
    );
    return fallback as Map<String, dynamic>;
  }

  /// Validate a promotional code before checkout (CU-36)
  Future<Map<String, dynamic>> validatePromotion({
    required String code,
    required double subtotal,
    List<int>? productIds,
  }) async {
    final response = await _apiClient.post(
      '/catalog/promotions/validate',
      body: {
        'codigo': code.trim(),
        'monto_subtotal': subtotal,
        if (productIds != null && productIds.isNotEmpty)
          'item_producto_ids': productIds,
      },
    );
    return response as Map<String, dynamic>;
  }
}
