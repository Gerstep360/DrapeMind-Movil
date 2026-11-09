import 'package:flutter/material.dart';
import 'negocio_screen.dart';
import 'package:provider/provider.dart';

import 'package:drapemind_mobile/compartido/componentes/navegacion/dm_mobile_navigation.dart';
import 'package:drapemind_mobile/core/core.dart';
import 'package:drapemind_mobile/paquetes/acceso_gestion_usuarios/gestionar_cuenta/presentacion/account_screen.dart';
import 'package:drapemind_mobile/segundo_parcial/cu24_pedidos/cu24_orders_screen.dart';
import 'package:drapemind_mobile/segundo_parcial/cu22_carrito_checkout/carrito/cu22_cart_screen.dart';
import 'package:drapemind_mobile/segundo_parcial/cu13_catalogo_offline/cu13_catalog_screen.dart';
import 'package:drapemind_mobile/segundo_parcial/cu29_altair/cu29_ai_studio_screen.dart';

class MainShell extends StatefulWidget {
  final int initialIndex;

  static void Function(int index)? switchTab;

  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;
  final Set<int> _visited = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _visited.add(_currentIndex);
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
    if (mounted) {
      setState(() {
        _currentIndex = index;
        _visited.add(index);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = context.watch<CartService>().itemCount;
    final user = context.watch<AuthService>().currentUser;
    final business = user != null && user.rol != UserRole.cliente;
    final screens = [
      CatalogScreen(onOpenAiStudio: () => _openTab(1)),
      const AiStudioScreen(),
      CartScreen(
        onOpenAiStudio: () => _openTab(1),
        onOpenCatalog: () => _openTab(0),
      ),
      const OrdersScreen(),
      business ? const BusinessHubScreen() : const AccountScreen(),
    ];

    return Scaffold(
      extendBody: false,
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                for (var i = 0; i < screens.length; i++)
                  _visited.contains(i) ? screens[i] : const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: DmMobileNavigation(
        selectedIndex: _currentIndex,
        cartCount: cartCount,
        onSelected: _openTab,
        business: business,
      ),
    );
  }
}
