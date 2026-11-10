import 'dart:math';
import '../../core/network/api_exception.dart';
import '../cu23_pagos/cu23_deferred_store.dart';
import '../cu24_pedidos/cu24_order_service.dart';

/// One immutable operation, saved before sending and recovered before any retry.
class ExchangeOperation {
  final OrderService api;
  final DeferredStore store;
  final String owner;
  final int orderId;
  final bool Function() authorized;
  Map<String, dynamic>? payload, result;
  ExchangeOperation({
    required this.api,
    required this.store,
    required this.owner,
    required this.orderId,
    required this.authorized,
  });
  String get key => '$owner|exchange:$orderId';
  void check() {
    if (!authorized()) {
      throw ApiException(
        'La sesión o la tienda cambió. Abre nuevamente tus pedidos.',
      );
    }
  }

  Future<void> restore() async {
    final saved = await store.context(key);
    check();
    if (saved?['payload'] != null) {
      payload = Map<String, dynamic>.from(saved!['payload']);
    }
    if (saved?['result'] != null) {
      result = Map<String, dynamic>.from(saved!['result']);
    }
  }

  Future<void> _save() =>
      store.saveContext(key, {'payload': payload, 'result': result});
  Future<Map<String, dynamic>?> recover() async {
    check();
    if (payload == null) return null;
    try {
      final data = await api.exchangeResult(payload!['operacion_id']);
      check();
      result = data;
      await _save();
      return data;
    } on ApiException catch (error) {
      if (error.statusCode != 404) rethrow;
      return null;
    }
  }

  Future<Map<String, dynamic>> confirm(Map<String, dynamic> selection) async {
    check();
    if (payload != null) {
      // Only a definitive 404 permits repeating the frozen request.
      try {
        result = await api.exchangeResult(payload!['operacion_id']);
        check();
        await _save();
        return result!;
      } on ApiException catch (error) {
        if (error.statusCode != 404) rethrow;
      }
    } else {
      payload = {...selection, 'operacion_id': uuid()};
    }
    // A failed first disk write must not let a later retry bypass durability.
    await _save();
    check();
    result = await api.confirmExchange(payload!);
    check();
    await _save();
    return result!;
  }

  Future<void> clearCompleted() async {
    check();
    if (result == null || result!['stripe_payment_needed'] == true) {
      throw ApiException(
        'Comprueba el resultado del cambio antes de iniciar otro.',
      );
    }
    await store.saveContext(key, {});
    payload = result = null;
  }

  static String uuid() {
    final random = Random.secure(), bytes = List<int>.generate(16, (_) => 0);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = random.nextInt(256);
    }
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final s = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
  }
}
