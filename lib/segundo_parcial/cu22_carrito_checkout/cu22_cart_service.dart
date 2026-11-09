import 'cu22_carrito_local.dart';
import '../cu13_catalogo_offline/cu13_offline_service.dart';
import '../cu23_pagos/cu23_deferred_store.dart';
import 'package:drapemind_mobile/core/network/api_exception.dart';
import 'package:flutter/foundation.dart';
import 'package:drapemind_mobile/core/network/api_client.dart';
import 'package:drapemind_mobile/segundo_parcial/cu22_carrito_checkout/cu22_cart_models.dart';

class CartService extends ChangeNotifier {
  final ApiClient _apiClient;
  Cart? _cart;
  LocalCart? _local;
  bool _disposed = false;
  String? get localIssue => _local?.issue;
  Future<void> keepSelection() async {
    await _local?.keepSelection();
  }

  OfflineService? get offline => _local?.offline;
  void _publish() {
    if (!_disposed) notifyListeners();
  }

  Future<void> synchronizeDraft() async {
    await _local?.synchronize();
    if (_local?.dirty == true && _local?.issue != null) {
      throw ApiException(_local!.issue!);
    }
  }

  Future<void> finishLocalCheckout() async {
    await _local?.edit('replace');
  }

  Future<Cart> _acceptRemote(dynamic response, String? scope) async {
    final result = Cart.fromJson(Map<String, dynamic>.from(response));
    if (scope == _owner) {
      if (_local != null) {
        await _local!.accept(result, scope);
      } else {
        _cart = result;
      }
    }
    return _cart ?? result;
  }

  bool _isLoading = false;
  String? _owner;
  String? get owner => _owner;
  void bindOwner(String? owner) {
    if (owner != _owner) {
      _owner = owner;
      _cart = null;
      _local?.bind(owner);
    }
  }

  CartService({
    ApiClient? apiClient,
    OfflineService? offline,
    DeferredStore? localStore,
  }) : _apiClient = apiClient ?? ApiClient() {
    if (offline != null) {
      _local = LocalCart(
        offline: offline,
        api: _apiClient,
        store: localStore,
        changed: (cart) {
          if (!_disposed) {
            _cart = cart;
            _publish();
          }
        },
      );
    }
  }

  Cart? get cart => _cart;
  int get itemCount => _cart?.totalItems ?? 0;
  double get subtotal => _cart?.subtotal ?? 0.0;
  bool get isEmpty => _cart == null || _cart!.isEmpty;
  bool get isLoading => _isLoading;

  /// Load or refresh the user's active cart
  Future<Cart> getCart() async {
    final scope = _owner;
    await _local?.ready;
    if (_local?.active == true) {
      await _local!.ready;
      await _local!.synchronize();
      if (_local!.current != null) return _local!.current!;
    }
    _isLoading = true;
    _publish();
    try {
      final response = await _apiClient.get('/cart');
      return _acceptRemote(response, scope);
    } on NetworkException {
      if (_local != null) {
        _local!.offline.useDownloadedData();
        if (_local?.current != null) return _local!.current!;
      }
      rethrow;
    } finally {
      _isLoading = false;
      _publish();
    }
  }

  /// Add a single item/variant to cart
  Future<Cart> addItem(int varianteId, {int cantidad = 1}) async {
    final scope = _owner;
    await _local?.ready;
    if (_local?.active == true) {
      return _local!.edit(
        'add',
        items: [
          {'variante_id': varianteId, 'cantidad': cantidad},
        ],
      );
    }
    _isLoading = true;
    _publish();
    try {
      final response = await _apiClient.post(
        '/cart/items',
        body: {'variante_id': varianteId, 'cantidad': cantidad},
      );
      return _acceptRemote(response, scope);
    } on NetworkException {
      if (_local != null) {
        _local!.offline.useDownloadedData();
        return _local!.edit(
          'add',
          items: [
            {'variante_id': varianteId, 'cantidad': cantidad},
          ],
        );
      }
      rethrow;
    } finally {
      _isLoading = false;
      _publish();
    }
  }

  /// Add a batch of items to cart
  Future<Cart> addBatch(List<BatchCartItemRequest> items) async {
    final scope = _owner;
    await _local?.ready;
    if (_local?.active == true) {
      return _local!.edit('add', items: items.map((i) => i.toJson()).toList());
    }
    _isLoading = true;
    _publish();
    try {
      final response = await _apiClient.post(
        '/cart/items/batch',
        body: {'items': items.map((i) => i.toJson()).toList()},
      );
      return _acceptRemote(response, scope);
    } on NetworkException {
      if (_local != null) {
        _local!.offline.useDownloadedData();
        return _local!.edit(
          'add',
          items: items.map((i) => i.toJson()).toList(),
        );
      }
      rethrow;
    } finally {
      _isLoading = false;
      _publish();
    }
  }

  /// Replace entire cart with a new selection (e.g. AI full outfit selection)
  Future<Cart> replaceCartWithBatch(List<BatchCartItemRequest> items) async {
    final scope = _owner;
    await _local?.ready;
    if (_local?.active == true) {
      return _local!.edit(
        'replace',
        items: items.map((i) => i.toJson()).toList(),
      );
    }
    _isLoading = true;
    _publish();
    try {
      final response = await _apiClient.put(
        '/cart/items/batch',
        body: {'items': items.map((i) => i.toJson()).toList()},
      );
      return _acceptRemote(response, scope);
    } on NetworkException {
      if (_local != null) {
        _local!.offline.useDownloadedData();
        return _local!.edit(
          'replace',
          items: items.map((i) => i.toJson()).toList(),
        );
      }
      rethrow;
    } finally {
      _isLoading = false;
      _publish();
    }
  }

  /// Update item quantity
  Future<Cart> updateItemQuantity(int itemId, int cantidad) async {
    final scope = _owner;
    await _local?.ready;
    if (_local?.active == true) {
      return _local!.edit(
        cantidad <= 0 ? 'remove' : 'quantity',
        id: itemId,
        quantity: cantidad,
      );
    }
    _isLoading = true;
    _publish();
    try {
      final response = await _apiClient.patch(
        '/cart/items/$itemId',
        body: {'cantidad': cantidad},
      );
      return _acceptRemote(response, scope);
    } on NetworkException {
      if (_local != null) {
        _local!.offline.useDownloadedData();
        return _local!.edit(
          cantidad <= 0 ? 'remove' : 'quantity',
          id: itemId,
          quantity: cantidad,
        );
      }
      rethrow;
    } finally {
      _isLoading = false;
      _publish();
    }
  }

  /// Delete an item from cart
  Future<Cart> removeItem(int itemId) async {
    final scope = _owner;
    await _local?.ready;
    if (_local?.active == true) return _local!.edit('remove', id: itemId);
    _isLoading = true;
    _publish();
    try {
      final response = await _apiClient.delete('/cart/items/$itemId');
      return _acceptRemote(response, scope);
    } on NetworkException {
      if (_local != null) {
        _local!.offline.useDownloadedData();
        return _local!.edit('remove', id: itemId);
      }
      rethrow;
    } finally {
      _isLoading = false;
      _publish();
    }
  }

  /// Clear cart cache locally
  void clearLocal() {
    _cart = null;
    _publish();
  }

  /// CU-22: Check style coherence of the current cart
  Future<Map<String, dynamic>> checkStyle({
    String? objetivo,
    int? sesionId,
  }) async {
    final body = <String, dynamic>{
      'objetivo':
          objetivo ?? 'Evaluar coherencia cromática y estilo del perchero',
      if (sesionId != null) 'sesion_id': sesionId,
    };
    final response = await _apiClient.post('/ai/cart/style-check', body: body);
    return response as Map<String, dynamic>;
  }

  /// CU-23: Optimize outfit for value, quality and savings
  Future<Map<String, dynamic>> checkValue({
    String? objetivo,
    int? sesionId,
  }) async {
    final body = <String, dynamic>{
      'objetivo':
          objetivo ??
          'Optimizar calidad, precio y balance de ahorro del perchero',
      if (sesionId != null) 'sesion_id': sesionId,
    };
    final response = await _apiClient.post('/ai/cart/value-check', body: body);
    return response as Map<String, dynamic>;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
