/// Global configuration for DrapeMind Backend API & WebSockets.
class ApiConfig {
  /// IP pública del servidor VPS de producción
  static const String defaultServerIp = '157.173.102.129';
  static const int defaultServerPort = 80;
  static const String defaultPathPrefix = '/DrapeMind';

  static String? _customHost;

  /// Cambia manualmente el host o IP si se desea probar en red local (ej. '192.168.100.223:8000')
  static void setCustomHost(String host) {
    _customHost = host.trim();
  }

  /// Restablece el host al VPS oficial de producción
  static void resetHost() {
    _customHost = null;
  }

  /// Host activo: usa la IP del VPS por defecto o la configurada manualmente
  static String get defaultHost {
    if (_customHost != null && _customHost!.isNotEmpty) {
      return _customHost!;
    }
    // Conexión directa por defecto al VPS de producción
    return defaultServerIp;
  }

  static bool get isSecure => false;

  static String get httpScheme => isSecure ? 'https' : 'http';
  static String get wsScheme => isSecure ? 'wss' : 'ws';

  /// Determina si el host actual incluye prefijo de ruta (ej. VPS con /DrapeMind)
  static String get _effectivePrefix {
    if (_customHost != null && _customHost!.isNotEmpty) {
      // Si el usuario configuró una IP local como '192.168.x.x:8000' o localhost sin subpath
      if (_customHost!.contains('/')) {
        return '';
      }
      if (_customHost!.contains(':8000') || _customHost!.contains('192.168.') || _customHost!.contains('localhost') || _customHost!.contains('10.0.2.2')) {
        return '';
      }
    }
    return defaultPathPrefix;
  }

  /// Base URL: e.g. http://157.173.102.129/DrapeMind o http://192.168.100.223:8000
  static String get baseUrl {
    final host = defaultHost;
    if (host.startsWith('http://') || host.startsWith('https://')) {
      return host.endsWith('/') ? host.substring(0, host.length - 1) : host;
    }
    final prefix = _effectivePrefix;
    return '$httpScheme://$host$prefix';
  }

  /// API V1 URL: e.g. http://157.173.102.129/DrapeMind/api/v1
  static String get apiV1Url => '$baseUrl/api/v1';

  /// AI WebSocket URL: e.g. ws://157.173.102.129/DrapeMind/api/v1/ws/ai
  static String get aiWsUrl {
    final base = baseUrl.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://');
    return '$base/api/v1/ws/ai';
  }

  /// Realtime Events WebSocket URL: e.g. ws://157.173.102.129/DrapeMind/api/v1/ws/events
  static String get eventsWsUrl {
    final base = baseUrl.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://');
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
