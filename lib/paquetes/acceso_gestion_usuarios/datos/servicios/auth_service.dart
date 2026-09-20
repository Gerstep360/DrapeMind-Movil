import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drapemind_mobile/core/network/api_client.dart';
import 'package:drapemind_mobile/core/network/api_exception.dart';
import 'package:drapemind_mobile/paquetes/acceso_gestion_usuarios/dominio/modelos/auth_models.dart';
import 'package:drapemind_mobile/paquetes/acceso_gestion_usuarios/dominio/modelos/style_profile_models.dart';
import 'security_service.dart';

class AuthService extends ChangeNotifier {
  final ApiClient _apiClient;
  User? _currentUser;
  bool _isLoading = false;
  bool _onboardingSkipped = false;
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
  bool get onboardingSkipped => _onboardingSkipped;
  String? get token => _token;

  /// Check token in storage and load user profile (sesion persistente estilo Facebook)
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

      // 1. Restaurar perfil desde cache local de inmediato (sin bloqueo de red)
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
          timeout: const Duration(seconds: 5),
        );
        _currentUser = User.fromJson(userResponse);
        await SecurityService().cacheUserProfile(userResponse);
      } on ApiException catch (e) {
        // Solo cerrar sesion si el servidor rechaza explicitamente el token
        if (e.statusCode == 401 || e.statusCode == 403) {
          await logout();
          return false;
        }
      } catch (_) {
        // En caso de estar sin conexion o fallo transitorio,
        // se conserva la sesion activa del usuario con su token y perfil cacheados
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (_) {
      return _currentUser != null;
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
        timeout: const Duration(seconds: 5),
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

  void skipOnboarding() {
    _onboardingSkipped = true;
    notifyListeners();
  }

  void markStyleProfileCompleted() {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(hasStyleProfile: true);
      notifyListeners();
    }
  }

  Future<StyleProfile?> getStyleProfile() async {
    try {
      final response = await _apiClient.get('/users/me/style-profile');
      if (response is Map<String, dynamic>) {
        final profile = StyleProfile.fromJson(response);
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            'drapemind_cached_style_profile',
            jsonEncode(response),
          );
        } catch (_) {}
        return profile;
      }
      return null;
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    } catch (_) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString('drapemind_cached_style_profile');
        if (cached != null && cached.isNotEmpty) {
          return StyleProfile.fromJson(
            jsonDecode(cached) as Map<String, dynamic>,
          );
        }
      } catch (_) {}
      return null;
    }
  }

  Future<StyleProfile> saveStyleProfile(StyleProfile profile) async {
    final response = await _apiClient.post(
      '/users/me/style-profile',
      body: profile.toJson(inferOutfit: false),
    );
    final saved = StyleProfile.fromJson(response as Map<String, dynamic>);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'drapemind_cached_style_profile',
        jsonEncode(response),
      );
    } catch (_) {}
    markStyleProfileCompleted();
    return saved;
  }

  /// Logout and clear storage
  Future<void> logout() async {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    _currentUser = null;
    _token = null;
    _onboardingSkipped = false;
    await _apiClient.clearToken();
    await SecurityService().clearCachedUserProfile();
    notifyListeners();
  }

  bool _isTokenUsable(String token) {
    if (token.trim().isEmpty) return false;
    final expiry = _tokenExpiry(token);
    // Si el token tiene fecha de expiracion explicita, verificar que no haya vencido
    if (expiry != null) {
      return expiry.isAfter(DateTime.now().toUtc().add(const Duration(seconds: 5)));
    }
    // Si no se puede extraer la fecha o el token no tiene exp, se considera valido
    // hasta que el servidor devuelva 401 Unauthorized
    return true;
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
    _expiryTimer = null;
    // Sesion ilimitada/permanente estilo Facebook:
    // No programamos temporizadores de cierre de sesion forzado.
    // La sesion permanece activa indefinidamente hasta que el usuario pulse 'Cerrar sesion'
    // o el servidor responda con HTTP 401 Unauthorized.
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    super.dispose();
  }
}
