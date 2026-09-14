class CatalogFilter {
  final int? categoryId;
  final String gender;
  final double? maxPrice;
  final String query;
  final String semanticQuery;

  const CatalogFilter({
    this.categoryId,
    this.gender = 'TODOS',
    this.maxPrice,
    this.query = '',
    this.semanticQuery = '',
  });
}

class CatalogPreset {
  final String key;
  final String label;
  final String semanticQuery;
  final double? maxPrice;
  final bool clearsFilters;

  const CatalogPreset({
    required this.key,
    required this.label,
    this.semanticQuery = '',
    this.maxPrice,
    this.clearsFilters = false,
  });
}

abstract final class CatalogPresets {
  static const all = <CatalogPreset>[
    CatalogPreset(
      key: 'TODOS',
      label: 'Catálogo completo',
      clearsFilters: true,
    ),
    CatalogPreset(
      key: 'CENA',
      label: 'Cena & noche elegante',
      semanticQuery: 'seda',
    ),
    CatalogPreset(
      key: 'POLERAS_TOP',
      label: 'Poleras de alta gama',
      semanticQuery: 'polera',
    ),
    CatalogPreset(
      key: 'CASUAL_ECONOMICO',
      label: 'Casual hasta Bs 300',
      maxPrice: 300,
    ),
  ];

  static CatalogPreset byKey(String key) =>
      all.firstWhere((preset) => preset.key == key, orElse: () => all.first);
}
