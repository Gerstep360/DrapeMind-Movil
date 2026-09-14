import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecurityService extends ChangeNotifier {
  static const String _keyPinEnabled = 'drapemind_pin_enabled';
  static const String _keyUserPin = 'drapemind_user_pin';
  static const String _keyBiometricEnabled = 'drapemind_biometric_enabled';
  static const String _keyCachedUser = 'drapemind_cached_user';

  bool _isPinEnabled = false;
  String? _userPin;
  bool _isBiometricEnabled = false;
  bool _isLocked = false;
  bool _isInitialized = false;

  SecurityService() {
    _loadSecurityPreferences();
  }

  bool get isPinEnabled => _isPinEnabled;
  bool get isBiometricEnabled => _isBiometricEnabled;
  bool get isLocked => _isLocked;
  bool get isInitialized => _isInitialized;

  Future<void> _loadSecurityPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isPinEnabled = prefs.getBool(_keyPinEnabled) ?? false;
      _userPin = prefs.getString(_keyUserPin);
      _isBiometricEnabled = prefs.getBool(_keyBiometricEnabled) ?? false;

      // Si tiene PIN o Huella configurada, iniciamos la app bloqueada para proteger compras/saldo
      if (_isPinEnabled && _userPin != null && _userPin!.isNotEmpty) {
        _isLocked = true;
      }
    } catch (_) {}
    _isInitialized = true;
    notifyListeners();
  }

  /// Configura o cambia el PIN de 4 dígitos
  Future<bool> setPin(String pin, {bool enableBiometric = true}) async {
    if (pin.length != 4 || int.tryParse(pin) == null) return false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserPin, pin);
    await prefs.setBool(_keyPinEnabled, true);
    await prefs.setBool(_keyBiometricEnabled, enableBiometric);

    _userPin = pin;
    _isPinEnabled = true;
    _isBiometricEnabled = enableBiometric;
    _isLocked = false; // Al configurar queda desbloqueado
    notifyListeners();
    return true;
  }

  /// Desactiva el bloqueo por PIN
  Future<void> disablePin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserPin);
    await prefs.setBool(_keyPinEnabled, false);
    await prefs.setBool(_keyBiometricEnabled, false);

    _userPin = null;
    _isPinEnabled = false;
    _isBiometricEnabled = false;
    _isLocked = false;
    notifyListeners();
  }

  /// Intenta desbloquear con el PIN de 4 dígitos ingresado
  bool verifyAndUnlock(String enteredPin) {
    if (_userPin != null && _userPin == enteredPin) {
      _isLocked = false;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Desbloqueo rápido biométrico / simulación de sensor
  Future<bool> unlockWithBiometrics() async {
    if (!_isBiometricEnabled) return false;
    // Simulamos verificación exitosa de huella
    _isLocked = false;
    notifyListeners();
    return true;
  }

  /// Bloquea manualmente la app (ej. al salir o poner en pausa)
  void lockApp() {
    if (_isPinEnabled) {
      _isLocked = true;
      notifyListeners();
    }
  }

  /// Desbloqueo de emergencia al cerrar sesión completa
  void resetLock() {
    _isLocked = false;
    notifyListeners();
  }

  // --- PERSISTENCIA DEL PERFIL DE USUARIO CACHEADO ---
  Future<void> cacheUserProfile(Map<String, dynamic> userJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCachedUser, jsonEncode(userJson));
  }

  Future<Map<String, dynamic>?> getCachedUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyCachedUser);
      if (raw != null && raw.isNotEmpty) {
        return jsonDecode(raw) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<void> clearCachedUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCachedUser);
  }
}
