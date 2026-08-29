import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/auth_models.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';
import 'security_service.dart';

class AuthService extends ChangeNotifier {
  final ApiClient _apiClient;
  User? _currentUser;
  bool _isLoading = false;
  String? _token;
  Timer? _expiryTimer;

  AuthService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  User? get currentUser => _currentUser;
  bool get hasValidToken => _token != null && _isTokenUsable(_token!);
  bool get isAuthenticated => _currentUser != null && hasValidToken;
  bool get isAdmin => _currentUser?.rol == UserRole.admin;
  bool get isVendedor => _currentUser?.rol == UserRole.vendedor;
  bool get isEncargado => _currentUser?.rol == UserRole.encargado;
  bool get isCajero => _currentUser?.rol == UserRole.cajero;
  bool get isLoading => _isLoading;
  String? get token => _token;

  /// Check token in storage and load user profile
  Future<bool> tryAutoLogin() async {
    _isLoading = true;
    notifyListeners();
    try {
      final savedToken = await _apiClient.getToken();
      if (savedToken == null || savedToken.isEmpty) {
        _currentUser = null;
        _token = null;
        _isLoading = false;
        notifyListeners();
        return false;
      }
      if (!_isTokenUsable(savedToken)) {
        await logout();
        return false;
      }
      _token = savedToken;
      _scheduleTokenExpiry(savedToken);

      // 1. Restaurar perfil desde caché local de inmediato (sin esperas de red)
      final cached = await SecurityService().getCachedUserProfile();
      if (cached != null) {
        _currentUser = User.fromJson(cached);
        _isLoading = false;
        notifyListeners();
      }

      // 2. Refrescar datos con el servidor en segundo plano
      try {
        final userResponse = await _apiClient.get(
          '/auth/me',
          timeout: const Duration(seconds: 4),
        );
        _currentUser = User.fromJson(userResponse);
        await SecurityService().cacheUserProfile(userResponse);
      } on ApiException catch (e) {
        // Si el servidor indica token expirado o inválido, cerrar sesión de inmediato
        if (e.statusCode == 401 || e.statusCode == 403) {
          await logout();
          return false;
        }
        if (_currentUser == null) {
          await logout();
          return false;
        }
      } catch (_) {
        // Si falló la red pero teníamos caché y token, mantenemos la sesión activa
        if (_currentUser == null) {
          await logout();
          return false;
        }
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (_) {
      await logout();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Login with email and password
  Future<User> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _apiClient.post(
        '/auth/login',
        body: LoginRequest(email: email, password: password).toJson(),
        requiresAuth: false,
        timeout: const Duration(seconds: 10),
      );

      final tokenData = TokenResponse.fromJson(
        response as Map<String, dynamic>,
      );
      _token = tokenData.accessToken;
      if (!_isTokenUsable(_token!)) {
        throw const FormatException('El servidor devolvió un token inválido');
      }
      await _apiClient.setToken(_token!);
      _scheduleTokenExpiry(_token!);

      // Fetch and cache user profile
      final userResponse = await _apiClient.get(
        '/auth/me',
        timeout: const Duration(seconds: 8),
      );
      _currentUser = User.fromJson(userResponse);
      await SecurityService().cacheUserProfile(userResponse);
      return _currentUser!;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Register a new user
  Future<User> register({
    required String nombre,
    required String email,
    required String password,
    String? telefono,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _apiClient.post(
        '/auth/register',
        body: RegisterRequest(
          nombre: nombre,
          email: email,
          password: password,
          telefono: telefono,
        ).toJson(),
        requiresAuth: false,
      );
      final user = User.fromJson(response as Map<String, dynamic>);

      // Auto login after register
      await login(email, password);
      return user;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh current user profile
  Future<User?> fetchProfile() async {
    try {
      final response = await _apiClient.get('/auth/me');
      _currentUser = User.fromJson(response as Map<String, dynamic>);
      notifyListeners();
      return _currentUser;
    } on AuthException {
      await logout();
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<User> updateProfile({required String nombre, String? telefono}) async {
    final response = await _apiClient.patch(
      '/users/me',
      body: {
        'nombre': nombre.trim(),
        'telefono': telefono?.trim().isEmpty == true ? null : telefono?.trim(),
      },
    );
    _currentUser = User.fromJson(response as Map<String, dynamic>);
    await SecurityService().cacheUserProfile(response);
    notifyListeners();
    return _currentUser!;
  }

  /// Logout and clear storage
  Future<void> logout() async {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    _currentUser = null;
    _token = null;
    await _apiClient.clearToken();
    await SecurityService().clearCachedUserProfile();
    notifyListeners();
  }

  bool _isTokenUsable(String token) {
    final expiry = _tokenExpiry(token);
    return expiry != null &&
        expiry.isAfter(DateTime.now().toUtc().add(const Duration(seconds: 5)));
  }

  DateTime? _tokenExpiry(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload =
          jsonDecode(
                utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
              )
              as Map<String, dynamic>;
      final exp = payload['exp'];
      final seconds = exp is int ? exp : int.tryParse(exp?.toString() ?? '');
      if (seconds == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
    } catch (_) {
      return null;
    }
  }

  void _scheduleTokenExpiry(String token) {
    _expiryTimer?.cancel();
    final expiry = _tokenExpiry(token);
    if (expiry == null) {
      unawaited(logout());
      return;
    }
    final delay =
        expiry.difference(DateTime.now().toUtc()) - const Duration(seconds: 2);
    if (delay <= Duration.zero) {
      unawaited(logout());
      return;
    }
    _expiryTimer = Timer(delay, () => unawaited(logout()));
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }
}
