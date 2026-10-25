import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CompanyService {
  static const key = 'drapemind_company';
  static String? entrySlug;

  static Future<void> useAccount(String? slug) async {
    if (slug != null && slug.isNotEmpty) {
      await select(slug);
    } else {
      await (await SharedPreferences.getInstance()).remove(key);
    }
    entrySlug = null;
  }

  static String? slugFromLink(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) return null;
    final parts = uri.pathSegments;
    final index = parts.indexOf('tienda');
    final slug = uri.scheme == 'drapemind' && uri.host == 'tienda'
        ? (parts.isNotEmpty ? parts.first : null)
        : index >= 0 && index + 1 < parts.length
        ? parts[index + 1]
        : null;
    if (slug == null || !RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(slug)) {
      return null;
    }
    return slug;
  }

  static Future<bool> acceptStoreLink(String value) async {
    final slug = slugFromLink(value);
    if (slug == null) return false;
    entrySlug = slug;
    await select(slug);
    return true;
  }

  static Future<String> selected() async =>
      (await SharedPreferences.getInstance()).getString(key) ?? 'drapemind';

  static Future<void> select(String value) async {
    final slug = value.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(slug)) {
      throw const FormatException('Identificador de empresa inválido');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, slug);
  }

  static Map<String, dynamic>? claims(String? token) {
    try {
      return jsonDecode(
            utf8.decode(
              base64Url.decode(base64Url.normalize(token!.split('.')[1])),
            ),
          )
          as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
