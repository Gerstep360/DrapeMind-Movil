import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:drapemind_mobile/core/services/navigation_service.dart';
import 'package:drapemind_mobile/navegacion/main_shell.dart';
import 'package:drapemind_mobile/paquetes/acceso_gestion_usuarios/datos/servicios/auth_service.dart';
import 'package:drapemind_mobile/paquetes/acceso_gestion_usuarios/dominio/modelos/auth_models.dart';

User customer(int tenant, {bool personal = true}) => User(
  id: tenant + 10,
  tenantId: tenant,
  tenantSlug: tenant == 1 ? 'moda' : 'urban',
  nombre: 'Cliente',
  email: 'cliente@example.com',
  rol: personal ? UserRole.cliente : UserRole.cajero,
  isUniversalCustomer: personal,
  estado: 'ACTIVO',
  createdAt: DateTime(2026),
);

class StoreAuth extends AuthService {
  User user;
  final List<String> visits = [];
  StoreAuth(this.user);
  @override
  User get currentUser => user;
  @override
  bool get isAuthenticated => true;
  @override
  Future<void> enterStore(String slug) async {
    visits.add(slug);
    user = customer(2);
    notifyListeners();
  }
}

void main() {
  testWidgets('opens the originating store before navigating to its orders', (
    tester,
  ) async {
    final auth = StoreAuth(customer(1));
    final tabs = <int>[];
    MainShell.switchTab = tabs.add;
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthService>.value(
        value: auth,
        child: MaterialApp(
          navigatorKey: NavigationService.navigatorKey,
          home: const Scaffold(body: Text('Tienda A')),
        ),
      ),
    );
    await NavigationService.navigateTo(
      screen: '/orders',
      data: {'tenant_id': '2', 'tenant_slug': 'urban'},
    );
    expect(auth.visits, ['urban']);
    expect(tabs, isEmpty);
    await tester.pump();
    await tester.pump();
    expect(auth.currentUser.tenantId, 2);
    expect(tabs, [3]);
    MainShell.switchTab = null;
  });

  testWidgets('an employee cannot follow an alert into another company', (
    tester,
  ) async {
    final auth = StoreAuth(customer(1, personal: false));
    final tabs = <int>[];
    MainShell.switchTab = tabs.add;
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthService>.value(
        value: auth,
        child: MaterialApp(
          navigatorKey: NavigationService.navigatorKey,
          home: const Scaffold(body: Text('Caja')),
        ),
      ),
    );
    await NavigationService.navigateTo(
      screen: '/orders',
      data: {'tenant_id': 2, 'tenant_slug': 'urban'},
    );
    await tester.pump();
    expect(auth.visits, isEmpty);
    expect(tabs, isEmpty);
    expect(
      find.textContaining('Este aviso pertenece a otra tienda'),
      findsOneWidget,
    );
    MainShell.switchTab = null;
  });
}
