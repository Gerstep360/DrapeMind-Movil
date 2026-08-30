/// Global configuration for DrapeMind Backend API & WebSockets.
class ApiConfig {
  /// Tu IP local explícita de red (obtenida de ipconfig) para conectar desde
  /// emuladores, dispositivos físicos Android/iOS y navegadores.
  static const String serverIp = '10.0.2.2';
  static const int serverPort = 8000;

  static String? _customHost;

  /// Cambia manualmente el host o IP si cambia de red Wi-Fi (ej. '192.168.1.50:8000')
  static void setCustomHost(String host) {
    _customHost = host;
  }

  /// Restablece el host a la IP por defecto
  static void resetHost() {
    _customHost = null;
  }

  /// Host activo: usa la IP explícita por defecto o la configurada
  static String get defaultHost {
    if (_customHost != null && _customHost!.isNotEmpty) {
      return _customHost!;
    }
    // Usamos la IP explícita del servidor en la red local
    return '$serverIp:$serverPort';
  }

  static bool get isSecure => false;

  static String get httpScheme => isSecure ? 'https' : 'http';
  static String get wsScheme => isSecure ? 'wss' : 'ws';

  /// Base URL: e.g. http://192.168.100.223:8000
  static String get baseUrl => '$httpScheme://$defaultHost';

  /// API V1 URL: e.g. http://192.168.100.223:8000/api/v1
  static String get apiV1Url => '$baseUrl/api/v1';

  /// AI WebSocket URL: e.g. ws://192.168.100.223:8000/api/v1/ws/ai
  static String get aiWsUrl => '$wsScheme://$defaultHost/api/v1/ws/ai';

  /// Realtime Events WebSocket URL: e.g. ws://192.168.100.223:8000/api/v1/ws/events
  static String get eventsWsUrl => '$wsScheme://$defaultHost/api/v1/ws/events';

  /// Helper to convert relative asset URLs (e.g. '/static/products/sample.jpg') to full URLs
  static String resolveMediaUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return '$baseUrl$cleanPath';
  }
}
