import 'dart:convert';
import 'dart:typed_data';
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

  DeferredStore? get _store =>
      offline == null ? null : DeferredStore(store: offline!.store);
  bool _unavailable(ApiException error) =>
      error is NetworkException || [502, 503, 504].contains(error.statusCode);
  void _checkScope(String? scope) {
    if (scope != _scope) {
      throw ApiException('La tienda cambió. Abre nuevamente tus pedidos.');
    }
  }

  Future<Map<String, dynamic>?> _cached(
    String? scope, [
    String suffix = '',
  ]) async {
    await offline?.ready;
    if (scope == null || scope != _scope || offline?.usable != true) {
      return null;
    }
    final saved = await _store!.context('$scope$suffix');
    final stamp = DateTime.tryParse(saved?['saved_at']?.toString() ?? '');
    if (scope != _scope ||
        stamp == null ||
        stamp.add(const Duration(days: 7)).isBefore(DateTime.now())) {
      return null;
    }
    return saved;
  }

  /// Explicit download retrieves every authorized page, not only the first 50.
  /// Commit the complete history only after every page has succeeded.
  Future<int> prepareDownload({void Function(int count)? onProgress}) async {
    final scope = _scope;
    if (scope == null) {
      throw ApiException('Abre una tienda para descargar tus pedidos.');
    }
    final rows = <Map<String, dynamic>>[];
    int? cursor;
    while (true) {
      final page =
          await _apiClient.get(
                '/orders',
                queryParams: {
                  'limit': 200,
                  if (cursor != null) 'before_id': cursor,
                },
              )
              as List;
      _checkScope(scope);
      final parsed = page.map((r) => Map<String, dynamic>.from(r)).toList();
      if (parsed.any(
        (r) =>
            r['id'] is! int || (cursor != null && (r['id'] as int) >= cursor),
      )) {
        throw ApiException(
          'No se pudo completar el historial. Vuelve a actualizar la descarga.',
        );
      }
      rows.addAll(parsed);
      onProgress?.call(rows.length);
      if (parsed.length < 200) break;
      cursor = parsed
          .map((r) => r['id'] as int)
          .reduce((a, b) => a < b ? a : b);
    }
    for (final row in rows) {
      final id = row['id'] as int;
      final receipt = Map<String, dynamic>.from(
        await _apiClient.get(
          '/orders/$id/receipt',
          queryParams: {'format': 'json'},
        ),
      );
      _checkScope(scope);
      Uint8List? pdf;
      if ([
        'PAGADO',
        'PREPARANDO',
        'LISTO',
        'ENVIADO',
        'ENTREGADO',
        'DEVUELTO',
      ].contains(row['estado'])) {
        pdf = await _apiClient.getBytes(
          '/orders/$id/receipt.pdf',
          headers: {'Accept': 'application/pdf'},
        );
        if (!utf8
            .decode(pdf.take(5).toList(), allowMalformed: true)
            .startsWith('%PDF-')) {
          throw ApiException(
            'No se pudo guardar un comprobante. Reintenta la descarga.',
          );
        }
      }
      _checkScope(scope);
      await _store!.saveContext('$scope|receipt:$id', {
        'receipt': receipt,
        if (pdf != null) 'pdf': base64Encode(pdf),
        'saved_at': DateTime.now().toUtc().toIso8601String(),
      });
    }
    _checkScope(scope);
    await _store!.saveContext(scope, {
      'orders': rows,
      'complete': true,
      'saved_at': DateTime.now().toUtc().toIso8601String(),
    });
    _checkScope(scope);
    return rows.length;
  }

  Future<List<Order>> getMyOrders({int? beforeId, int limit = 50}) async {
    final scope = _scope;
    Future<List<dynamic>> cached() async {
      final saved = await _cached(scope);
      final rows = (saved?['orders'] as List?) ?? [];
      // The normal orders tab shows the entire downloaded history offline.
      return beforeId == null
          ? rows
          : rows.where((r) => (r['id'] as int) < beforeId).take(limit).toList();
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
        _checkScope(scope);
        if (scope != null && response is List) {
          try {
            final prior = await _store!.context(scope);
            _checkScope(scope);
            final merged = {
              for (final row in (prior?['orders'] as List?) ?? [])
                row['id']: row,
              for (final row in response) row['id']: row,
            };
            final rows = merged.values.toList()
              ..sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
            // A partial online refresh must not extend the lifetime of older rows.
            await _store!.saveContext(scope, {
              'orders': rows,
              'saved_at':
                  prior?['saved_at'] ??
                  DateTime.now().toUtc().toIso8601String(),
            });
          } catch (_) {
            /* Online history is still available if storage is full. */
          }
        }
      }
    } on ApiException catch (error) {
      if (offline == null || !_unavailable(error)) rethrow;
      offline!.useDownloadedData();
      response = await cached();
    }
    _checkScope(scope);
    return (response as List)
        .map((o) => Order.fromJson(Map<String, dynamic>.from(o)))
        .toList();
  }

  Future<Order> getOrderDetail(int orderId) async {
    final scope = _scope;
    try {
      if (offline?.online == false) throw NetworkException('Sin conexión');
      final response = await _apiClient.get('/orders/$orderId');
      _checkScope(scope);
      return Order.fromJson(Map<String, dynamic>.from(response));
    } on ApiException catch (error) {
      if (offline == null || !_unavailable(error)) rethrow;
      offline!.useDownloadedData();
      final rows = (await _cached(scope))?['orders'] as List? ?? [];
      final row = rows.where((r) => r['id'] == orderId).firstOrNull;
      if (row == null) {
        throw ApiException(
          'Este pedido no está guardado. Actualiza la descarga con conexión.',
        );
      }
      return Order.fromJson(Map<String, dynamic>.from(row));
    }
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

  Future<Map<String, dynamic>> getOrderReceipt(int orderId) async {
    final scope = _scope;
    try {
      if (offline?.online == false) throw NetworkException('Sin conexión');
      final receipt = Map<String, dynamic>.from(
        await _apiClient.get(
          '/orders/$orderId/receipt',
          queryParams: {'format': 'json'},
        ),
      );
      _checkScope(scope);
      if (scope != null) {
        try {
          final prior = await _store!.context('$scope|receipt:$orderId');
          _checkScope(scope);
          final sameReceipt =
              prior?['pdf'] != null &&
              jsonEncode(prior?['receipt']) == jsonEncode(receipt);
          await _store!.saveContext('$scope|receipt:$orderId', {
            'receipt': receipt,
            if (sameReceipt) 'pdf': prior!['pdf'],
            'saved_at': sameReceipt
                ? prior!['saved_at']
                : DateTime.now().toUtc().toIso8601String(),
          });
        } catch (_) {
          /* Confirmed online data remains usable. */
        }
      }
      return receipt;
    } on ApiException catch (error) {
      if (offline == null || !_unavailable(error)) rethrow;
      offline!.useDownloadedData();
      final data = await _cached(scope, '|receipt:$orderId');
      if (data?['receipt'] == null) {
        throw ApiException(
          'Este comprobante no está descargado. Recupera conexión para consultarlo.',
        );
      }
      return Map<String, dynamic>.from(data!['receipt']);
    }
  }

  Future<bool> downloadReceipt(int orderId) async {
    final scope = _scope;
    Uint8List bytes;
    try {
      if (offline?.online == false) throw NetworkException('Sin conexión');
      bytes = await _apiClient.getBytes(
        '/orders/$orderId/receipt.pdf',
        headers: {'Accept': 'application/pdf'},
      );
      _checkScope(scope);
    } on ApiException catch (error) {
      if (offline == null || !_unavailable(error)) rethrow;
      final saved = await _cached(scope, '|receipt:$orderId');
      if (saved?['pdf'] == null) {
        throw ApiException(
          'El PDF no está descargado. Recupera conexión para obtenerlo.',
        );
      }
      bytes = base64Decode(saved!['pdf']);
    }
    _checkScope(scope);
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
  Future<Map<String, dynamic>> quoteExchange(
    Map<String, dynamic> payload,
  ) async {
    final response = await _apiClient.post(
      '/retail/exchanges',
      queryParams: {'preview': 'true'},
      body: payload,
    );
    return Map<String, dynamic>.from(response as Map);
  }

  /// Confirmar cambio o devolución de prendas
  Future<Map<String, dynamic>> exchangeResult(String operation) async =>
      Map<String, dynamic>.from(
        await _apiClient.get('/retail/exchanges/operations/$operation'),
      );

  Future<List<Map<String, dynamic>>> exchangeProducts(String query) async =>
      (await _apiClient.get(
                '/catalog/products',
                queryParams: {'q': query, 'limit': 20, 'offset': 0},
              )
              as List)
          .map((r) => Map<String, dynamic>.from(r))
          .toList();

  Future<Map<String, dynamic>> exchangeProduct(int id) async =>
      Map<String, dynamic>.from(await _apiClient.get('/catalog/products/$id'));
  Future<List<Map<String, dynamic>>> exchangeAvailability(int id) async =>
      (await _apiClient.get('/branches/products/$id/availability') as List)
          .map((r) => Map<String, dynamic>.from(r))
          .toList();

  Future<Map<String, dynamic>> confirmExchange(
    Map<String, dynamic> payload,
  ) async {
    final response = await _apiClient.post('/retail/exchanges', body: payload);
    return Map<String, dynamic>.from(response as Map);
  }
}
