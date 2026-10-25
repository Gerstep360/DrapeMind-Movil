import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drapemind_mobile/core/network/api_client.dart';
import 'package:drapemind_mobile/core/network/api_exception.dart';
import 'package:drapemind_mobile/paquetes/acceso_gestion_usuarios/dominio/modelos/auth_models.dart';
import 'package:drapemind_mobile/paquetes/acceso_gestion_usuarios/dominio/modelos/style_profile_models.dart';
import 'security_service.dart';
import 'package:drapemind_mobile/core/services/company_service.dart';

class AuthService extends ChangeNotifier {
  final ApiClient _apiClient;
  User? _currentUser;
  bool _isLoading = false;
  bool _isRestoring = false;
  bool _onboardingSkipped = false;
  String? _token;
  String? _destination;
  String? _storeEntryError;
  Timer? _expiryTimer;

  AuthService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  User? get currentUser => _currentUser;
  bool get hasValidToken => _token != null && _isTokenUsable(_token!);
  bool get isAuthenticated => _currentUser != null && hasValidToken;
  bool get isAdmin => !isPlatformAdmin && _currentUser?.rol == UserRole.admin;
  bool get isPlatformAdmin => _currentUser?.isPlatformAdmin == true;
  String? get destination => _destination;
  String? get storeEntryError => _storeEntryError;
  bool get isVendedor => _currentUser?.rol == UserRole.vendedor;
  bool get isEncargado => _currentUser?.rol == UserRole.encargado;
  bool get isCajero => _currentUser?.rol == UserRole.cajero;
  bool get isLoading => _isLoading;
  bool get isRestoring => _isRestoring;
  bool get onboardingSkipped => _onboardingSkipped;
  String? get token => _token;

  /// Check token in storage and load user profile (sesion persistente estilo Facebook)
  Future<bool> tryAutoLogin() async {
    _isRestoring = true;
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
      final requestedStore = CompanyService.entrySlug;
      if (CompanyService.entrySlug != null &&
          cached?['tenant_slug'] != CompanyService.entrySlug &&
          cached?['is_universal_customer'] != true) {
        await logout();
        return false;
      }
      if (cached != null &&
          cached['tenant_id'] == CompanyService.claims(savedToken)?['tid'] &&
          cached['id'].toString() ==
              CompanyService.claims(savedToken)?['sub']) {
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
        await CompanyService.useAccount(_currentUser!.tenantSlug);
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

      if (requestedStore != null &&
          _currentUser?.isUniversalCustomer == true &&
          _currentUser?.tenantSlug != requestedStore) {
        try {
          await enterStore(requestedStore);
        } on ApiException catch (e) {
          _storeEntryError = e.message;
        } catch (_) {
          _storeEntryError =
              'No pudimos abrir esta tienda. Intenta nuevamente.';
        }
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (_) {
      return _currentUser != null;
    } finally {
      _isRestoring = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Login with email and password
  Future<User> login(String email, String password) async {
    await logout();
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _apiClient.post(
        '/auth/login',
        body: {
          ...LoginRequest(
            email: email.trim().toLowerCase(),
            password: password,
          ).toJson(),
          if (CompanyService.entrySlug != null)
            'tenant_slug': CompanyService.entrySlug,
        },
        requiresAuth: false,
        timeout: const Duration(seconds: 20),
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
      final userResponse =
          response['user'] ??
          await _apiClient.get('/auth/me', timeout: const Duration(seconds: 8));
      _currentUser = User.fromJson(userResponse);
      await CompanyService.useAccount(
        _currentUser!.tenantSlug ?? response['tenant']?['slug'],
      );
      _destination = response['redirect_path'] as String?;
      await SecurityService().cacheUserProfile(userResponse);
      return _currentUser!;
    } catch (_) {
      await logout();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Register a new user
  Future<void> enterStore(String slug) async {
    _storeEntryError = null;
    final response = await _apiClient.post('/auth/store', body: {'slug': slug});
    final data = Map<String, dynamic>.from(response);
    final tokenData = TokenResponse.fromJson(data);
    await _apiClient.setToken(tokenData.accessToken);
    _token = tokenData.accessToken;
    _scheduleTokenExpiry(_token!);
    _currentUser = User.fromJson(data['user']);
    await CompanyService.useAccount(_currentUser!.tenantSlug);
    await SecurityService().cacheUserProfile(data['user']);
    _destination = data['redirect_path'];
    _onboardingSkipped = false;
    notifyListeners();
  }

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
      body: profile.toJson(inferOutfit: false, inferStyle: true),
      timeout: const Duration(seconds: 60),
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
    _destination = null;
    _storeEntryError = null;
    _onboardingSkipped = false;
    await _apiClient.clearToken();
    await SecurityService().clearSecurityState();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('drapemind_cached_style_profile');
      await prefs.remove('ai_quest_occ');
      await prefs.remove('ai_quest_top_type');
      await prefs.remove('ai_quest_top_size');
      await prefs.remove('ai_quest_bot_type');
      await prefs.remove('ai_quest_bot_size');
      await prefs.remove('ai_quest_shoe');
      await prefs.remove('ai_quest_budget');
      await prefs.remove('dm_device_push_token');
    } catch (_) {}
    notifyListeners();
  }

  bool _isTokenUsable(String token) {
    if (token.trim().isEmpty) return false;
    final claims = CompanyService.claims(token);
    if (claims == null ||
        (claims['tid'] is! int && claims['platform'] != true)) {
      return false;
    }
    final expiry = _tokenExpiry(token);
    // Si el token tiene fecha de expiracion explicita, verificar que no haya vencido
    if (expiry != null) {
      return expiry.isAfter(
        DateTime.now().toUtc().add(const Duration(seconds: 5)),
      );
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
