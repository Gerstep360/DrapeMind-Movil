import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:drapemind_mobile/app/auth_gate.dart';
import 'package:drapemind_mobile/core/services/events_socket_service.dart';
import 'package:drapemind_mobile/core/services/navigation_service.dart';
import 'package:drapemind_mobile/core/services/push_notification_service.dart';
import 'package:drapemind_mobile/core/theme/app_theme.dart';
import 'package:drapemind_mobile/paquetes/acceso_gestion_usuarios/datos/servicios/auth_service.dart';
import 'package:drapemind_mobile/paquetes/acceso_gestion_usuarios/datos/servicios/security_service.dart';
import 'package:drapemind_mobile/paquetes/carrito_pedidos_pagos/datos/servicios/cart_service.dart';
import 'package:drapemind_mobile/paquetes/inteligencia_artificial_asistencia_moda/datos/servicios/ai_socket_service.dart';

class DrapeMindApp extends StatelessWidget {
  const DrapeMindApp({super.key});

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => SecurityService()),
      ChangeNotifierProvider(create: (_) => AuthService()..tryAutoLogin()),
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
        create: (context) =>
            AiSocketService(authService: context.read<AuthService>()),
        update: (_, auth, current) =>
            current ?? AiSocketService(authService: auth),
      ),
      ChangeNotifierProxyProvider<AuthService, EventsSocketService>(
        create: (context) =>
            EventsSocketService(authService: context.read<AuthService>()),
        update: (_, auth, current) {
          final service = current ?? EventsSocketService(authService: auth);
          if (auth.isAuthenticated) {
            service.connect();
          } else {
            service.disconnect();
          }
          return service;
        },
      ),
      ChangeNotifierProxyProvider2<AuthService, EventsSocketService, PushNotificationService>(
        create: (context) => PushNotificationService(
          authService: context.read<AuthService>(),
          eventsService: context.read<EventsSocketService>(),
        ),
        update: (_, auth, events, current) {
          final service = current ??
              PushNotificationService(authService: auth, eventsService: events);
          if (auth.isAuthenticated) {
            service.registerDeviceWithBackend();
            service.fetchNotifications();
          }
          return service;
        },
      ),
    ],
    child: MaterialApp(
      title: 'DrapeMind Atelier',
      navigatorKey: NavigationService.navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.luxuryTheme,
      home: const AuthGate(),
    ),
  );
}

