import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:drapemind_mobile/core/network/api_client.dart';
import 'package:drapemind_mobile/core/theme/app_theme.dart';
import 'package:drapemind_mobile/segundo_parcial/cu05_acceso/cu05_auth_service.dart';
import 'package:drapemind_mobile/segundo_parcial/cu05_acceso/cu05_auth_models.dart';
import 'package:drapemind_mobile/segundo_parcial/cu06_usuarios_roles/cu06_equipo.dart';
import 'package:drapemind_mobile/segundo_parcial/compartido/gestion_resource.dart';
import 'package:drapemind_mobile/segundo_parcial/navegacion/negocio_screen.dart';
import 'package:drapemind_mobile/compartido/componentes/navegacion/dm_mobile_navigation.dart';
import 'incremento_ii_offline_test.dart'
    show TestAuth, customer, loadOfflineFonts;

class ManagementApi extends ApiClient {
  Map<String, dynamic>? saved;
  @override
  Future<dynamic> post(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    bool requiresAuth = true,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    expect(path, '/admin/users');
    saved = Map<String, dynamic>.from(body);
    return {'id': 8};
  }
}

void main() {
  setUpAll(loadOfflineFonts);
  for (final width in [320.0, 390.0]) {
    testWidgets('company management and navigation fit $width pixels', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final auth = TestAuth()
        ..user = User.fromJson({
          ...customer(1, 4).toJson(),
          'rol': 'ADMIN',
          'nombre': 'Administrador',
          'tenant_name': 'Moda Oriente',
        });
      addTearDown(auth.dispose);
      final key = GlobalKey();
      int? selected;
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthService>.value(
          value: auth,
          child: MaterialApp(
            theme: AppTheme.luxuryTheme,
            home: RepaintBoundary(
              key: key,
              child: Scaffold(
                body: const BusinessHubScreen(),
                bottomNavigationBar: DmMobileNavigation(
                  selectedIndex: 4,
                  cartCount: 0,
                  business: true,
                  onSelected: (v) => selected = v,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Mi negocio'), findsOneWidget);
      expect(find.text('Altair'), findsOneWidget);
      expect(find.text('Carrito'), findsOneWidget);
      expect(find.text('Negocio'), findsOneWidget);
      await tester.tap(find.text('Altair'));
      await tester.pumpAndSettle();
      expect(selected, 1);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
      final image =
          await (key.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('qa/segundo-parcial/negocio-${width.toInt()}.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
      });
    });
  }
  testWidgets(
    'employee form submits company-authorized API data without choosing a tenant',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = ManagementApi();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.luxuryTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ResourceForm(spec: equipo, api: api),
                  ),
                ),
                child: const Text('Abrir equipo'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir equipo'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Cajera de prueba');
      await tester.enterText(fields.at(1), 'cashier@example.com');
      await tester.enterText(fields.at(2), 'Only-test-fixture-123!');
      await tester.scrollUntilVisible(
        find.text('Guardar cambios'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(api.saved!['rol'], 'CAJERO');
      expect(api.saved!['email'], 'cashier@example.com');
      expect(api.saved!.containsKey('tenant_id'), isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
