import 'package:drapemind_mobile/paquetes/catalogo_comercializacion/buscar_filtrar_prendas/dominio/catalog_filter.dart';
import 'package:drapemind_mobile/paquetes/catalogo_comercializacion/dominio/modelos/catalog_models.dart';

class FiltrarPrendas {
  const FiltrarPrendas();

  List<Product> call({
    required Iterable<Product> products,
    required Iterable<Category> categories,
    required CatalogFilter filter,
  }) {
    final categoryNames = {
      for (final category in categories) category.id: category.nombre,
    };
    return products
        .where((product) {
          if (filter.categoryId != null &&
              product.categoriaId != filter.categoryId) {
            return false;
          }
          final expectedGender = filter.gender.trim().toUpperCase();
          final productGender = product.generoObjetivo.trim().toUpperCase();
          if (expectedGender.isNotEmpty &&
              expectedGender != 'TODOS' &&
              productGender != expectedGender &&
              productGender != 'UNISEX') {
            return false;
          }
          if (filter.maxPrice != null && product.precio > filter.maxPrice!) {
            return false;
          }

          final searchable = [
            product.nombre,
            product.descripcion ?? '',
            product.marca ?? '',
            product.material ?? '',
            categoryNames[product.categoriaId] ?? '',
          ].join(' ').toLowerCase();
          return _matches(searchable, filter.query) &&
              _matches(searchable, filter.semanticQuery);
        })
        .toList(growable: false);
  }

  bool _matches(String searchable, String query) {
    final terms = query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty);
    return terms.every(searchable.contains);
  }
}
