import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drapemind_mobile/core/config/api_config.dart';
import 'package:drapemind_mobile/core/network/api_client.dart';
import 'package:drapemind_mobile/core/network/api_exception.dart';
import 'package:drapemind_mobile/core/services/company_service.dart';

class CheckoutConfirmation {
  final ApiClient api;
  CheckoutConfirmation(this.api);
  Future<bool> hasPending() async {
    final claims = CompanyService.claims(await api.getToken());
    if (claims == null) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(
      'drapemind.checkout.pending|${ApiConfig.apiV1Url}|${claims['tid']}:${claims['sub']}',
    );
  }

  String canonical(Map<String, dynamic> value) {
    final keys = value.keys.toList()..sort();
    return jsonEncode({for (final k in keys) k: value[k]});
  }

  String uuid() {
    final r = Random.secure();
    final bytes = List.generate(16, (_) => r.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final s = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
  }

  Future<dynamic> confirm(Map<String, dynamic> body) async {
    final token = await api.getToken();
    final claims = CompanyService.claims(token);
    if (token == null || claims?['tid'] == null || claims?['sub'] == null) {
      throw AuthException('Inicia sesión en la tienda antes de confirmar.');
    }
    final key =
        'drapemind.checkout.pending|${ApiConfig.apiV1Url}|${claims!['tid']}:${claims['sub']}';
    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.getString(key);
    Map<String, dynamic> pending;
    if (previous != null) {
      pending = Map<String, dynamic>.from(jsonDecode(previous));
      try {
        final order = await api.get(
          '/orders/checkout-operations/${pending['operacion_id']}',
          headers: {'Authorization': 'Bearer $token'},
        );
        await prefs.remove(key);
        return order;
      } on ApiException catch (e) {
        if (e.statusCode != 404) rethrow;
      }
      final saved = {...pending}..remove('operacion_id');
      if (canonical(saved) != canonical(body)) {
        throw ApiException(
          'Hay una confirmación pendiente. Conserva sus opciones de entrega para comprobarla antes de iniciar otra compra.',
        );
      }
    } else {
      pending = {...body, 'operacion_id': uuid()};
      final saved = await prefs.setString(key, jsonEncode(pending));
      if (!saved) {
        throw ApiException(
          'No se pudo guardar la confirmación de forma segura.',
        );
      }
    }
    if (await api.getToken() != token) {
      throw AuthException(
        'La sesión cambió; la confirmación sigue guardada en su cuenta.',
      );
    }
    try {
      final order = await api.post(
        '/orders/checkout',
        body: pending,
        headers: {'Authorization': 'Bearer $token'},
      );
      await prefs.remove(key);
      return order;
    } on ApiException catch (e) {
      if ([404, 409, 422].contains(e.statusCode)) await prefs.remove(key);
      rethrow;
    }
  }
}
