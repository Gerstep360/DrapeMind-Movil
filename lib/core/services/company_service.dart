import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CompanyService {
  static const key = 'drapemind_company';
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
