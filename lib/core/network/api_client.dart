import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'api_exception.dart';
import '../services/company_service.dart';
import '../services/offline_catalog.dart';

/// Core HTTP Client for DrapeMind Mobile with automatic Bearer token injection,
/// custom headers, timeout management, and standardized error parsing.
class ApiClient {
  static const String _tokenKey = 'drapemind_auth_token';
  final http.Client _httpClient;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  ApiClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  /// Retrieve stored JWT access token from hardware-backed secure storage
  Future<String?> getToken() async {
    try {
      final secureToken = await _secureStorage.read(key: _tokenKey);
      if (secureToken != null && secureToken.isNotEmpty) {
        return secureToken;
      }
    } catch (_) {}

    // Fallback y migracion desde SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacyToken = prefs.getString(_tokenKey);
      if (legacyToken != null && legacyToken.isNotEmpty) {
        try {
          await _secureStorage.write(key: _tokenKey, value: legacyToken);
          await prefs.remove(_tokenKey);
          return legacyToken;
        } catch (_) {
          return null;
        }
      }
    } catch (_) {}

    return null;
  }

  /// Save JWT access token permanently in secure storage
  Future<void> setToken(String token) async {
    try {
      await _secureStorage.write(key: _tokenKey, value: token);
    } catch (_) {
      throw ApiException(
        'No se pudo guardar la sesión de forma segura. Intenta nuevamente.',
      );
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
    } catch (_) {}
  }

  /// Remove stored JWT access token
  Future<void> clearToken() async {
    try {
      await _secureStorage.delete(key: _tokenKey);
      await _secureStorage.deleteAll();
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
    } catch (_) {}
  }

  /// Construct base headers with optional auth token
  Future<Map<String, String>> _buildHeaders({
    Map<String, String>? extraHeaders,
    bool requiresAuth = true,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Tenant': await CompanyService.selected(),
    };

    if (requiresAuth) {
      final token = await getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
        headers.remove(
          'X-Tenant',
        ); // Authenticated company comes exclusively from JWT.
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
      } else if (detail is Map && detail['message'] is String) {
        errorMessage = detail['message'];
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

  Future<void> _validateScope(Map<String, String> headers) async {
    if (headers.containsKey('X-Tenant') &&
        headers['X-Tenant'] != await CompanyService.selected()) {
      throw AuthException('La empresa seleccionada ha cambiado.');
    }
    final before = CompanyService.claims(
      headers['Authorization']?.replaceFirst('Bearer ', ''),
    );
    final after = CompanyService.claims(await getToken());
    if (before != null &&
        (before['tid'] != after?['tid'] ||
            before['sub'] != after?['sub'] ||
            before['platform'] != after?['platform'])) {
      throw AuthException('La cuenta ha cambiado.');
    }
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    bool requiresAuth = true,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final owner = OfflineCatalog.owner(await getToken());
    final resource = _buildUri(path, queryParams).toString();
    try {
      final value = await _getNetwork(
        path,
        queryParams: queryParams,
        headers: headers,
        requiresAuth: requiresAuth,
        timeout: timeout,
      );
      await OfflineCatalog.save(owner, path, resource, value);
      return value;
    } on NetworkException {
      if (owner != OfflineCatalog.owner(await getToken())) rethrow;
      final cached = await OfflineCatalog.read(owner, path, resource);
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<dynamic> _getNetwork(
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
      await _validateScope(finalHeaders);
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
      await _validateScope(finalHeaders);
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
      if (path == '/auth/login') {
        finalHeaders.remove('X-Tenant');
        finalHeaders.remove('Authorization');
      }
      final payload = body != null ? jsonEncode(body) : null;
      final response = await _httpClient
          .post(uri, headers: finalHeaders, body: payload)
          .timeout(timeout);
      if (path != '/auth/login') await _validateScope(finalHeaders);
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
      await _validateScope(finalHeaders);
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
      await _validateScope(finalHeaders);
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
      await _validateScope(finalHeaders);
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
