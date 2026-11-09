import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:drapemind_mobile/segundo_parcial/cu05_acceso/cu05_auth_service.dart';
import 'package:drapemind_mobile/segundo_parcial/cu22_carrito_checkout/cu22_cart_service.dart';
import 'package:drapemind_mobile/segundo_parcial/cu22_carrito_checkout/cu22_compra.dart';
import 'package:drapemind_mobile/segundo_parcial/cu23_pagos/cu23_deferred_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:drapemind_mobile/core/network/api_client.dart';
import 'package:drapemind_mobile/core/network/api_exception.dart';
import 'package:drapemind_mobile/segundo_parcial/cu13_catalogo_offline/cu13_offline_store.dart';
import 'package:drapemind_mobile/segundo_parcial/cu13_catalogo_offline/cu13_offline_service.dart';
import 'package:drapemind_mobile/segundo_parcial/cu22_carrito_checkout/cu22_carrito_local.dart';
import 'package:drapemind_mobile/segundo_parcial/cu23_pagos/cu23_deferred_store.dart';
import 'package:drapemind_mobile/segundo_parcial/cu30_resenas/cu30_review_service.dart';
import 'package:drapemind_mobile/segundo_parcial/cu30_resenas/cu30_review_models.dart';
import 'package:drapemind_mobile/segundo_parcial/cu30_resenas/cu30_reviews_widget.dart';
import 'incremento_ii_offline_test.dart' as fixture;

class DraftApi extends ApiClient {
  @override
  Future<String?> getToken() async => null;
  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    bool requiresAuth = true,
    Duration timeout = const Duration(seconds: 15),
  }) async => throw NetworkException('Sin conexión');
  bool conflict = false;
  int calls = 0;
  Completer<void>? gate;
  @override
  Future<dynamic> put(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    bool requiresAuth = true,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    expect(path, '/cart/draft');
    calls++;
    await gate?.future;
    if (conflict) {
      throw ApiException(
        'Tu carrito cambió en otro dispositivo.',
        statusCode: 409,
      );
    }
    final lines = body['items'] as List;
    return {
      'id': 1,
      'items': lines
          .map(
            (l) => {
              'id': l['variante_id'],
              'variante_id': l['variante_id'],
              'producto_id': 1,
              'nombre': 'Camisa',
              'cantidad': l['cantidad'],
              'precio_unitario': 175,
              'subtotal': 175 * l['cantidad'],
              'stock_disponible': 10,
            },
          )
          .toList(),
      'subtotal': lines.fold<num>(
        0,
        (n, l) => n + 175 * (l['cantidad'] as int),
      ),
      'total_items': lines.fold<int>(0, (n, l) => n + (l['cantidad'] as int)),
    };
  }
}

class CheckoutStore extends DeferredStore {
  final contexts = <String, Map<String, dynamic>>{},
      pending = <String, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>?> context(String owner) async => contexts[owner];
  @override
  Future<void> saveContext(String owner, Map<String, dynamic> data) async {
    contexts[owner] = data;
  }

  @override
  Future<List<Map<String, dynamic>>> purchases(String owner) async =>
      pending.values.where((r) => r['owner'] == owner).toList();
  @override
  Future<void> save(Map<String, dynamic> row) async {
    pending[row['key']] = row;
  }
}

class Reviews extends ReviewService {
  final Completer<ProductReviewsResponse>? pending;
  Reviews({this.pending});
  @override
  Future<ProductReviewsResponse> getProductReviews(int id) async =>
      pending?.future ??
      ProductReviewsResponse.fromJson({
        'producto_id': id,
        'promedio': 5,
        'total': 1,
        'distribucion': {'5': 1},
        'resenas': [
          {
            'id': 1,
            'producto_id': id,
            'usuario_id': 4,
            'calificacion': 5,
            'comentario': 'Excelente calidad y talla.',
            'usuario_nombre': 'Cliente',
            'compra_verificada': true,
            'creado_en': '2026-11-08T15:00:00Z',
          },
        ],
      });
}

void main() {
  setUpAll(sqfliteFfiInit);
  test(
    'normal cart persists downloaded selections, serializes edits and preserves conflicts',
    () async {
      final dir = await Directory.systemTemp.createTemp('drapemind-store-');
      final db = OfflineStore(
        factory: databaseFactoryFfi,
        databasePath: '${dir.path}/drapemind.db',
      );
      final auth = fixture.TestAuth();
      final offline = OfflineService(auth: auth, store: db, monitor: false);
      await Future<void>.delayed(Duration.zero);
      await offline.ready;
      offline.bundle = fixture.bundle();
      offline.online = false;
      final api = DraftApi();
      LocalCart create() => LocalCart(
        offline: offline,
        api: api,
        store: DeferredStore(store: db),
        changed: (_) {},
      );
      final cart = create()..bind('1_4');
      await cart.ready;
      await Future.wait([
        cart.edit(
          'add',
          items: [
            {'variante_id': 1, 'cantidad': 1},
          ],
        ),
        cart.edit(
          'add',
          items: [
            {'variante_id': 1, 'cantidad': 2},
          ],
        ),
      ]);
      expect(cart.current!.totalItems, 3);
      expect(cart.current!.subtotal, 525);
      expect(api.calls, 0);
      final restored = create()..bind('1_4');
      await restored.ready;
      expect(restored.current!.totalItems, 3);
      expect(restored.dirty, isTrue);
      offline.online = true;
      api.conflict = true;
      await restored.synchronize();
      expect(restored.current!.totalItems, 3);
      expect(restored.dirty, isTrue);
      expect(restored.issue, contains('otro dispositivo'));
      api.conflict = false;
      api.gate = Completer<void>();
      final sync = restored.synchronize();
      await Future<void>.delayed(Duration.zero);
      final edit = restored.edit('quantity', id: -1, quantity: 4);
      api.gate!.complete();
      await sync.timeout(const Duration(seconds: 2));
      await edit.timeout(const Duration(seconds: 2));
      // Server assigns a positive id; the pending edit still addresses its variant.
      await restored.synchronize();
      expect(restored.current!.totalItems, 4);
      restored.bind('2_9');
      await restored.ready;
      expect(restored.current, isNull);
      restored.bind('1_4');
      await restored.ready;
      expect(restored.current!.totalItems, 4);
      offline.dispose();
      auth.dispose();
      await db.close();
      await dir.delete(recursive: true);
    },
  );
  for (final width in [320.0, 390.0]) {
    testWidgets('normal offline checkout saves the chosen cart at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = fixture.TestAuth(),
          api = DraftApi(),
          store = CheckoutStore();
      final offline = OfflineService(
        auth: auth,
        store: fixture.MemoryStore(),
        monitor: false,
      );
      await tester.pump();
      await offline.ready;
      offline.bundle = fixture.bundle();
      offline.online = false;
      final cart = CartService(
        apiClient: api,
        offline: offline,
        localStore: store,
      )..bindOwner('1_4');
      await cart.addItem(1, cantidad: 2);
      await store.saveContext(offline.owner!, {
        'owner': '1:4',
        'valid_until': fixture.bundle().validUntil.toIso8601String(),
        'downloaded_at': DateTime.now().toIso8601String(),
        'cart': cart.cart!.toJson(),
        'branches': [
          {'id': 1, 'nombre': 'Centro'},
        ],
        'addresses': [],
        'cards': [],
        'delivery_fee': '25.00',
      });
      final queue = DeferredService(
        auth: auth,
        client: api,
        local: store,
        cart: cart,
        automatic: false,
      );
      auth.notifyListeners();
      await queue.ready;
      queue.online = false;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: auth),
            ChangeNotifierProvider.value(value: offline),
            ChangeNotifierProvider.value(value: cart),
            ChangeNotifierProvider.value(value: queue),
          ],
          child: MaterialApp(home: CheckoutScreen(apiClient: api)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Confirmar compra'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Confirmar compra'));
      await tester.pumpAndSettle();
      expect(find.text('Tu compra está en Mis pedidos'), findsOneWidget);
      expect(queue.purchases.single['body']['items'], [
        {'variante_id': 1, 'cantidad': 2},
      ]);
      expect(queue.purchases.single['body']['total_autorizado'], '350.00');
      expect(cart.itemCount, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      queue.dispose();
      cart.dispose();
      offline.dispose();
      auth.dispose();
    });
    testWidgets('CU30 verified review and form fit $width', (tester) async {
      tester.view.physicalSize = Size(width, 950);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProductReviewsWidget(productId: 1, service: Reviews()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Excelente calidad y talla.'), findsOneWidget);
      await tester.tap(find.text('★ CALIFICAR'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('CU30 ignores late response after detail is closed', (
    tester,
  ) async {
    final pending = Completer<ProductReviewsResponse>();
    await tester.pumpWidget(
      MaterialApp(
        home: ProductReviewsWidget(
          productId: 1,
          service: Reviews(pending: pending),
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox());
    pending.complete(
      ProductReviewsResponse.fromJson({
        'producto_id': 1,
        'total': 0,
        'resenas': [],
      }),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
