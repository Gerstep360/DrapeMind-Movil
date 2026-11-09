import 'package:flutter/material.dart';
import 'package:drapemind_mobile/segundo_parcial/cu23_pagos/cu23_deferred_service.dart';
import 'package:drapemind_mobile/segundo_parcial/cu13_catalogo_offline/cu13_offline_service.dart';
import 'package:provider/provider.dart';

import 'package:drapemind_mobile/app/auth_gate.dart';
import 'package:drapemind_mobile/core/services/events_socket_service.dart';
import 'package:drapemind_mobile/core/services/company_service.dart';
import 'package:drapemind_mobile/core/services/navigation_service.dart';
import 'package:drapemind_mobile/core/services/push_notification_service.dart';
import 'package:drapemind_mobile/core/theme/app_theme.dart';
import 'package:drapemind_mobile/segundo_parcial/cu05_acceso/cu05_auth_service.dart';
import 'package:drapemind_mobile/paquetes/acceso_gestion_usuarios/datos/servicios/security_service.dart';
import 'package:drapemind_mobile/segundo_parcial/cu22_carrito_checkout/cu22_cart_service.dart';
import 'package:drapemind_mobile/segundo_parcial/cu29_altair/cu29_ai_socket_service.dart';

class DrapeMindApp extends StatelessWidget {
  const DrapeMindApp({super.key});

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => SecurityService()),
      ChangeNotifierProvider(create: (_) => AuthService()..tryAutoLogin()),
      ChangeNotifierProvider(
        create: (context) => OfflineService(auth: context.read<AuthService>()),
      ),
      ChangeNotifierProxyProvider<AuthService, CartService>(
        create: (context) =>
            CartService(offline: context.read<OfflineService>()),
        update: (_, auth, cart) {
          final service = cart ?? CartService();
          service.bindOwner(
            auth.currentUser == null
                ? null
                : '${auth.currentUser!.tenantId}_${auth.currentUser!.id}',
          );
          if (auth.isAuthenticated && !auth.isPlatformAdmin) {
            service.getCart().then<void>((_) {}, onError: (_) {});
          } else {
            service.clearLocal();
          }
          return service;
        },
      ),
      ChangeNotifierProvider(
        lazy: false,
        create: (context) => DeferredService(
          auth: context.read<AuthService>(),
          cart: context.read<CartService>(),
        ),
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
          if (auth.isAuthenticated && !auth.isPlatformAdmin) {
            service.connect();
          } else {
            service.disconnect();
          }
          return service;
        },
      ),
      ChangeNotifierProxyProvider2<
        AuthService,
        EventsSocketService,
        PushNotificationService
      >(
        create: (context) => PushNotificationService(
          authService: context.read<AuthService>(),
          eventsService: context.read<EventsSocketService>(),
        ),
        update: (_, auth, events, current) {
          final service =
              current ??
              PushNotificationService(authService: auth, eventsService: events);
          return service;
        },
      ),
    ],
    child: MaterialApp(
      title: 'DrapeMind Atelier',
      navigatorKey: NavigationService.navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.luxuryTheme,
      onGenerateInitialRoutes: (name) => [
        MaterialPageRoute(
          builder: (_) => CompanyService.slugFromLink(name) == null
              ? const AuthGate()
              : StoreEntryGate(link: name),
        ),
      ],
      onGenerateRoute: (settings) =>
          CompanyService.slugFromLink(settings.name ?? '') == null
          ? null
          : MaterialPageRoute(
              settings: settings,
              builder: (_) => StoreEntryGate(link: settings.name!),
            ),
    ),
  );
}
