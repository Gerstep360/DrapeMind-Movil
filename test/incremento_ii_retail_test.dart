import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:drapemind_mobile/core/config/api_config.dart';
import 'package:drapemind_mobile/core/theme/app_theme.dart';
import 'package:drapemind_mobile/core/network/api_exception.dart';
import 'package:drapemind_mobile/paquetes/acceso_gestion_usuarios/dominio/modelos/auth_models.dart';
import 'package:drapemind_mobile/incrementos/incremento_ii/offline/offline_service.dart';
import 'package:drapemind_mobile/incrementos/incremento_ii/caja/retail_screen.dart';
import 'incremento_ii_offline_test.dart'
    show TestAuth, TestApi, MemoryStore, bundle, loadOfflineFonts;

TestAuth cashier() {
  final auth = TestAuth();
  auth.user = User.fromJson({...auth.user!.toJson(), 'rol': 'CAJERO'});
  return auth;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadOfflineFonts);
  test(
    'Offline cash collection remains durable, cannot be cancelled locally, and reconciles a lost response once',
    () async {
      final auth = cashier(), store = MemoryStore(), api = TestApi();
      final scope = '${ApiConfig.apiV1Url}|1:4';
      store.bundles[scope] = bundle();
      final service = OfflineService(
        auth: auth,
        store: store,
        api: api,
        monitor: false,
      );
      addTearDown(service.dispose);
      addTearDown(auth.dispose);
      await Future<void>.delayed(Duration.zero);
      await service.ready;
      service.online = false;
      await service.cashSale(
        [
          {'variante_id': 1, 'cantidad': 2},
        ],
        1,
        '400',
      );
      expect(store.rows.values.single.kind, 'SALE');
      expect(
        store.rows.values.single.body['items'][0]['precio_unitario'],
        '175.00',
      );
      expect(service.available(1, 1), 8);
      await service.cancel(service.queue.single);
      expect(service.queue.single.state, 'PENDING');
      service.online = true;
      await service.sync();
      expect(service.queue.single.state, 'UNCERTAIN');
      await service.checkConnection();
      expect(service.queue.single.state, 'CONFIRMED');
      expect(service.queue.single.sale?['total'], '350.00');
      expect(api.calls, 1);
      expect(api.created, 1);
      expect(service.available(1, 1), 8);
    },
  );
  test(
    'Customers cannot register cash sales and insufficient cash never creates a pending operation',
    () async {
      final auth = TestAuth(), store = MemoryStore();
      store.bundles['${ApiConfig.apiV1Url}|1:4'] = bundle();
      final service = OfflineService(
        auth: auth,
        store: store,
        api: TestApi(),
        monitor: false,
      );
      addTearDown(service.dispose);
      addTearDown(auth.dispose);
      await Future<void>.delayed(Duration.zero);
      await service.ready;
      service.online = false;
      await expectLater(
        service.cashSale(
          [
            {'variante_id': 1, 'cantidad': 1},
          ],
          1,
          '200',
        ),
        throwsA(isA<ApiException>()),
      );
      auth.user = User.fromJson({...auth.user!.toJson(), 'rol': 'CAJERO'});
      await expectLater(
        service.cashSale(
          [
            {'variante_id': 1, 'cantidad': 1},
          ],
          1,
          '100',
        ),
        throwsA(isA<ApiException>()),
      );
      expect(store.rows, isEmpty);
    },
  );
  test(
    'Older conflict results reconcile by UUID even when absent from the recent history',
    () async {
      final auth = cashier(),
          store = MemoryStore(),
          api = TestApi()..dropResponse = false;
      store.bundles['${ApiConfig.apiV1Url}|1:4'] = bundle();
      final service = OfflineService(
        auth: auth,
        store: store,
        api: api,
        monitor: false,
      );
      addTearDown(service.dispose);
      addTearDown(auth.dispose);
      await Future<void>.delayed(Duration.zero);
      await service.ready;
      service.online = false;
      await service.cashSale(
        [
          {'variante_id': 1, 'cantidad': 1},
        ],
        1,
        '200',
      );
      service.online = true;
      await service.sync();
      expect(api.created, 1);
      final conflicted = service.queue.single.change(state: 'CONFLICT');
      service.queue = [conflicted];
      await store.saveRequest(conflicted);
      api.hideHistory = true;
      await service.checkConnection();
      expect(service.queue.single.state, 'CONFIRMED');
      expect(api.calls, 1);
    },
  );
  test(
    'Offline pickup keeps reserved availability and prevents collecting the same reservation twice',
    () async {
      final auth = cashier(),
          store = MemoryStore(),
          api = TestApi()..dropResponse = false;
      final data = bundle();
      data.data['stock'][0]['disponible'] = 9;
      final reservation = <String, dynamic>{
        'id': 41,
        'sucursal_id': 1,
        'estado': 'LISTA',
        'vence_at': DateTime.now()
            .add(const Duration(hours: 1))
            .toIso8601String(),
        'items': [
          {'variante_id': 1, 'cantidad': 1, 'precio_unitario': '175.00'},
        ],
      };
      data.data['reservations'] = [reservation];
      store.bundles['${ApiConfig.apiV1Url}|1:4'] = data;
      final service = OfflineService(
        auth: auth,
        store: store,
        api: api,
        monitor: false,
      );
      addTearDown(service.dispose);
      addTearDown(auth.dispose);
      await Future<void>.delayed(Duration.zero);
      await service.ready;
      service.online = false;
      await service.pickup(reservation, '200');
      expect(service.queue.single.kind, 'PICKUP');
      expect(service.available(1, 1), 9);
      await expectLater(
        service.pickup(reservation, '200'),
        throwsA(isA<ApiException>()),
      );
      service.online = true;
      await service.sync();
      expect(service.queue.single.sale?['total'], '175.00');
      expect(api.created, 1);
    },
  );
  for (final width in [320.0, 390.0]) {
    testWidgets(
      'Cash desk fits $width pixels and saves a provisional receipt offline',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final auth = cashier(), store = MemoryStore();
        store.bundles['${ApiConfig.apiV1Url}|1:4'] = bundle();
        final service = OfflineService(
          auth: auth,
          store: store,
          api: TestApi(),
          monitor: false,
        );
        addTearDown(service.dispose);
        addTearDown(auth.dispose);
        await tester.pump();
        await service.ready;
        service.online = false;
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: service,
            child: MaterialApp(
              theme: AppTheme.luxuryTheme,
              home: const RetailScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(RetailScreen),
          matchesGoldenFile('../qa/incremento-ii/retail-${width.toInt()}.png'),
        );
        expect(tester.takeException(), isNull);
        final dropdown = find.byType(DropdownButtonFormField<int>).last;
        await tester.ensureVisible(dropdown);
        await tester.tap(dropdown);
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('Camisa de algodón').last);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(OutlinedButton, 'Añadir'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.widgetWithText(TextField, 'Efectivo recibido'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Efectivo recibido'),
          '200',
        );
        final save = find.widgetWithText(
          FilledButton,
          'Guardar venta de contado',
        );
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Ver comprobante provisional'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Ver comprobante provisional'));
        await tester.pumpAndSettle();
        expect(find.text('Comprobante provisional'), findsOneWidget);
        expect(store.rows.values.single.kind, 'SALE');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
