import '../cu13_catalogo_offline/cu13_offline_service.dart';
import '../cu23_pagos/cu23_deferred_store.dart';
import 'package:drapemind_mobile/core/config/api_config.dart';
import 'package:drapemind_mobile/core/network/api_client.dart';
import 'package:drapemind_mobile/core/network/api_exception.dart';
import 'package:drapemind_mobile/segundo_parcial/cu24_pedidos/cu24_order_models.dart';
import 'package:drapemind_mobile/segundo_parcial/cu22_carrito_checkout/cu22_checkout_confirmation.dart';
import 'package:drapemind_mobile/segundo_parcial/cu25_reportes_voz/cu25_native_actions.dart';

class OrderService {
  final ApiClient _apiClient;
  final OfflineService? offline;
  String? get _scope {
    final user = offline?.auth.currentUser;
    return user == null
        ? null
        : '${ApiConfig.apiV1Url}|${user.tenantId}:${user.id}|orders:${user.rol.toServerString()}';
  }

  OrderService({ApiClient? apiClient, this.offline})
    : _apiClient = apiClient ?? ApiClient();

  /// Retrieve the current user's order history
  Future<List<Order>> getMyOrders({int? beforeId, int limit = 50}) async {
    final scope = _scope;
    final store = offline == null ? null : DeferredStore(store: offline!.store);
    Future<List<dynamic>> cached() async {
      await offline?.ready;
      if (scope == null || scope != _scope || offline?.usable != true) {
        return [];
      }
      final saved = await store!.context(scope);
      if (scope != _scope ||
          saved == null ||
          DateTime.parse(
            saved['saved_at'],
          ).add(const Duration(days: 7)).isBefore(DateTime.now())) {
        return [];
      }
      return saved['orders'] as List;
    }

    dynamic response;
    try {
      if (offline?.online == false) {
        response = await cached();
      } else {
        response = await _apiClient.get(
          '/orders',
          queryParams: {
            'limit': limit,
            if (beforeId != null) 'before_id': beforeId,
          },
        );
        if (scope != null &&
            scope == _scope &&
            beforeId == null &&
            response is List) {
          try {
            await store!.saveContext(scope, {
              'orders': response,
              'saved_at': DateTime.now().toUtc().toIso8601String(),
            });
          } catch (_) {
            /* The confirmed history remains usable online. */
          }
        }
      }
    } on NetworkException {
      if (offline == null) rethrow;
      offline!.useDownloadedData();
      response = await cached();
    }
    if (scope != _scope) return [];
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

  /// Consultar venta/pedido para cambio o devolución (CU-20)
  Future<Map<String, dynamic>> findOrderForExchange(String code) async {
    final response = await _apiClient.get(
      '/retail/orders/find',
      queryParams: {'code': code.trim()},
    );
    return Map<String, dynamic>.from(response as Map);
  }

  /// Cotizar diferencia económica del cambio o devolución
  Future<Map<String, dynamic>> quoteExchange(Map<String, dynamic> payload) async {
    final response = await _apiClient.post(
      '/retail/exchanges',
      queryParams: {'preview': 'true'},
      body: payload,
    );
    return Map<String, dynamic>.from(response as Map);
  }

  /// Confirmar cambio o devolución de prendas
  Future<Map<String, dynamic>> confirmExchange(Map<String, dynamic> payload) async {
    final response = await _apiClient.post(
      '/retail/exchanges',
      body: payload,
    );
    return Map<String, dynamic>.from(response as Map);
  }
}
