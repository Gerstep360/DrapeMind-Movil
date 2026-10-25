import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drapemind_mobile/paquetes/saas/company_access_gate.dart';
import 'package:drapemind_mobile/paquetes/saas/platform_screen.dart';
import 'package:drapemind_mobile/core/services/company_service.dart';

import 'package:drapemind_mobile/core/theme/app_colors.dart';
import 'package:drapemind_mobile/navegacion/main_shell.dart';
import 'package:drapemind_mobile/paquetes/acceso_gestion_usuarios/datos/servicios/auth_service.dart';
import 'package:drapemind_mobile/paquetes/acceso_gestion_usuarios/datos/servicios/security_service.dart';
import 'package:drapemind_mobile/paquetes/acceso_gestion_usuarios/iniciar_sesion/presentacion/login_screen.dart';
import 'package:drapemind_mobile/paquetes/acceso_gestion_usuarios/iniciar_sesion/presentacion/pin_lock_screen.dart';
import 'package:drapemind_mobile/paquetes/acceso_gestion_usuarios/registrar_cliente/presentacion/onboarding_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final security = context.watch<SecurityService>();

    if (auth.isRestoring &&
        (auth.currentUser == null || CompanyService.entrySlug != null)) {
      return const Scaffold(
        backgroundColor: AppColors.paper,
        body: Center(child: CircularProgressIndicator(color: AppColors.ink)),
      );
    }
    if (!auth.isAuthenticated) return const LoginScreen();
    if (security.isLocked) return PinLockScreen(onUnlocked: () {});
    if (auth.isPlatformAdmin) return const PlatformScreen();
    final user = auth.currentUser;
    if (user != null &&
        user.rol.toServerString() == 'CLIENTE' &&
        !user.hasStyleProfile &&
        !auth.onboardingSkipped) {
      return CompanyAccessGate(
        key: ValueKey(user.id),
        child: const OnboardingScreen(),
      );
    }
    return CompanyAccessGate(key: ValueKey(user?.id), child: const MainShell());
  }
}

class StoreEntryGate extends StatefulWidget {
  final String link;
  const StoreEntryGate({super.key, required this.link});
  @override
  State<StoreEntryGate> createState() => _StoreEntryGateState();
}

class _StoreEntryGateState extends State<StoreEntryGate> {
  bool _ready = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _apply();
  }

  Future<void> _apply() async {
    final auth = context.read<AuthService>();
    final slug = CompanyService.slugFromLink(widget.link);
    if (slug != null &&
        auth.isAuthenticated &&
        auth.currentUser?.isUniversalCustomer == true) {
      try {
        await auth.enterStore(slug);
      } catch (_) {
        if (mounted) {
          setState(
            () => _error = 'No pudimos abrir esta tienda. Vuelve a intentarlo.',
          );
        }
      }
      if (mounted) setState(() => _ready = true);
      return;
    }
    if (await CompanyService.acceptStoreLink(widget.link)) {
      if (auth.isAuthenticated &&
          auth.currentUser?.tenantSlug != CompanyService.entrySlug) {
        await auth.logout();
      }
    }
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    final error = _error ?? context.watch<AuthService>().storeEntryError;
    return error != null
        ? Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(error),
                  TextButton(
                    onPressed: () {
                      setState(() => _error = null);
                      _apply();
                    },
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          )
        : _ready
        ? const AuthGate()
        : const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
