import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'company_service.dart';

/// Read-only cache. Payments, sales and stock mutations always require the server.
class OfflineCatalog {
  static final active = ValueNotifier<bool>(false);
  static String? owner(String? token) {
    final claims = CompanyService.claims(token);
    if (claims?['tid'] is! int || claims?['sub'] == null) return null;
    if ((claims?['exp'] as num? ?? 0) * 1000 <=
        DateTime.now().millisecondsSinceEpoch) {
      return null;
    }
    return '${claims!['tid']}_${claims['sub']}';
  }

  static bool catalogPath(String path) =>
      path == '/catalog/products' ||
      path.startsWith('/catalog/products/') ||
      path == '/branches' ||
      path.startsWith('/branches/');
  static String cacheKey(String owner, String resource) =>
      'dm_offline_${owner}_${Uri.encodeComponent(resource)}';
  static Future<void> save(
    String? owner,
    String path,
    String resource,
    dynamic value,
  ) async {
    if (owner == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (path == '/saas/me') {
      await prefs.setString('dm_license_$owner', jsonEncode(value));
    }
    if (catalogPath(path)) {
      await prefs.setString(cacheKey(owner, resource), jsonEncode(value));
    }
    active.value = false;
  }

  static Future<dynamic> read(
    String? owner,
    String path,
    String resource,
  ) async {
    if (owner == null || !catalogPath(path)) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('dm_license_$owner');
    if (raw == null) return null;
    final license = jsonDecode(raw);
    final end = DateTime.tryParse(license['subscription']?['ends_at'] ?? '');
    if (license['access_active'] != true ||
        license['plan']?['features']?['offline'] != true ||
        end == null ||
        !end.isAfter(DateTime.now())) {
      return null;
    }
    final cached = prefs.getString(cacheKey(owner, resource));
    if (cached == null) return null;
    active.value = true;
    return jsonDecode(cached);
  }
}
