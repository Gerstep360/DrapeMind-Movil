import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drapemind_mobile/core/theme/app_theme.dart';
import 'package:drapemind_mobile/compartido/componentes/navegacion/dm_mobile_navigation.dart';
import 'package:drapemind_mobile/paquetes/catalogo_comercializacion/datos/servicios/catalog_service.dart';
import 'package:drapemind_mobile/paquetes/catalogo_comercializacion/dominio/modelos/catalog_models.dart';
import 'package:drapemind_mobile/paquetes/catalogo_comercializacion/consultar_catalogo_prendas/presentacion/catalog_screen.dart';
import 'support/golden_assets.dart';

class FixtureCatalog extends CatalogService {
  final products =
      (jsonDecode(File('test/fixtures/catalog.json').readAsStringSync())
              as List)
          .map((p) => Product.fromJson(p as Map<String, dynamic>))
          .toList();
  double? requestedPrice;
  String? requestedSize;
  bool fail = false;
  @override
  Future<List<Category>> getCategories() async => [
    Category(id: 18, nombre: 'Vestidos', slug: 'vestidos'),
    Category(id: 26, nombre: 'Chaquetas', slug: 'chaquetas'),
  ];
  @override
  Future<List<Product>> getFavorites() async => [];
  @override
  Future<List<Product>> getProducts({
    int? categoriaId,
    String? query,
    int? calidadMin,
    String? genero,
    int limit = 50,
    int offset = 0,
    double? maxPrice,
    String? talla,
  }) async {
    requestedPrice = maxPrice;
    requestedSize = talla;
    if (fail) throw Exception('Fixture unavailable');
    return products;
  }

  @override
  Future<Product> getProductDetail(int id) async =>
      products.firstWhere((p) => p.id == id);
}

Future<void> mount(
  WidgetTester tester,
  FixtureCatalog catalog,
  Size size,
) async {
  await tester.binding.setSurfaceSize(size);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.luxuryTheme,
      home: Scaffold(
        body: CatalogScreen(catalogService: catalog),
        bottomNavigationBar: DmMobileNavigation(
          selectedIndex: 0,
          cartCount: 2,
          onSelected: (_) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    for (final p in catalog.products) {
      await precacheImage(
        MemoryImage(base64Decode(p.imagenes.first.split(',').last)),
        tester.element(find.byType(CatalogScreen)),
      );
    }
  });
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadGoldenFonts);
  for (final width in [390.0, 320.0]) {
    testWidgets(
      'Storefront ${width.toInt()}px renders clothes and navigation without overflow',
      (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await mount(tester, FixtureCatalog(), Size(width, 844));
        expect(find.text('Tienda'), findsOneWidget);
        expect(find.text('Carrito'), findsOneWidget);
        expect(find.text('Para todos tus días.'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/storefront_${width.toInt()}.png'),
        );
      },
    );
  }

  testWidgets('Size and budget filters are sent to the catalog service', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final catalog = FixtureCatalog();
    await mount(tester, catalog, const Size(390, 844));
    await tester.tap(find.text('Filtros'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hasta Bs 200'));
    await tester.tap(find.text('M'));
    await tester.tap(find.text('Ver prendas'));
    await tester.pumpAndSettle();
    expect(catalog.requestedPrice, 200);
    expect(catalog.requestedSize, 'M');
    expect(find.text('Talla M'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Failed catalog request offers a working retry', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final catalog = FixtureCatalog()..fail = true;
    await mount(tester, catalog, const Size(390, 844));
    expect(
      find.text('No pudimos cargar las prendas. Intenta de nuevo.'),
      findsOneWidget,
    );
    catalog.fail = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(
      find.text('No pudimos cargar las prendas. Intenta de nuevo.'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
