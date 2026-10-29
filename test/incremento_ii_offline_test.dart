import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:drapemind_mobile/core/config/api_config.dart';
import 'package:drapemind_mobile/core/theme/app_theme.dart';
import 'package:drapemind_mobile/core/network/api_client.dart';
import 'package:drapemind_mobile/core/network/api_exception.dart';
import 'package:drapemind_mobile/paquetes/acceso_gestion_usuarios/datos/servicios/auth_service.dart';
import 'package:drapemind_mobile/paquetes/acceso_gestion_usuarios/dominio/modelos/auth_models.dart';
import 'package:drapemind_mobile/incrementos/incremento_ii/offline/models.dart';
import 'package:drapemind_mobile/incrementos/incremento_ii/offline/offline_service.dart';
import 'package:drapemind_mobile/incrementos/incremento_ii/offline/offline_store.dart';
import 'package:drapemind_mobile/incrementos/incremento_ii/offline/offline_screen.dart';

User customer(int tenant, int id) => User.fromJson({
  'id': id,
  'tenant_id': tenant,
  'tenant_slug': 'store-$tenant',
  'tenant_name': 'Tienda $tenant',
  'nombre': 'Cliente',
  'email': 'client@example.com',
  'rol': 'CLIENTE',
  'estado': 'ACTIVO',
  'created_at': DateTime.now().toIso8601String(),
});

class TestAuth extends ChangeNotifier implements AuthService {
  User? user = customer(1, 4);
  @override
  User? get currentUser => user;
  @override
  bool get isAuthenticated => user != null;
  @override
  bool get hasValidToken => user != null;
  @override
  String? get token =>
      user == null ? null : 'test-token-${user!.tenantId}-${user!.id}';
  @override
  bool get isPlatformAdmin => false;
  void switchStore() {
    user = customer(2, 9);
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

OfflineBundle bundle() => OfflineBundle.fromJson({
  'schema_version': 1,
  'owner': '1:4',
  'tenant_id': 1,
  'user_id': 4,
  'tenant_name': 'Moda Oriente',
  'version': 'v1',
  'downloaded_at': DateTime.now().toUtc().toIso8601String(),
  'valid_until': DateTime.now()
      .toUtc()
      .add(const Duration(hours: 12))
      .toIso8601String(),
  'products': [
    {
      'id': 1,
      'nombre': 'Camisa de algodón',
      'precio': '175.00',
      'imagenes': [],
    },
  ],
  'variants': [
    {'id': 1, 'producto_id': 1, 'talla': 'M', 'color': 'Negro', 'sku': 'CAM-M'},
  ],
  'branches': [
    {'id': 1, 'nombre': 'Centro', 'ciudad': 'La Paz'},
  ],
  'stock': [
    {'sucursal_id': 1, 'variante_id': 1, 'disponible': 10},
  ],
});

class MemoryStore extends OfflineStore {
  void Function(OfflineRequest)? onSaved;
  final bundles = <String, OfflineBundle>{}, rows = <String, OfflineRequest>{};
  @override
  Future<OfflineBundle?> readBundle(String owner) async => bundles[owner];
  @override
  Future<void> saveBundle(String owner, OfflineBundle data) async {
    bundles[owner] = data;
  }

  @override
  Future<List<OfflineRequest>> requests(String owner) async =>
      rows.values.where((r) => r.owner == owner).toList();
  @override
  Future<void> saveRequest(OfflineRequest row) async {
    rows[row.key] = row;
    onSaved?.call(row);
  }

  @override
  Future<Uint8List?> photo(String owner, String url) async => null;
}

class TestApi extends ApiClient {
  bool hideHistory = false;
  bool dropResponse = true;
  int calls = 0, created = 0;
  final receipts = <String, Map<String, dynamic>>{};
  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    bool requiresAuth = true,
    Duration timeout = const Duration(seconds: 15),
  }) async => path == '/offline/bundle'
      ? bundle().data
      : path == '/offline/operations'
      ? (hideHistory ? [] : receipts.values.toList())
      : {'available': true};
  @override
  Future<dynamic> post(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    bool requiresAuth = true,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    if (path == '/offline/operations/results') {
      return receipts.entries
          .where((e) => (body['operaciones'] as List).contains(e.key))
          .map((e) => e.value)
          .toList();
    }
    calls++;
    final payload = body!['payload'] ?? body,
        kind = body['tipo'] ?? 'RESERVATION';
    final id = payload['operacion_id'] as String;
    receipts.putIfAbsent(id, () {
      created++;
      final reservation = {
        'id': 31,
        'codigo_publico': 'a1234567-1111-4222-8333-123456789012',
        'estado': 'PENDIENTE',
        'vence_at': DateTime.now()
            .add(const Duration(hours: 1))
            .toIso8601String(),
      };
      final total = (payload['items'] as List).fold<num>(
        0,
        (n, i) =>
            n +
            (num.tryParse(i['precio_unitario'].toString()) ?? 0) *
                (i['cantidad'] as int),
      );
      return {
        'id': created,
        'usuario_id': 4,
        'operacion_id': id,
        'tipo': kind,
        'payload': payload,
        'estado': 'CONFIRMED',
        'intentos': 1,
        'resultado': kind == 'RESERVATION'
            ? {'reservation': reservation}
            : {
                'sale': {
                  'pedido_id': 31,
                  'codigo_publico': reservation['codigo_publico'],
                  'estado': 'ENTREGADO',
                  'total': total.toStringAsFixed(2),
                  'cambio':
                      ((num.tryParse(payload['efectivo_recibido'].toString()) ??
                                  0) -
                              total)
                          .toStringAsFixed(2),
                },
              },
      };
    });
    if (dropResponse) {
      dropResponse = false;
      throw NetworkException('Respuesta perdida');
    }
    return receipts[id];
  }
}

Future<void> loadOfflineFonts() async {
  final packages =
      jsonDecode(
            await File('.dart_tool/package_config.json').readAsString(),
          )['packages']
          as List;
  final flutter = packages.firstWhere((p) => p['name'] == 'flutter');
  final sdk = Directory.fromUri(Uri.parse(flutter['rootUri'])).parent.parent;
  for (final font in {
    'Roboto': 'roboto-regular.ttf',
    'MaterialIcons': 'materialicons-regular.otf',
  }.entries) {
    final loader = FontLoader(font.key);
    loader.addFont(
      File(
        '${sdk.path}/bin/cache/artifacts/material_fonts/${font.value}',
      ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
    );
    await loader.load();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadOfflineFonts);
  test(
    'SQLite preserves downloaded data and queued operations after reopening, separated by owner',
    () async {
      sqfliteFfiInit();
      final filename =
          '${Directory.systemTemp.path}/drapemind-offline-${DateTime.now().microsecondsSinceEpoch}.db';
      var store = OfflineStore(
        factory: databaseFactoryFfi,
        databasePath: filename,
      );
      try {
        await store.saveBundle('api|1:4', bundle());
        await store.savePhoto(
          'api|1:4',
          'photo.png',
          Uint8List.fromList([1, 2, 3]),
        );
        await store.saveRequest(
          const OfflineRequest(
            key: 'api|1:4|operation',
            owner: 'api|1:4',
            name: 'Camisa',
            branch: 'Centro',
            body: {'operacion_id': 'operation'},
          ),
        );
        await store.close();
        store = OfflineStore(
          factory: databaseFactoryFfi,
          databasePath: filename,
        );
        expect(
          (await store.readBundle('api|1:4'))!.products.single['nombre'],
          'Camisa de algodón',
        );
        expect((await store.requests('api|1:4')).length, 1);
        expect(await store.readBundle('api|2:4'), isNull);
        expect(await store.requests('api|2:4'), isEmpty);
        expect(
          await store.photo('api|1:4', 'photo.png'),
          orderedEquals([1, 2, 3]),
        );
        expect(await store.photo('api|2:4', 'photo.png'), isNull);
      } finally {
        await store.close();
        for (final path in [filename, '$filename-wal', '$filename-shm']) {
          final file = File(path);
          if (await file.exists()) await file.delete();
        }
      }
    },
  );
  test(
    'Lost response is retried with the same operation and does not create a second reservation',
    () async {
      final auth = TestAuth(), api = TestApi(), store = MemoryStore();
      final scope = '${ApiConfig.apiV1Url}|1:4';
      store.bundles[scope] = bundle();
      final service = OfflineService(
        auth: auth,
        api: api,
        store: store,
        monitor: false,
      );
      addTearDown(service.dispose);
      addTearDown(auth.dispose);
      await Future<void>.delayed(Duration.zero);
      await service.ready;
      service.online = false;
      await service.reserve(1, 1, 2);
      expect(store.rows.length, 1);
      expect(service.available(1, 1), 8);
      service.online = true;
      await service.sync();
      expect(service.queue.single.state, 'UNCERTAIN');
      expect(api.created, 1);
      await service.cancel(service.queue.single);
      expect(service.queue.single.state, 'UNCERTAIN');
      await service.checkConnection();
      expect(service.queue.single.state, 'CONFIRMED');
      expect(api.calls, 1);
      expect(api.created, 1);
      auth.switchStore();
      await service.ready;
      expect(service.bundle, isNull);
      expect(service.queue, isEmpty);
      expect(store.rows.length, 1);
    },
  );
  test('Expired download cannot create new offline reservations', () async {
    final auth = TestAuth(), store = MemoryStore();
    final data = bundle();
    data.data['valid_until'] = DateTime.now()
        .subtract(const Duration(hours: 1))
        .toIso8601String();
    store.bundles['${ApiConfig.apiV1Url}|1:4'] = data;
    final service = OfflineService(
      auth: auth,
      api: TestApi(),
      store: store,
      monitor: false,
    );
    addTearDown(service.dispose);
    addTearDown(auth.dispose);
    await Future<void>.delayed(Duration.zero);
    await service.ready;
    expect(service.usable, isFalse);
    await expectLater(service.reserve(1, 1, 1), throwsA(isA<ApiException>()));
    expect(store.rows, isEmpty);
  });
  test(
    'Changing owner during durable save never sends the old request with a new session',
    () async {
      final auth = TestAuth(), store = MemoryStore(), api = TestApi();
      final scope = '${ApiConfig.apiV1Url}|1:4';
      store.bundles[scope] = bundle();
      final service = OfflineService(
        auth: auth,
        api: api,
        store: store,
        monitor: false,
      );
      addTearDown(service.dispose);
      addTearDown(auth.dispose);
      await Future<void>.delayed(Duration.zero);
      await service.ready;
      service.online = false;
      await service.reserve(1, 1, 1);
      store.onSaved = (row) {
        if (row.state == 'SENDING') auth.switchStore();
      };
      service.online = true;
      await service.sync();
      await service.ready;
      expect(api.calls, 0);
      expect(service.queue, isEmpty);
      expect(store.rows.values.single.owner, scope);
    },
  );
  for (final width in [320.0, 390.0]) {
    testWidgets(
      'Offline clothing screen and reserve sheet fit at $width pixels',
      (tester) async {
        tester.view.physicalSize = Size(width, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final auth = TestAuth(), store = MemoryStore();
        store.bundles['${ApiConfig.apiV1Url}|1:4'] = bundle();
        final service = OfflineService(
          auth: auth,
          api: TestApi(),
          store: store,
          monitor: false,
        );
        addTearDown(service.dispose);
        addTearDown(auth.dispose);
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: service,
            child: MaterialApp(
              theme: AppTheme.luxuryTheme,
              home: const OfflineScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        service.online = false;
        await tester.scrollUntilVisible(
          find.text('Elegir'),
          160,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(find.text('Camisa de algodón'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(OfflineScreen),
          matchesGoldenFile('../qa/incremento-ii/offline-${width.toInt()}.png'),
        );
        await tester.tap(find.text('Elegir'));
        await tester.pumpAndSettle();
        expect(find.text('Guardar solicitud'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
