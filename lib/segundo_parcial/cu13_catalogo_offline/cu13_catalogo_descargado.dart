import 'cu13_models.dart';

List<Map<String, dynamic>> downloadedCatalog(OfflineBundle bundle) {
  return bundle.products.map((p) {
    final variants = bundle.variants
        .where((v) => v['producto_id'] == p['id'])
        .map((v) {
          final available = bundle.stock
              .where((s) => s['variante_id'] == v['id'])
              .fold<int>(0, (n, s) => n + (s['disponible'] as num).toInt());
          return {
            ...v,
            'stock_total': available,
            'stock_reservado': 0,
            'stock_disponible': available,
            'activo': true,
          };
        })
        .toList();
    return {
      ...p,
      'imagenes': ((p['imagenes'] as List?) ?? [])
          .map(
            (image) => image is String
                ? image
                : image is Map
                ? image['url']
                : null,
          )
          .whereType<String>()
          .toList(),
      'created_at': p['created_at'] ?? '1970-01-01T00:00:00Z',
      'activo': true,
      'variantes': variants,
      'stock_disponible': variants.fold<int>(
        0,
        (n, v) => n + (v['stock_disponible'] as int),
      ),
    };
  }).toList();
}
