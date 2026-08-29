import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/core.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_svg.dart';
import 'ai_studio/ai_studio_screen.dart';
import 'catalog/catalog_screen.dart';
import 'cart/cart_screen.dart';
import 'orders/orders_screen.dart';
import 'profile/account_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>();

    final screens = [
      const CatalogScreen(),
      const AiStudioScreen(),
      CartScreen(onOpenAiStudio: () => setState(() => _currentIndex = 1)),
      const OrdersScreen(),
      const AccountScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.paperLight,
          border: Border(top: BorderSide(color: AppColors.lineStrong)),
        ),
        child: SafeArea(
          child: NavigationBar(
            backgroundColor: Colors.transparent,
            indicatorColor: AppColors.forest,
            selectedIndex: _currentIndex,
            onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
            destinations: [
              NavigationDestination(
                icon: AppSvg.raw(
                  AppSvg.grid,
                  size: 20,
                  color: AppColors.forest,
                ),
                selectedIcon: AppSvg.raw(
                  AppSvg.grid,
                  size: 20,
                  color: AppColors.acid,
                ),
                label: 'Showroom',
              ),
              NavigationDestination(
                icon: AppSvg.raw(
                  AppSvg.sparkle,
                  size: 20,
                  color: AppColors.forest,
                ),
                selectedIcon: AppSvg.raw(
                  AppSvg.sparkle,
                  size: 20,
                  color: AppColors.acid,
                ),
                label: 'Stylist IA',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: cart.itemCount > 0,
                  label: Text('${cart.itemCount}'),
                  backgroundColor: AppColors.forest,
                  child: AppSvg.raw(
                    AppSvg.bag,
                    size: 20,
                    color: AppColors.forest,
                  ),
                ),
                selectedIcon: Badge(
                  isLabelVisible: cart.itemCount > 0,
                  label: Text('${cart.itemCount}'),
                  backgroundColor: AppColors.ink,
                  child: AppSvg.raw(
                    AppSvg.bag,
                    size: 20,
                    color: AppColors.acid,
                  ),
                ),
                label: 'Perchero',
              ),
              NavigationDestination(
                icon: AppSvg.raw(
                  AppSvg.package,
                  size: 20,
                  color: AppColors.forest,
                ),
                selectedIcon: AppSvg.raw(
                  AppSvg.package,
                  size: 20,
                  color: AppColors.acid,
                ),
                label: 'Compras',
              ),
              NavigationDestination(
                icon: AppSvg.raw(
                  AppSvg.user,
                  size: 20,
                  color: AppColors.forest,
                ),
                selectedIcon: AppSvg.raw(
                  AppSvg.user,
                  size: 20,
                  color: AppColors.acid,
                ),
                label: 'Perfil',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
