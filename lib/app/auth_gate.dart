import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

    if (auth.isLoading && auth.currentUser == null) {
      return const Scaffold(
        backgroundColor: AppColors.paper,
        body: Center(child: CircularProgressIndicator(color: AppColors.ink)),
      );
    }
    if (!auth.isAuthenticated) return const LoginScreen();
    if (security.isLocked) return PinLockScreen(onUnlocked: () {});
    final user = auth.currentUser;
    if (user != null && !user.hasStyleProfile && !auth.onboardingSkipped) {
      return const OnboardingScreen();
    }
    return const MainShell();
  }
}
