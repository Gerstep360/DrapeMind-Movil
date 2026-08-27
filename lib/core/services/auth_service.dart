import 'dart:async';
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

  AuthService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null && _token != null;
  bool get isAdmin => _currentUser?.rol == UserRole.admin;
  bool get isVendedor => _currentUser?.rol == UserRole.vendedor;
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
      _token = savedToken;

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

      final tokenData = TokenResponse.fromJson(response as Map<String, dynamic>);
      _token = tokenData.accessToken;
      await _apiClient.setToken(_token!);

      // Fetch and cache user profile
      final userResponse = await _apiClient.get('/auth/me', timeout: const Duration(seconds: 8));
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
    } catch (_) {
      return null;
    }
  }

  /// Logout and clear storage
  Future<void> logout() async {
    _currentUser = null;
    _token = null;
    await _apiClient.clearToken();
    notifyListeners();
  }
}
