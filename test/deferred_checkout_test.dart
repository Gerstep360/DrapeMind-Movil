import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:drapemind_mobile/incrementos/incremento_ii/offline/offline_store.dart';
import 'package:drapemind_mobile/incrementos/incremento_iii/deferred_store.dart';
import 'package:drapemind_mobile/incrementos/incremento_iii/deferred_service.dart';
import 'package:drapemind_mobile/incrementos/incremento_iii/deferred_screen.dart';
import 'package:drapemind_mobile/paquetes/acceso_gestion_usuarios/datos/servicios/auth_service.dart';

Map<String, dynamic> snapshot() => {
  'owner': '1:4',
  'downloaded_at': DateTime.now().toUtc().toIso8601String(),
  'valid_until': DateTime.now()
      .add(const Duration(days: 2))
      .toUtc()
      .toIso8601String(),
  'cart': {
    'items': [
      {
        'variante_id': 7,
        'nombre': 'Camisa de algodón',
        'cantidad': 2,
        'color': 'Negro',
        'talla': 'M',
        'subtotal': '200.00',
      },
    ],
    'subtotal': '200.00',
  },
  'delivery_fee': '25.00',
  'branches': [
    {'id': 1, 'nombre': 'Centro'},
  ],
  'addresses': [],
  'cards': [
    {'id': 1, 'marca': 'visa', 'ultimos_cuatro': '4242'},
  ],
};

class LocalPreview extends DeferredService {
  LocalPreview() : super(auth: AuthService(), automatic: false) {
    contextData = snapshot();
    online = false;
  }
  @override
  Future<void> refresh() async {}
}

void main() {
  setUpAll(sqfliteFfiInit);
  test(
    'SQLite keeps owner queues and cancellations after reopening without card numbers',
    () async {
      final folder = await Directory.systemTemp.createTemp(
        'drapemind-checkout-test',
      );
      final path = '${folder.path}/drapemind.db';
      final first = OfflineStore(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      final store = DeferredStore(store: first);
      await store.saveContext('api|1:4', snapshot());
      final record = {
        'key': 'api|1:4|operation',
        'owner': 'api|1:4',
        'operation': 'operation',
        'body': {
          'tarjeta_id': 1,
          'total_autorizado': '200.00',
          'items': [
            {'variante_id': 7, 'cantidad': 2},
          ],
        },
        'cancelRequested': true,
      };
      await store.save(record);
      await first.close();
      final second = OfflineStore(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      final restored = DeferredStore(store: second);
      expect(
        (await restored.purchases('api|1:4')).single['cancelRequested'],
        isTrue,
      );
      expect(await restored.purchases('api|2:4'), isEmpty);
      expect(await restored.context('api|2:4'), isNull);
      final persisted = jsonEncode(await restored.purchases('api|1:4'));
      expect(persisted, isNot(contains('card_number')));
      expect(persisted, isNot(contains('cvc')));
      await second.close();
      await folder.delete(recursive: true);
    },
  );
  test(
    'SQLite upgrade preserves pre-existing pending offline operations',
    () async {
      final folder = await Directory.systemTemp.createTemp(
        'drapemind-upgrade-test',
      );
      final path = '${folder.path}/drapemind.db';
      final old = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await db.execute(
              'CREATE TABLE requests(key TEXT PRIMARY KEY,owner TEXT,data TEXT)',
            );
          },
        ),
      );
      await old.insert('requests', {
        'key': 'cash',
        'owner': '1:4',
        'data': '{"estado":"PENDIENTE"}',
      });
      await old.close();
      final store = OfflineStore(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      final db = await store.database;
      expect((await db.query('requests')).single['key'], 'cash');
      expect(await db.query('checkout_pending'), isEmpty);
      await store.close();
      await folder.delete(recursive: true);
    },
  );
  for (final width in [320.0, 390.0]) {
    testWidgets(
      'deferred purchase fits $width and displays an honest offline state',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final service = LocalPreview();
        await tester.pumpWidget(
          ChangeNotifierProvider<DeferredService>.value(
            value: service,
            child: const MaterialApp(home: DeferredPurchasesScreen()),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Sin conexión. Tu compra queda guardada.'),
          findsOneWidget,
        );
        expect(find.text('Prendas de tu carrito'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.text('Guardar compra pendiente'),
          400,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        service.dispose();
      },
    );
  }
}
