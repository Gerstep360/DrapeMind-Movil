import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/core.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_svg.dart';
import 'ai_studio/ai_studio_screen.dart';
import 'catalog/catalog_screen.dart';
import 'cart/cart_screen.dart';
import 'orders/orders_screen.dart';

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
    final auth = context.watch<AuthService>();

    final screens = [
      const CatalogScreen(),
      const AiStudioScreen(),
      CartScreen(onOpenAiStudio: () => setState(() => _currentIndex = 1)),
      const OrdersScreen(),
      _buildProfileScreen(auth),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
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
                icon: AppSvg.raw(AppSvg.grid, size: 20, color: AppColors.forest),
                selectedIcon: AppSvg.raw(AppSvg.grid, size: 20, color: AppColors.acid),
                label: 'Showroom',
              ),
              NavigationDestination(
                icon: AppSvg.raw(AppSvg.sparkle, size: 20, color: AppColors.forest),
                selectedIcon: AppSvg.raw(AppSvg.sparkle, size: 20, color: AppColors.acid),
                label: 'Stylist IA',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: cart.itemCount > 0,
                  label: Text('${cart.itemCount}'),
                  backgroundColor: AppColors.forest,
                  child: AppSvg.raw(AppSvg.bag, size: 20, color: AppColors.forest),
                ),
                selectedIcon: Badge(
                  isLabelVisible: cart.itemCount > 0,
                  label: Text('${cart.itemCount}'),
                  backgroundColor: AppColors.ink,
                  child: AppSvg.raw(AppSvg.bag, size: 20, color: AppColors.acid),
                ),
                label: 'Perchero',
              ),
              NavigationDestination(
                icon: AppSvg.raw(AppSvg.package, size: 20, color: AppColors.forest),
                selectedIcon: AppSvg.raw(AppSvg.package, size: 20, color: AppColors.acid),
                label: 'Compras',
              ),
              NavigationDestination(
                icon: AppSvg.raw(AppSvg.user, size: 20, color: AppColors.forest),
                selectedIcon: AppSvg.raw(AppSvg.user, size: 20, color: AppColors.acid),
                label: 'Perfil',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileScreen(AuthService auth) {
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Row(
          children: [
            AppSvg.raw(AppSvg.user, size: 18, color: AppColors.white),
            const SizedBox(width: 8),
            const Text('MI CUENTA EN EL ATELIER'),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: AppColors.forest,
                        shape: BoxShape.circle,
                      ),
                      child: AppSvg.raw(AppSvg.user, size: 36, color: AppColors.acid),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user?.nombre ?? 'Cliente Atelier',
                      style: const TextStyle(
                        fontFamily: 'serif',
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.forestDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user?.email ?? '',
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.paperLight,
                        border: Border.all(color: AppColors.lineStrong),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        'ROL: ${user?.rol.toServerString() ?? "CLIENTE"}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          color: AppColors.forest,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // IP & HOST CONFIGURATION CARD
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AppSvg.raw(AppSvg.lock, size: 16, color: AppColors.forest),
                        const SizedBox(width: 8),
                        const Text(
                          'CONFIGURACIÓN DE SERVIDOR API',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Host API Backend: ${ApiConfig.baseUrl}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMutedStrong),
                    ),
                    Text(
                      'WebSocket IA: ${ApiConfig.aiWsUrl}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMutedStrong),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => auth.logout(),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppSvg.raw(AppSvg.close, size: 16, color: AppColors.white),
                  const SizedBox(width: 8),
                  const Text('Cerrar Sesión'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
