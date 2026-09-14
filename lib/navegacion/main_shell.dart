import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:drapemind_mobile/compartido/componentes/navegacion/dm_mobile_navigation.dart';
import 'package:drapemind_mobile/core/core.dart';
import 'package:drapemind_mobile/paquetes/acceso_gestion_usuarios/gestionar_cuenta/presentacion/account_screen.dart';
import 'package:drapemind_mobile/paquetes/carrito_pedidos_pagos/consultar_pedidos_historial_compras/presentacion/orders_screen.dart';
import 'package:drapemind_mobile/paquetes/carrito_pedidos_pagos/gestionar_carrito_perchero/presentacion/cart_screen.dart';
import 'package:drapemind_mobile/paquetes/catalogo_comercializacion/consultar_catalogo_prendas/presentacion/catalog_screen.dart';
import 'package:drapemind_mobile/paquetes/inteligencia_artificial_asistencia_moda/consultar_asistente_altair/presentacion/ai_studio_screen.dart';

class MainShell extends StatefulWidget {
  final int initialIndex;

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
  }

  void _openTab(int index) => setState(() => _currentIndex = index);

  @override
  Widget build(BuildContext context) {
    final cartCount = context.watch<CartService>().itemCount;
    final screens = [
      CatalogScreen(onOpenAiStudio: () => _openTab(1)),
      const AiStudioScreen(),
      CartScreen(onOpenAiStudio: () => _openTab(1)),
      const OrdersScreen(),
      const AccountScreen(),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: DmMobileNavigation(
        selectedIndex: _currentIndex,
        cartCount: cartCount,
        onSelected: _openTab,
      ),
    );
  }
}
