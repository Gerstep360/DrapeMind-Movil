import 'package:shared_preferences/shared_preferences.dart';

/// Global configuration for DrapeMind Backend API & WebSockets.
class ApiConfig {
  /// IP pública del servidor VPS oficial de producción
  static const String defaultServerIp = '167.86.106.105';
  static const int defaultServerPort = 80;
  static const String defaultPathPrefix = '/DrapeMind';

  /// Hosts predefinidos de fácil conmutación
  static const String hostVPS = '167.86.106.105';
  static const String hostLAN = '192.168.100.223:8000';
  static const String hostLocal = '127.0.0.1:8000';

  static String? _customHost;

  /// Carga la IP guardada previamente en el dispositivo, limpiando IPs antiguas deprecadas
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('custom_api_host');
      if (saved != null && saved.isNotEmpty) {
        if (saved.contains('157.173.102.129')) {
          await prefs.remove('custom_api_host');
          _customHost = null;
        } else {
          _customHost = saved.trim();
        }
      }
    } catch (_) {}
  }

  /// Cambia manualmente el host o IP (ej. '167.86.106.105', '127.0.0.1:8000', '192.168.100.223:8000')
  static Future<void> setCustomHost(String host) async {
    final clean = host.trim();
    if (clean.contains('157.173.102.129')) {
      await resetHost();
      return;
    }
    if (clean.isEmpty || clean == defaultServerIp) {
      await resetHost();
      return;
    }
    _customHost = clean;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('custom_api_host', clean);
    } catch (_) {}
  }

  /// Restablece el host al VPS oficial de producción (167.86.106.105)
  static Future<void> resetHost() async {
    _customHost = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('custom_api_host');
    } catch (_) {}
  }

  /// Host activo: usa el VPS de producción o el configurado (ADB Reverse / LAN)
  static String get defaultHost {
    if (_customHost != null && _customHost!.isNotEmpty) {
      if (_customHost!.contains('157.173.102.129')) {
        _customHost = null;
        return defaultServerIp;
      }
      return _customHost!;
    }
    return defaultServerIp;
  }

  static bool get isSecure => false;

  static String get httpScheme => isSecure ? 'https' : 'http';
  static String get wsScheme => isSecure ? 'wss' : 'ws';

  /// Determina si el host actual incluye prefijo de ruta (ej. VPS con /DrapeMind)
  static String get _effectivePrefix {
    if (_customHost != null && _customHost!.isNotEmpty) {
      if (_customHost!.contains('/')) {
        return '';
      }
      if (_customHost!.contains(':8000') ||
          _customHost!.contains('192.168.') ||
          _customHost!.contains('localhost') ||
          _customHost!.contains('127.0.0.1') ||
          _customHost!.contains('10.0.2.2')) {
        return '';
      }
    }
    return defaultPathPrefix;
  }

  /// Base URL: e.g. http://167.86.106.105/DrapeMind o http://127.0.0.1:8000
  static String get baseUrl {
    final host = defaultHost;
    if (host.startsWith('http://') || host.startsWith('https://')) {
      return host.endsWith('/') ? host.substring(0, host.length - 1) : host;
    }
    final prefix = _effectivePrefix;
    return '$httpScheme://$host$prefix';
  }

  /// API V1 URL: e.g. http://167.86.106.105/DrapeMind/api/v1
  static String get apiV1Url => '$baseUrl/api/v1';

  /// AI WebSocket URL: e.g. ws://167.86.106.105/DrapeMind/api/v1/ws/ai
  static String get aiWsUrl {
    final base = baseUrl
        .replaceFirst('http://', 'ws://')
        .replaceFirst('https://', 'wss://');
    return '$base/api/v1/ws/ai';
  }

  /// Realtime Events WebSocket URL: e.g. ws://167.86.106.105/DrapeMind/api/v1/ws/events
  static String get eventsWsUrl {
    final base = baseUrl
        .replaceFirst('http://', 'ws://')
        .replaceFirst('https://', 'wss://');
    return '$base/api/v1/ws/events';
  }

  /// Helper to convert relative asset URLs (e.g. '/static/products/sample.jpg') to full URLs
  static String resolveMediaUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return '$baseUrl$cleanPath';
  }
}
