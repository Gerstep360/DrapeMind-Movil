import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drapemind_mobile/compartido/componentes/navegacion/dm_mobile_navigation.dart';
import 'package:drapemind_mobile/compartido/componentes/productos/dm_product_card.dart';
import 'package:drapemind_mobile/core/theme/app_colors.dart';
import 'package:drapemind_mobile/core/theme/app_theme.dart';
import 'package:drapemind_mobile/paquetes/catalogo_comercializacion/dominio/modelos/catalog_models.dart';
import 'package:drapemind_mobile/paquetes/inteligencia_artificial_asistencia_moda/consultar_asistente_altair/presentacion/componentes/altair_welcome_state.dart';

void main() {
  testWidgets('DrapeMind mobile shell visual regression', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final product = Product(
      id: 1,
      categoriaId: 1,
      nombre: 'Polera Gráfica Edición Limitada',
      marca: 'Drape Studio',
      precio: 179,
      calidadNivel: 5,
      generoObjetivo: 'UNISEX',
      stockDisponible: 12,
      createdAt: DateTime(2026),
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.luxuryTheme,
        home: Scaffold(
          backgroundColor: AppColors.paper,
          extendBody: true,
          appBar: AppBar(title: const Text('Showroom')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 174,
                height: 340,
                child: DmProductCard(
                  product: product,
                  isFavorite: true,
                  onOpen: () {},
                  onFavorite: () {},
                  onQuickAdd: () {},
                ),
              ),
            ),
          ),
          bottomNavigationBar: DmMobileNavigation(
            selectedIndex: 0,
            cartCount: 2,
            onSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/drapemind_mobile_shell.png'),
    );
  });

  testWidgets('Altair empty state visual regression', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.luxuryTheme,
        home: Scaffold(
          appBar: AppBar(title: const Text('Altair · Stylist IA')),
          body: AltairWelcomeState(onPrompt: (_) {}, onOpenPreferences: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/altair_welcome.png'),
    );
  });
}
