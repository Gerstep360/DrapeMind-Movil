import 'package:flutter/foundation.dart';
import 'package:drapemind_mobile/core/network/api_client.dart';
import 'package:drapemind_mobile/paquetes/carrito_pedidos_pagos/dominio/modelos/cart_models.dart';

class CartService extends ChangeNotifier {
  final ApiClient _apiClient;
  Cart? _cart;
  bool _isLoading = false;

  CartService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  Cart? get cart => _cart;
  int get itemCount => _cart?.totalItems ?? 0;
  double get subtotal => _cart?.subtotal ?? 0.0;
  bool get isEmpty => _cart == null || _cart!.isEmpty;
  bool get isLoading => _isLoading;

  /// Load or refresh the user's active cart
  Future<Cart> getCart() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _apiClient.get('/cart');
      _cart = Cart.fromJson(response as Map<String, dynamic>);
      return _cart!;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add a single item/variant to cart
  Future<Cart> addItem(int varianteId, {int cantidad = 1}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _apiClient.post(
        '/cart/items',
        body: {'variante_id': varianteId, 'cantidad': cantidad},
      );
      _cart = Cart.fromJson(response as Map<String, dynamic>);
      return _cart!;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add a batch of items to cart
  Future<Cart> addBatch(List<BatchCartItemRequest> items) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _apiClient.post(
        '/cart/items/batch',
        body: {'items': items.map((i) => i.toJson()).toList()},
      );
      _cart = Cart.fromJson(response as Map<String, dynamic>);
      return _cart!;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Replace entire cart with a new selection (e.g. AI full outfit selection)
  Future<Cart> replaceCartWithBatch(List<BatchCartItemRequest> items) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _apiClient.put(
        '/cart/items/batch',
        body: {'items': items.map((i) => i.toJson()).toList()},
      );
      _cart = Cart.fromJson(response as Map<String, dynamic>);
      return _cart!;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update item quantity
  Future<Cart> updateItemQuantity(int itemId, int cantidad) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _apiClient.patch(
        '/cart/items/$itemId',
        body: {'cantidad': cantidad},
      );
      _cart = Cart.fromJson(response as Map<String, dynamic>);
      return _cart!;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Delete an item from cart
  Future<Cart> removeItem(int itemId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _apiClient.delete('/cart/items/$itemId');
      _cart = Cart.fromJson(response as Map<String, dynamic>);
      return _cart!;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear cart cache locally
  void clearLocal() {
    _cart = null;
    notifyListeners();
  }

  /// CU-22: Check style coherence of the current cart
  Future<Map<String, dynamic>> checkStyle({String? objetivo, int? sesionId}) async {
    final body = <String, dynamic>{
      'objetivo': objetivo ?? 'Evaluar coherencia cromática y estilo del perchero',
      if (sesionId != null) 'sesion_id': sesionId,
    };
    final response = await _apiClient.post('/ai/cart/style-check', body: body);
    return response as Map<String, dynamic>;
  }

  /// CU-23: Optimize outfit for value, quality and savings
  Future<Map<String, dynamic>> checkValue({String? objetivo, int? sesionId}) async {
    final body = <String, dynamic>{
      'objetivo': objetivo ?? 'Optimizar calidad, precio y balance de ahorro del perchero',
      if (sesionId != null) 'sesion_id': sesionId,
    };
    final response = await _apiClient.post('/ai/cart/value-check', body: body);
    return response as Map<String, dynamic>;
  }
}
