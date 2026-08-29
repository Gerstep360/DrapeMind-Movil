import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'api_exception.dart';

/// Core HTTP Client for DrapeMind Mobile with automatic Bearer token injection,
/// custom headers, timeout management, and standardized error parsing.
class ApiClient {
  static const String _tokenKey = 'drapemind_auth_token';
  final http.Client _httpClient;

  ApiClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  /// Retrieve stored JWT access token
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Save JWT access token
  Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  /// Remove stored JWT access token
  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  /// Construct base headers with optional auth token
  Future<Map<String, String>> _buildHeaders({
    Map<String, String>? extraHeaders,
    bool requiresAuth = true,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requiresAuth) {
      final token = await getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }
    return headers;
  }

  Uri _buildUri(String path, [Map<String, dynamic>? queryParams]) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final urlString = '${ApiConfig.apiV1Url}$cleanPath';
    final uri = Uri.parse(urlString);

    if (queryParams != null && queryParams.isNotEmpty) {
      final stringParams = <String, String>{};
      queryParams.forEach((key, value) {
        if (value != null && value.toString().isNotEmpty) {
          stringParams[key] = value.toString();
        }
      });
      return uri.replace(queryParameters: stringParams);
    }
    return uri;
  }

  dynamic _processResponse(http.Response response) {
    dynamic body;
    if (response.body.isNotEmpty) {
      try {
        body = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        body = response.body;
      }
    }

    final code = response.statusCode;
    if (code >= 200 && code < 300) {
      return body;
    }

    String errorMessage = 'Error en la petición ($code)';
    if (body is Map && body.containsKey('detail')) {
      final detail = body['detail'];
      if (detail is String) {
        errorMessage = detail;
      } else if (detail is List) {
        errorMessage = detail.map((e) => e['msg'] ?? e.toString()).join(', ');
      } else {
        errorMessage = detail.toString();
      }
    }

    switch (code) {
      case 401:
        throw AuthException(errorMessage, statusCode: 401, details: body);
      case 403:
        throw ForbiddenException(errorMessage, statusCode: 403, details: body);
      case 404:
        throw NotFoundException(errorMessage, statusCode: 404, details: body);
      case 422:
        throw ValidationException(errorMessage, statusCode: 422, details: body);
      default:
        if (code >= 500) {
          throw ServerException(errorMessage, statusCode: code, details: body);
        }
        throw ApiException(errorMessage, statusCode: code, details: body);
    }
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    bool requiresAuth = true,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      final uri = _buildUri(path, queryParams);
      final finalHeaders = await _buildHeaders(
        extraHeaders: headers,
        requiresAuth: requiresAuth,
      );
      final response = await _httpClient
          .get(uri, headers: finalHeaders)
          .timeout(timeout);
      return _processResponse(response);
    } on SocketException catch (e) {
      throw NetworkException(
        'Sin conexión a Internet o servidor no disponible.',
        details: e,
      );
    } on TimeoutException catch (e) {
      throw NetworkException(
        'Tiempo de espera agotado al comunicarse con el servidor.',
        details: e,
      );
    } on http.ClientException catch (e) {
      throw NetworkException(
        'Error en el cliente de red: ${e.message}',
        details: e,
      );
    }
  }

  /// Retrieve a binary resource with the same auth and error semantics.
  Future<Uint8List> getBytes(
    String path, {
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    bool requiresAuth = true,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      final uri = _buildUri(path, queryParams);
      final finalHeaders = await _buildHeaders(
        extraHeaders: {'Accept': 'image/png', ...?headers},
        requiresAuth: requiresAuth,
      );
      final response = await _httpClient
          .get(uri, headers: finalHeaders)
          .timeout(timeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.bodyBytes;
      }
      _processResponse(response);
      throw ApiException('No se pudo descargar el recurso.');
    } on SocketException catch (e) {
      throw NetworkException(
        'Sin conexión a Internet o servidor no disponible.',
        details: e,
      );
    } on TimeoutException catch (e) {
      throw NetworkException(
        'Tiempo de espera agotado al comunicarse con el servidor.',
        details: e,
      );
    } on http.ClientException catch (e) {
      throw NetworkException(
        'Error en el cliente de red: ${e.message}',
        details: e,
      );
    }
  }

  Future<dynamic> post(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    bool requiresAuth = true,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    try {
      final uri = _buildUri(path, queryParams);
      final finalHeaders = await _buildHeaders(
        extraHeaders: headers,
        requiresAuth: requiresAuth,
      );
      final payload = body != null ? jsonEncode(body) : null;
      final response = await _httpClient
          .post(uri, headers: finalHeaders, body: payload)
          .timeout(timeout);
      return _processResponse(response);
    } on SocketException catch (e) {
      throw NetworkException(
        'Sin conexión a Internet o servidor no disponible.',
        details: e,
      );
    } on TimeoutException catch (e) {
      throw NetworkException(
        'Tiempo de espera agotado al comunicarse con el servidor.',
        details: e,
      );
    } on http.ClientException catch (e) {
      throw NetworkException(
        'Error en el cliente de red: ${e.message}',
        details: e,
      );
    }
  }

  Future<dynamic> put(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    bool requiresAuth = true,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    try {
      final uri = _buildUri(path, queryParams);
      final finalHeaders = await _buildHeaders(
        extraHeaders: headers,
        requiresAuth: requiresAuth,
      );
      final payload = body != null ? jsonEncode(body) : null;
      final response = await _httpClient
          .put(uri, headers: finalHeaders, body: payload)
          .timeout(timeout);
      return _processResponse(response);
    } on SocketException catch (e) {
      throw NetworkException(
        'Sin conexión a Internet o servidor no disponible.',
        details: e,
      );
    } on TimeoutException catch (e) {
      throw NetworkException(
        'Tiempo de espera agotado al comunicarse con el servidor.',
        details: e,
      );
    } on http.ClientException catch (e) {
      throw NetworkException(
        'Error en el cliente de red: ${e.message}',
        details: e,
      );
    }
  }

  Future<dynamic> patch(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    bool requiresAuth = true,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    try {
      final uri = _buildUri(path, queryParams);
      final finalHeaders = await _buildHeaders(
        extraHeaders: headers,
        requiresAuth: requiresAuth,
      );
      final payload = body != null ? jsonEncode(body) : null;
      final response = await _httpClient
          .patch(uri, headers: finalHeaders, body: payload)
          .timeout(timeout);
      return _processResponse(response);
    } on SocketException catch (e) {
      throw NetworkException(
        'Sin conexión a Internet o servidor no disponible.',
        details: e,
      );
    } on TimeoutException catch (e) {
      throw NetworkException(
        'Tiempo de espera agotado al comunicarse con el servidor.',
        details: e,
      );
    } on http.ClientException catch (e) {
      throw NetworkException(
        'Error en el cliente de red: ${e.message}',
        details: e,
      );
    }
  }

  Future<dynamic> delete(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    bool requiresAuth = true,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    try {
      final uri = _buildUri(path, queryParams);
      final finalHeaders = await _buildHeaders(
        extraHeaders: headers,
        requiresAuth: requiresAuth,
      );
      final payload = body != null ? jsonEncode(body) : null;
      final response = await _httpClient
          .delete(uri, headers: finalHeaders, body: payload)
          .timeout(timeout);
      return _processResponse(response);
    } on SocketException catch (e) {
      throw NetworkException(
        'Sin conexión a Internet o servidor no disponible.',
        details: e,
      );
    } on TimeoutException catch (e) {
      throw NetworkException(
        'Tiempo de espera agotado al comunicarse con el servidor.',
        details: e,
      );
    } on http.ClientException catch (e) {
      throw NetworkException(
        'Error en el cliente de red: ${e.message}',
        details: e,
      );
    }
  }
}
