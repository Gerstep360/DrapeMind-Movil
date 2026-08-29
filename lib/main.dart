import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/core.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/pin_lock_screen.dart';
import 'screens/main_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DrapeMindApp());
}

class DrapeMindApp extends StatelessWidget {
  const DrapeMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SecurityService>(
          create: (_) => SecurityService(),
        ),
        ChangeNotifierProvider<AuthService>(
          create: (_) => AuthService()..tryAutoLogin(),
        ),
        ChangeNotifierProxyProvider<AuthService, CartService>(
          create: (_) => CartService(),
          update: (_, auth, cart) {
            final service = cart ?? CartService();
            if (auth.isAuthenticated) {
              service.getCart();
            } else {
              service.clearLocal();
            }
            return service;
          },
        ),
        ChangeNotifierProxyProvider<AuthService, AiSocketService>(
          create: (ctx) =>
              AiSocketService(authService: ctx.read<AuthService>()),
          update: (ctx, auth, ai) {
            return ai ?? AiSocketService(authService: auth);
          },
        ),
        ChangeNotifierProxyProvider<AuthService, EventsSocketService>(
          create: (ctx) =>
              EventsSocketService(authService: ctx.read<AuthService>()),
          update: (ctx, auth, events) {
            final service = events ?? EventsSocketService(authService: auth);
            if (auth.isAuthenticated) {
              service.connect();
            } else {
              service.disconnect();
            }
            return service;
          },
        ),
      ],
      child: MaterialApp(
        title: 'DrapeMind Atelier',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.luxuryTheme,
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final security = context.watch<SecurityService>();

    if (auth.isLoading && auth.currentUser == null) {
      return const Scaffold(
        backgroundColor: AppColors.paper,
        body: Center(child: CircularProgressIndicator(color: AppColors.forest)),
      );
    }

    if (auth.isAuthenticated) {
      if (security.isLocked) {
        return PinLockScreen(onUnlocked: () {});
      }
      return const MainShell();
    }

    return const LoginScreen();
  }
}
