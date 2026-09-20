import 'package:flutter/material.dart';

import 'package:drapemind_mobile/navegacion/main_shell.dart';
import 'package:drapemind_mobile/paquetes/catalogo_comercializacion/consultar_detalle_talla_color_variante/presentacion/product_detail_screen.dart';
import 'package:drapemind_mobile/paquetes/notificaciones/presentacion/notifications_screen.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static BuildContext? get context => navigatorKey.currentContext;

  static String? _pendingScreen;
  static Map<String, dynamic>? _pendingData;

  static void setPendingNavigation(String screen, Map<String, dynamic>? data) {
    _pendingScreen = screen;
    _pendingData = data;
  }

  static void processPendingNavigation() {
    if (_pendingScreen != null) {
      final s = _pendingScreen!;
      final d = _pendingData;
      _pendingScreen = null;
      _pendingData = null;
      navigateTo(screen: s, data: d);
    }
  }

  static Future<void> navigateTo({
    required String screen,
    Map<String, dynamic>? data,
  }) async {
    final normalized = screen.toLowerCase().trim();
    if (normalized.isEmpty) return;

    // Si MainShell todavia no esta inicializado (cold start desde notificacion push)
    if (MainShell.switchTab == null) {
      _pendingScreen = screen;
      _pendingData = data;
      return;
    }

    final nav = navigatorKey.currentState;

    // 1. Manejo de pestanas principales de MainShell
    if (normalized.contains('order') || normalized.contains('pedido')) {
      if (nav != null && nav.canPop()) {
        nav.popUntil((route) => route.isFirst);
      }
      MainShell.switchTab?.call(3);
      return;
    }

    if (normalized.contains('ai') || normalized.contains('chat') || normalized.contains('studio')) {
      if (nav != null && nav.canPop()) {
        nav.popUntil((route) => route.isFirst);
      }
      MainShell.switchTab?.call(1);
      return;
    }

    if (normalized.contains('cart') || normalized.contains('carrito')) {
      if (nav != null && nav.canPop()) {
        nav.popUntil((route) => route.isFirst);
      }
      MainShell.switchTab?.call(2);
      return;
    }

    if (normalized.contains('account') || normalized.contains('cuenta') || normalized.contains('perfil')) {
      if (nav != null && nav.canPop()) {
        nav.popUntil((route) => route.isFirst);
      }
      MainShell.switchTab?.call(4);
      return;
    }

    if (normalized.contains('catalog') || normalized.contains('ropa') || normalized.contains('prenda')) {
      if (nav != null && nav.canPop()) {
        nav.popUntil((route) => route.isFirst);
      }
      MainShell.switchTab?.call(0);
      final rawProdId = data?['product_id'] ?? data?['producto_id'];
      if (rawProdId != null && nav != null) {
        final prodId = int.tryParse(rawProdId.toString());
        if (prodId != null) {
          await nav.push(
            MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: prodId)),
          );
        }
      }
      return;
    }

    if (normalized.contains('report')) {
      if (nav != null) {
        await nav.push(
          MaterialPageRoute(builder: (_) => const NotificationsScreen(filterType: 'REPORTE_GENERADO')),
        );
      }
      return;
    }

    if (normalized.contains('notification') || normalized.contains('alerta')) {
      if (nav != null) {
        await nav.push(
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        );
      }
      return;
    }

    // Ruta por defecto si no encaja
    if (nav != null) {
      await nav.push(
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      );
    }
  }
}
