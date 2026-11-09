import 'cu13_offline_service.dart';
import 'cu13_catalogo_descargado.dart';
import 'cu13_models.dart';
import 'package:drapemind_mobile/core/network/api_exception.dart';
import 'package:drapemind_mobile/core/network/api_client.dart';
import 'package:drapemind_mobile/segundo_parcial/cu13_catalogo_offline/cu13_catalog_models.dart';

class CatalogService {
  final ApiClient _apiClient;
  OfflineService? offline;
  Future<dynamic> _read(
    Future<dynamic> Function() remote,
    dynamic Function(OfflineBundle) cached,
  ) async {
    final local = offline;
    if (local != null) {
      await local.ready;
      if (!local.online && local.usable) return cached(local.bundle!);
    }
    try {
      return await remote();
    } on ApiException catch (error) {
      if (local != null &&
          (error is NetworkException ||
              [502, 503, 504].contains(error.statusCode)) &&
          local.usable) {
        local.useDownloadedData();
        return cached(local.bundle!);
      }
      rethrow;
    }
  }

  CatalogService({ApiClient? apiClient, this.offline})
    : _apiClient = apiClient ?? ApiClient();

  /// Retrieve active categories
  Future<List<Category>> getCategories() async {
    final response = await _read(
      () => _apiClient.get('/catalog/categories', requiresAuth: false),
      (bundle) => bundle.rows('categories'),
    );
    if (response is List) {
      return response
          .map((c) => Category.fromJson(c as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Search and filter products
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
    final queryParams = <String, dynamic>{
      if (categoriaId != null) 'categoria_id': categoriaId,
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      if (calidadMin != null) 'calidad_min': calidadMin,
      if (genero != null && genero.trim().isNotEmpty) 'genero': genero.trim(),
      'limit': limit,
      'offset': offset,
      if (maxPrice != null) 'precio_max': maxPrice,
      if (talla != null && talla.isNotEmpty) 'talla': talla,
    };

    final response = await _read(
      () => _apiClient.get(
        '/catalog/products',
        queryParams: queryParams,
        requiresAuth: false,
      ),
      (bundle) {
        final rows = downloadedCatalog(bundle).where((p) {
          final text =
              '${p['nombre']} ${p['descripcion'] ?? ""} ${p['marca'] ?? ""}'
                  .toLowerCase();
          return (categoriaId == null || p['categoria_id'] == categoriaId) &&
              (query == null || text.contains(query.toLowerCase().trim())) &&
              (maxPrice == null ||
                  double.parse(p['precio'].toString()) <= maxPrice) &&
              (genero == null ||
                  genero.isEmpty ||
                  p['genero_objetivo'] == genero ||
                  p['genero_objetivo'] == 'UNISEX') &&
              (talla == null ||
                  talla.isEmpty ||
                  (p['variantes'] as List).any(
                    (v) => v['talla'] == talla && v['stock_disponible'] > 0,
                  )) &&
              (calidadMin == null ||
                  ((p['calidad_nivel'] as num?)?.toInt() ?? 3) >= calidadMin);
        }).toList();
        return rows.skip(offset).take(limit).toList();
      },
    );

    if (response is List) {
      return response
          .map((p) => Product.fromJson(p as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Get product detail with all variants and stock
  Future<Product> getProductDetail(int id) async {
    final response = await _read(
      () => _apiClient.get('/catalog/products/$id', requiresAuth: false),
      (bundle) {
        final product = downloadedCatalog(
          bundle,
        ).where((p) => p['id'] == id).firstOrNull;
        if (product == null) {
          throw NotFoundException('Esta prenda no forma parte de tu descarga.');
        }
        return product;
      },
    );
    return Product.fromJson(response as Map<String, dynamic>);
  }

  Future<List<Product>> getFavorites() async {
    final response = await _apiClient.get('/catalog/favorites');
    return response is List
        ? response
              .map((item) => Product.fromJson(item as Map<String, dynamic>))
              .toList()
        : [];
  }

  Future<void> addFavorite(int productId) async {
    await _apiClient.post('/catalog/favorites/$productId', body: {});
  }

  Future<void> removeFavorite(int productId) async {
    await _apiClient.delete('/catalog/favorites/$productId');
  }

  Future<bool> toggleFavorite(int productId) async {
    try {
      final favs = await getFavorites();
      final isFav = favs.any((f) => f.id == productId);
      if (isFav) {
        await removeFavorite(productId);
        return false;
      } else {
        await addFavorite(productId);
        return true;
      }
    } catch (_) {
      return false;
    }
  }
}
