import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drapemind_mobile/incrementos/incremento_ii/offline/offline_service.dart';
import 'package:drapemind_mobile/incrementos/incremento_ii/offline/offline_screen.dart';

import 'package:drapemind_mobile/compartido/componentes/navegacion/dm_mobile_navigation.dart';
import 'package:drapemind_mobile/core/core.dart';
import 'package:drapemind_mobile/paquetes/acceso_gestion_usuarios/gestionar_cuenta/presentacion/account_screen.dart';
import 'package:drapemind_mobile/paquetes/carrito_pedidos_pagos/consultar_pedidos_historial_compras/presentacion/orders_screen.dart';
import 'package:drapemind_mobile/paquetes/carrito_pedidos_pagos/gestionar_carrito_perchero/presentacion/cart_screen.dart';
import 'package:drapemind_mobile/paquetes/catalogo_comercializacion/consultar_catalogo_prendas/presentacion/catalog_screen.dart';
import 'package:drapemind_mobile/paquetes/inteligencia_artificial_asistencia_moda/consultar_asistente_altair/presentacion/ai_studio_screen.dart';

class MainShell extends StatefulWidget {
  final int initialIndex;

  static void Function(int index)? switchTab;

  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    MainShell.switchTab = _openTab;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NavigationService.processPendingNavigation();
    });
  }

  @override
  void dispose() {
    if (MainShell.switchTab == _openTab) {
      MainShell.switchTab = null;
    }
    super.dispose();
  }

  void _openTab(int index) {
    if (mounted) setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = context.watch<CartService>().itemCount;
    final offline = context.watch<OfflineService>();
    final screens = [
      CatalogScreen(onOpenAiStudio: () => _openTab(1)),
      const AiStudioScreen(),
      CartScreen(
        onOpenAiStudio: () => _openTab(1),
        onOpenCatalog: () => _openTab(0),
      ),
      const OrdersScreen(),
      const AccountScreen(),
    ];

    return Scaffold(
      extendBody: false,
      body: IndexedStack(index: _currentIndex, children: screens),
      floatingActionButton: !offline.online || offline.pending > 0
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const OfflineScreen())),
              icon: Icon(
                offline.online ? Icons.sync : Icons.cloud_off_outlined,
              ),
              label: Text(
                offline.pending > 0
                    ? '${offline.pending} solicitudes'
                    : 'Colección guardada',
              ),
            )
          : null,
      bottomNavigationBar: DmMobileNavigation(
        selectedIndex: _currentIndex,
        cartCount: cartCount,
        onSelected: _openTab,
      ),
    );
  }
}
