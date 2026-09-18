import 'package:flutter/material.dart';

import 'package:drapemind_mobile/navegacion/main_shell.dart';
import 'package:drapemind_mobile/paquetes/catalogo_comercializacion/consultar_detalle_talla_color_variante/presentacion/product_detail_screen.dart';
import 'package:drapemind_mobile/paquetes/notificaciones/presentacion/notifications_screen.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static BuildContext? get context => navigatorKey.currentContext;

  static Future<void> navigateTo({
    required String screen,
    Map<String, dynamic>? data,
  }) async {
    final ctx = context;
    final normalized = screen.toLowerCase().trim();

    // 1. Manejo de pestanas de MainShell
    if (normalized.contains('order') || normalized.contains('pedido')) {
      MainShell.switchTab?.call(3);
      return;
    }

    if (normalized.contains('ai') || normalized.contains('chat') || normalized.contains('studio')) {
      MainShell.switchTab?.call(1);
      return;
    }

    if (normalized.contains('cart') || normalized.contains('carrito')) {
      MainShell.switchTab?.call(2);
      return;
    }

    if (normalized.contains('catalog') || normalized.contains('ropa') || normalized.contains('prenda')) {
      MainShell.switchTab?.call(0);
      final rawProdId = data?['product_id'] ?? data?['producto_id'];
      if (rawProdId != null && ctx != null) {
        final prodId = int.tryParse(rawProdId.toString());
        if (prodId != null) {
          await Navigator.of(ctx).push(
            MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: prodId)),
          );
        }
      }
      return;
    }

    if (normalized.contains('notification') || normalized.contains('alerta')) {
      if (ctx != null) {
        await Navigator.of(ctx).push(
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        );
      }
      return;
    }

    if (normalized.contains('report')) {
      if (ctx != null) {
        await Navigator.of(ctx).push(
          MaterialPageRoute(builder: (_) => const NotificationsScreen(filterType: 'REPORTE_GENERADO')),
        );
      }
      return;
    }

    // Ruta por defecto si no encaja: abrir centro de notificaciones
    if (ctx != null) {
      await Navigator.of(ctx).push(
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      );
    }
  }
}
