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
          border: Border(top: BorderSide(color: AppColors.line, width: 1)),
          boxShadow: [
            BoxShadow(
              color: Color(0x0F10110F),
              blurRadius: 20,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: NavigationBar(
            backgroundColor: AppColors.paperLight,
            indicatorColor: AppColors.lime,
            selectedIndex: _currentIndex,
            onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
            destinations: [
              NavigationDestination(
                icon: AppSvg.raw(
                  AppSvg.grid,
                  size: 20,
                  color: AppColors.textMuted,
                ),
                selectedIcon: AppSvg.raw(
                  AppSvg.grid,
                  size: 20,
                  color: AppColors.ink,
                ),
                label: 'Showroom',
              ),
              NavigationDestination(
                icon: AppSvg.raw(
                  AppSvg.sparkle,
                  size: 20,
                  color: AppColors.textMuted,
                ),
                selectedIcon: AppSvg.raw(
                  AppSvg.sparkle,
                  size: 20,
                  color: AppColors.ink,
                ),
                label: 'Stylist IA',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: cart.itemCount > 0,
                  label: Text(
                    '${cart.itemCount}',
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                    ),
                  ),
                  backgroundColor: AppColors.lime,
                  child: AppSvg.raw(
                    AppSvg.bag,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                ),
                selectedIcon: Badge(
                  isLabelVisible: cart.itemCount > 0,
                  label: Text(
                    '${cart.itemCount}',
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                    ),
                  ),
                  backgroundColor: AppColors.lime,
                  child: AppSvg.raw(
                    AppSvg.bag,
                    size: 20,
                    color: AppColors.ink,
                  ),
                ),
                label: 'Perchero',
              ),
              NavigationDestination(
                icon: AppSvg.raw(
                  AppSvg.package,
                  size: 20,
                  color: AppColors.textMuted,
                ),
                selectedIcon: AppSvg.raw(
                  AppSvg.package,
                  size: 20,
                  color: AppColors.ink,
                ),
                label: 'Compras',
              ),
              NavigationDestination(
                icon: AppSvg.raw(
                  AppSvg.user,
                  size: 20,
                  color: AppColors.textMuted,
                ),
                selectedIcon: AppSvg.raw(
                  AppSvg.user,
                  size: 20,
                  color: AppColors.ink,
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
