import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:drapemind_mobile/core/network/api_client.dart';
import 'package:drapemind_mobile/core/network/api_exception.dart';
import 'package:drapemind_mobile/core/theme/app_theme.dart';
import 'package:drapemind_mobile/segundo_parcial/cu12_descarga_offline/cu12_download_sheet.dart';
import 'package:drapemind_mobile/segundo_parcial/cu13_catalogo_offline/cu13_offline_service.dart';
import 'package:drapemind_mobile/segundo_parcial/cu13_catalogo_offline/cu13_offline_store.dart';
import 'package:drapemind_mobile/segundo_parcial/cu20_cambios/cu20_exchange_service.dart';
import 'package:drapemind_mobile/segundo_parcial/cu20_cambios/cu20_exchange_sheet.dart';
import 'package:drapemind_mobile/segundo_parcial/cu22_carrito_checkout/cu22_cart_service.dart';
import 'package:drapemind_mobile/segundo_parcial/cu23_pagos/cu23_deferred_service.dart';
import 'package:drapemind_mobile/segundo_parcial/cu23_pagos/cu23_deferred_store.dart';
import 'package:drapemind_mobile/segundo_parcial/cu24_pedidos/cu24_order_service.dart';
import 'package:drapemind_mobile/segundo_parcial/cu24_pedidos/cu24_order_models.dart';
import 'package:drapemind_mobile/segundo_parcial/cu24_pedidos/cu24_orders_screen.dart';
import 'incremento_ii_offline_test.dart' as fixture;

Map<String, dynamic> order(int id) => {
  'id': id,
  'sucursal_id': 1,
  'codigo_publico': 'order-$id',
  'estado': 'PAGADO',
  'subtotal': 175,
  'total': 175,
  'created_at': DateTime.now().toUtc().toIso8601String(),
  'items': [
    {
      'id': id,
      'nombre': 'Camisa de algodón',
      'variante_id': 1,
      'cantidad': 1,
      'precio_unitario': 175,
      'subtotal': 175,
    },
  ],
};

class StoreApi extends ApiClient {
  bool offline = false, failBundle = false, failContext = false;
  int count = 2, posts = 0;
  final requests = <String>[];
  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    bool requiresAuth = true,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    requests.add(path);
    if (offline ||
        (path == '/offline/bundle' && failBundle) ||
        (path == '/payments/deferred/context' && failContext)) {
      throw NetworkException('Sin conexión');
    }
    if (path == '/offline/bundle') return fixture.bundle().data;
    if (path == '/cart') {
      return {'id': 1, 'items': [], 'subtotal': 0, 'total_items': 0};
    }
    if (path == '/payments/deferred') return [];
    if (path == '/payments/deferred/context') {
      return {
        'owner': '1:4',
        'branches': [
          {'id': 1, 'nombre': 'Centro'},
        ],
        'cards': [],
        'cart': {'id': 1, 'items': []},
      };
    }
    if (path == '/orders') {
      final cursor = queryParams?['before_id'] as int? ?? count + 1;
      return List.generate(count, (i) => count - i)
          .where((id) => id < cursor)
          .take(queryParams?['limit'] ?? 50)
          .map(order)
          .toList();
    }
    if (path.endsWith('/receipt')) {
      final id = int.parse(path.split('/')[2]);
      return {
        'order': order(id),
        'empresa': {'nombre': 'Moda Oriente'},
        'items': order(id)['items'],
      };
    }
    if (path.startsWith('/orders/')) {
      return order(int.parse(path.split('/')[2]));
    }
    throw ApiException('Ruta inesperada $path');
  }

  @override
  Future<Uint8List> getBytes(
    String path, {
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    bool requiresAuth = true,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (offline) throw NetworkException('Sin conexión');
    return Uint8List.fromList(utf8.encode('%PDF-fixture'));
  }

  @override
  Future<dynamic> post(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    bool requiresAuth = true,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    posts++;
    throw StateError('La descarga nunca debe crear una compra');
  }
}

class ExchangeApi extends OrderService {
  int posts = 0, gets = 0, searches = 0;
  bool drop = false, blockRecovery = false, needsPayment = false;
  Map<String, dynamic>? sent, accepted;
  @override
  Future<Map<String, dynamic>> findOrderForExchange(String code) async => {
    'sucursal_id': 1,
    'items': [
      {
        'id': 10,
        'nombre': 'Camisa de algodón',
        'talla': 'M',
        'color': 'Negro',
        'cantidad': 2,
        'disponible_cambio': 2,
        'credito_unitario': '175',
      },
    ],
  };
  @override
  Future<List<Map<String, dynamic>>> exchangeProducts(String query) async {
    searches++;
    return [
      {'id': 1, 'nombre': 'Camisa de algodón', 'precio': '210', 'imagenes': []},
    ];
  }

  @override
  Future<Map<String, dynamic>> exchangeProduct(int id) async => {
    'id': 1,
    'nombre': 'Camisa de algodón',
    'variantes': [
      {'id': 2, 'talla': 'L', 'color': 'Negro'},
    ],
  };
  @override
  Future<List<Map<String, dynamic>>> exchangeAvailability(int id) async => [
    {'sucursal_id': 1, 'variante_id': 2, 'stock_disponible': 2},
  ];
  @override
  Future<Map<String, dynamic>> quoteExchange(
    Map<String, dynamic> payload,
  ) async => {
    'credito': '175',
    'total_nuevo': payload['prendas_nuevas'].isEmpty ? '0' : '210',
    'diferencia': payload['prendas_nuevas'].isEmpty ? '-175' : '35',
    'stripe_refund_eligible': true,
  };
  @override
  Future<Map<String, dynamic>> confirmExchange(
    Map<String, dynamic> payload,
  ) async {
    posts++;
    sent = jsonDecode(jsonEncode(payload));
    accepted = {
      'id': 22,
      'pedido_nuevo_id': 44,
      'stripe_payment_needed': needsPayment,
      'credito': '175',
      'total_nuevo': needsPayment ? '210' : '0',
      'diferencia': needsPayment ? '35' : '-175',
      if (!needsPayment)
        'stripe_refund': {'monto': '175', 'estado': 'REEMBOLSO_PENDIENTE'},
    };
    if (drop) throw NetworkException('Respuesta perdida');
    return accepted!;
  }

  @override
  Future<Map<String, dynamic>> exchangeResult(String operation) async {
    gets++;
    if (blockRecovery) throw AuthException('Sesión vencida');
    if (accepted == null) throw NotFoundException('Sin resultado');
    return accepted!;
  }
}

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('qa/mobile-download/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

class DownloadAuth extends fixture.TestAuth {
  void refreshSession() => notifyListeners();
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    await fixture.loadOfflineFonts();
  });
  Future<(OfflineStore, OfflineService, DownloadAuth, Directory)> setup(
    StoreApi api,
  ) async {
    final dir = await Directory.systemTemp.createTemp('drapemind-mobile-');
    final store = OfflineStore(
      factory: databaseFactoryFfi,
      databasePath: '${dir.path}/drapemind.db',
    );
    final auth = DownloadAuth();
    final local = OfflineService(
      auth: auth,
      api: api,
      store: store,
      monitor: false,
    );
    await Future<void>.delayed(Duration.zero);
    await local.ready;
    local.bundle = fixture.bundle();
    addTearDown(() async {
      local.dispose();
      auth.dispose();
      await store.close();
      await dir.delete(recursive: true);
    });
    return (store, local, auth, dir);
  }

  test(
    'download persists all order pages and receipts across SQLite reopening; isolates tenants',
    () async {
      final api = StoreApi()..count = 201;
      final (store, local, auth, dir) = await setup(api);
      final service = OrderService(apiClient: api, offline: local);
      await store.saveBundle(local.owner!, local.bundle!);
      expect(await service.prepareDownload(), 201);
      expect(api.requests.where((r) => r == '/orders').length, 2);
      await store.close();
      final reopened = OfflineStore(
        factory: databaseFactoryFfi,
        databasePath: '${dir.path}/drapemind.db',
      );
      final again = OfflineService(
        auth: auth,
        api: api,
        store: reopened,
        monitor: false,
      );
      addTearDown(() async {
        again.dispose();
        await reopened.close();
      });
      await Future<void>.delayed(Duration.zero);
      await again.ready;
      api.offline = true;
      again.useDownloadedData();
      final offlineOrders = OrderService(apiClient: api, offline: again);
      expect((await offlineOrders.getMyOrders()).length, 201);
      expect(
        (await offlineOrders.getOrderDetail(1)).items.single.nombre,
        'Camisa de algodón',
      );
      expect(
        (await offlineOrders.getOrderReceipt(1))['empresa']['nombre'],
        'Moda Oriente',
      );
      // Refreshing one page online cannot erase the older downloaded history.
      api.offline = false;
      again.online = true;
      await offlineOrders.getMyOrders();
      again.useDownloadedData();
      expect((await offlineOrders.getMyOrders()).length, 201);
      auth.switchStore();
      await again.ready;
      expect(await offlineOrders.getMyOrders(), isEmpty);
      expect(api.posts, 0);
    },
  );
  test(
    'explicit download rejects stale successful data after a network failure',
    () async {
      final api = StoreApi()..failBundle = true;
      final (_, local, auth, _) = await setup(api);
      expect(local.usable, isTrue);
      await expectLater(
        local.download(strict: true),
        throwsA(isA<NetworkException>()),
      );
      expect(local.message, 'Sin conexión');
      final deferred = DeferredService(
        auth: auth,
        client: api,
        local: DeferredStore(store: local.store),
        automatic: false,
      );
      addTearDown(deferred.dispose);
      await deferred.restore(local.owner!);
      // Explicit checkout preparation must not accept an old context on failure.
      api.failContext = true;
      await expectLater(deferred.prepareDownload(), throwsA(anything));
      expect(api.posts, 0);
    },
  );
  test(
    'download caches every product and variant photo and reports invalid responses',
    () async {
      final auth = fixture.TestAuth(), store = fixture.MemoryStore();
      final data = fixture.bundle().data;
      data['products'][0]['imagenes'] = [
        'https://example.test/a.png',
        'https://example.test/b.png',
      ];
      data['variants'][0]['imagenes'] = [
        'https://example.test/c.png',
        'https://example.test/b.png',
        'https://example.test/html.png',
      ];
      final api = _BundleApi(data);
      final photos = _Photos();
      final client = MockClient(
        (request) async => http.Response(
          request.url.path.contains('html')
              ? '<!doctype html><html>error</html>'
              : 'PNG bytes',
          200,
          headers: {'content-type': 'image/png'},
        ),
      );
      final local = OfflineService(
        auth: auth,
        api: api,
        store: photos,
        photoClient: client,
        monitor: false,
      );
      await Future<void>.delayed(Duration.zero);
      await local.ready;
      await local.download(strict: true);
      expect(local.photosTotal, 4);
      expect(local.photosSaved, 3);
      expect(local.photosFailed, 1);
      expect(photos.saved.length, 3);
      local.dispose();
      auth.dispose();
      client.close();
      store.close();
    },
  );
  test(
    'an uncertain exchange survives restart and only 404 allows reposting',
    () async {
      final (store, local, _, _) = await setup(StoreApi());
      final api = ExchangeApi()..drop = true;
      ExchangeOperation make() => ExchangeOperation(
        api: api,
        store: DeferredStore(store: store),
        owner: local.owner!,
        orderId: 1,
        authorized: () => true,
      );
      final first = make();
      await first.restore();
      await expectLater(
        first.confirm({'pedido_origen_id': 1}),
        throwsA(isA<NetworkException>()),
      );
      final uuid = api.sent!['operacion_id'];
      final restarted = make();
      await restarted.restore();
      api.blockRecovery = true;
      await expectLater(restarted.confirm({}), throwsA(isA<AuthException>()));
      expect(api.posts, 1);
      api.blockRecovery = false;
      expect((await restarted.confirm({}))['id'], 22);
      expect(api.posts, 1);
      expect(restarted.payload!['operacion_id'], uuid);
      api.accepted = null;
      api.drop = false;
      await restarted.confirm({});
      expect(api.posts, 2);
      expect(api.sent!['operacion_id'], uuid);
    },
  );
  test(
    'a failed disk write can never be bypassed by retrying an exchange',
    () async {
      final storage = MemoryContexts()..failWrites = true;
      final api = ExchangeApi();
      final flow = ExchangeOperation(
        api: api,
        store: storage,
        owner: 'fixture',
        orderId: 1,
        authorized: () => true,
      );
      await expectLater(
        flow.confirm({'pedido_origen_id': 1}),
        throwsA(isA<FileSystemException>()),
      );
      final uuid = flow.payload!['operacion_id'];
      await expectLater(flow.confirm({}), throwsA(isA<FileSystemException>()));
      expect(api.posts, 0);
      storage.failWrites = false;
      await flow.confirm({});
      expect(api.posts, 1);
      expect(api.sent!['operacion_id'], uuid);
      expect(storage.values[flow.key]!['payload']['operacion_id'], uuid);
    },
  );
  for (final width in [320.0, 390.0]) {
    testWidgets('normal orders tab opens the downloaded receipt at $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final local = OfflineService(
        auth: DownloadAuth(),
        store: fixture.MemoryStore(),
        monitor: false,
      );
      addTearDown(local.dispose);
      final key = GlobalKey();
      await tester.pumpWidget(
        ChangeNotifierProvider<OfflineService>.value(
          value: local,
          child: MaterialApp(
            theme: AppTheme.luxuryTheme,
            home: RepaintBoundary(
              key: key,
              child: OrdersScreen(service: DownloadedHistory()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Ver Comprobante Oficial'));
      await tester.tap(find.text('Ver Comprobante Oficial'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Moda Oriente'), findsWidgets);
      expect(find.text('Cargando comprobante oficial...'), findsNothing);
      expect(tester.takeException(), isNull);
      await capture(tester, key, 'comprobante-${width.toInt()}');
    });
    testWidgets('exchange works without prior catalog download at $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final auth = DownloadAuth();
      final local = OfflineService(
        auth: auth,
        api: StoreApi(),
        store: fixture.MemoryStore(),
        monitor: false,
      );
      addTearDown(local.dispose);
      addTearDown(auth.dispose);
      await tester.pump();
      await local.ready;
      local.bundle = null;
      final api = ExchangeApi()..needsPayment = true;
      final op = ExchangeOperation(
        api: api,
        store: MemoryContexts(),
        owner: local.owner!,
        orderId: 1,
        authorized: () => true,
      );
      int? paymentOrder;
      final key = GlobalKey();
      await tester.pumpWidget(
        ChangeNotifierProvider<OfflineService>.value(
          value: local,
          child: MaterialApp(
            theme: AppTheme.luxuryTheme,
            home: RepaintBoundary(
              key: key,
              child: Scaffold(
                body: ExchangeSheet(
                  order: Order.fromJson(order(1)),
                  orderService: api,
                  offline: local,
                  operation: op,
                  onConfirmed: () {},
                  paymentBuilder: (id) {
                    paymentOrder = id;
                    return Scaffold(
                      body: TextButton(
                        onPressed: () => Navigator.pop(key.currentContext!),
                        child: const Text('Cerrar pago'),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();
      expect(find.text('0'), findsOneWidget);
      await tester.tap(
        find.byTooltip('Devolver una unidad de Camisa de algodón'),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(SwitchListTile));
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(api.searches, 1);
      await tester.ensureVisible(find.text('Bs 210.00'));
      await tester.tap(find.text('Bs 210.00'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('L · Negro (+1)'));
      await tester.tap(find.text('L · Negro (+1)'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Revisar importes'));
      await tester.tap(find.text('Revisar importes'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Confirmar cambio'));
      await capture(tester, key, 'cambio-${width.toInt()}');
      await tester.tap(find.text('Confirmar cambio'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(paymentOrder, 44);
      expect(api.posts, 1);
      expect(api.sent!['sucursal_id'], 1);
      expect(api.sent!['devoluciones'], [
        {'item_pedido_id': 10, 'cantidad': 1},
      ]);
      await tester.tap(find.text('Cerrar pago'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pagar diferencia con Stripe'), findsOneWidget);
      expect(api.posts, 1);
      expect(tester.takeException(), isNull);
    });
    testWidgets(
      'download sheet displays honest progress and complete normal store at $width',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 720));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final api = StoreApi();
        final auth = DownloadAuth();
        final local = OfflineService(
          auth: auth,
          api: api,
          store: fixture.MemoryStore(),
          monitor: false,
        );
        addTearDown(local.dispose);
        addTearDown(auth.dispose);
        await tester.pump();
        await local.ready;
        local.bundle = fixture.bundle();
        final cart = CartService(
          apiClient: api,
          offline: local,
          localStore: MemoryContexts(),
        )..bindOwner('1_4');
        final purchases = DeferredService(
          auth: auth,
          client: api,
          cart: cart,
          local: MemoryContexts(),
          automatic: false,
        );
        addTearDown(cart.dispose);
        addTearDown(purchases.dispose);
        // Automatic=false deliberately leaves the service unbound; bind through its public auth listener.
        auth.refreshSession();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        final key = GlobalKey();
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<OfflineService>.value(value: local),
              ChangeNotifierProvider<CartService>.value(value: cart),
              ChangeNotifierProvider<DeferredService>.value(value: purchases),
            ],
            child: MaterialApp(
              theme: AppTheme.luxuryTheme,
              home: RepaintBoundary(
                key: key,
                child: Scaffold(
                  body: StoreDownloadSheet(orders: DownloadOrders()),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Actualizar descarga'));
        await tester.tap(find.text('Actualizar descarga'));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 600)),
        );
        await tester.pumpAndSettle();
        expect(find.text('4 de 4 apartados guardados'), findsOneWidget);
        expect(
          find.text('Descarga lista. Continúa en Tienda, Carrito o Pedidos.'),
          findsOneWidget,
        );
        expect(api.posts, 0);
        expect(tester.takeException(), isNull);
        await capture(tester, key, 'descarga-${width.toInt()}');
      },
    );
  }
}

class _BundleApi extends StoreApi {
  final Map<String, dynamic> data;
  _BundleApi(this.data);
  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    bool requiresAuth = true,
    Duration timeout = const Duration(seconds: 15),
  }) async => data;
}

class _Photos extends fixture.MemoryStore {
  final saved = <String, Uint8List>{};
  @override
  Future<void> savePhoto(String owner, String url, Uint8List bytes) async {
    saved[url] = bytes;
  }
}

class MemoryContexts extends DeferredStore {
  bool failWrites = false;
  final values = <String, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>?> context(String owner) async => values[owner];
  @override
  Future<void> saveContext(String owner, Map<String, dynamic> data) async {
    if (failWrites) throw const FileSystemException('Almacenamiento lleno');
    values[owner] = jsonDecode(jsonEncode(data));
  }

  @override
  Future<List<Map<String, dynamic>>> purchases(String owner) async => [];
}

class DownloadOrders extends OrderService {
  @override
  Future<int> prepareDownload({void Function(int count)? onProgress}) async {
    onProgress?.call(2);
    return 2;
  }
}

class DownloadedHistory extends OrderService {
  @override
  Future<List<Order>> getMyOrders({int? beforeId, int limit = 50}) async => [
    Order.fromJson(order(1)),
  ];
  @override
  Future<Map<String, dynamic>> getOrderReceipt(int id) async => {
    'order': order(id),
    'empresa': {'nombre': 'Moda Oriente', 'direccion': 'Sucursal Centro'},
    'items': order(id)['items'],
    'payments': [
      {'metodo': 'TARJETA'},
    ],
  };
}
