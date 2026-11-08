import 'package:drapemind_mobile/core/network/api_client.dart';
import 'package:drapemind_mobile/segundo_parcial/cu24_pedidos/cu24_order_models.dart';
import 'package:drapemind_mobile/segundo_parcial/cu22_carrito_checkout/cu22_checkout_confirmation.dart';
import 'package:drapemind_mobile/segundo_parcial/cu25_reportes_voz/cu25_native_actions.dart';

class OrderService {
  final ApiClient _apiClient;

  OrderService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// Retrieve the current user's order history
  Future<List<Order>> getMyOrders({int? beforeId, int limit = 50}) async {
    final response = await _apiClient.get(
      '/orders',
      queryParams: {
        'limit': limit,
        if (beforeId != null) 'before_id': beforeId,
      },
    );
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
    final response = await CheckoutConfirmation(
      _apiClient,
    ).confirm(request.toJson());
    return Order.fromJson(response as Map<String, dynamic>);
  }

  /// Cancel an order (if in pending state)
  Future<Order> cancelOrder(int orderId) async {
    final response = await _apiClient.post('/orders/$orderId/cancel', body: {});
    return Order.fromJson(response as Map<String, dynamic>);
  }

  /// Retrieve official purchase receipt / voucher (CU-12)
  Future<Map<String, dynamic>> getOrderReceipt(int orderId) async {
    final response = await _apiClient.get(
      '/orders/$orderId/receipt',
      queryParams: {'format': 'json'},
    );
    return Map<String, dynamic>.from(response);
  }

  Future<bool> downloadReceipt(int orderId) async {
    final bytes = await _apiClient.getBytes(
      '/orders/$orderId/receipt.pdf',
      headers: {'Accept': 'application/pdf'},
    );
    return NativeActions().savePdf('comprobante-$orderId.pdf', bytes);
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
