import 'package:flutter_test/flutter_test.dart';

import 'package:drapemind_mobile/paquetes/catalogo_comercializacion/buscar_filtrar_prendas/aplicacion/filtrar_prendas.dart';
import 'package:drapemind_mobile/paquetes/catalogo_comercializacion/buscar_filtrar_prendas/dominio/catalog_filter.dart';
import 'package:drapemind_mobile/paquetes/catalogo_comercializacion/dominio/modelos/catalog_models.dart';

void main() {
  const filterProducts = FiltrarPrendas();
  final categories = [
    Category(id: 1, nombre: 'Pantalones', slug: 'pantalones'),
  ];
  final products = [
    Product(
      id: 1,
      categoriaId: 1,
      nombre: 'Pantalón lino claro',
      descripcion: 'Corte relajado',
      material: 'Lino',
      precio: 280,
      generoObjetivo: 'UNISEX',
      createdAt: DateTime(2026),
    ),
    Product(
      id: 2,
      categoriaId: 1,
      nombre: 'Pantalón sastrero negro',
      material: 'Lana',
      precio: 520,
      generoObjetivo: 'MASCULINO',
      createdAt: DateTime(2026),
    ),
  ];

  test('combina texto, categoría y presupuesto sin depender de la vista', () {
    final result = filterProducts(
      products: products,
      categories: categories,
      filter: const CatalogFilter(
        categoryId: 1,
        maxPrice: 300,
        semanticQuery: 'pantalón lino',
      ),
    );

    expect(result.map((item) => item.id), [1]);
  });

  test('incluye prendas unisex al filtrar por género', () {
    final result = filterProducts(
      products: products,
      categories: categories,
      filter: const CatalogFilter(gender: 'FEMENINO'),
    );

    expect(result.map((item) => item.id), [1]);
  });
}
