import '../models/catalog_models.dart';
import '../network/api_client.dart';

class CatalogService {
  final ApiClient _apiClient;

  CatalogService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// Retrieve active categories
  Future<List<Category>> getCategories() async {
    final response = await _apiClient.get(
      '/catalog/categories',
      requiresAuth: false,
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
  }) async {
    final queryParams = <String, dynamic>{
      if (categoriaId != null) 'categoria_id': categoriaId,
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      if (calidadMin != null) 'calidad_min': calidadMin,
      if (genero != null && genero.trim().isNotEmpty) 'genero': genero.trim(),
      'limit': limit,
      'offset': offset,
    };

    final response = await _apiClient.get(
      '/catalog/products',
      queryParams: queryParams,
      requiresAuth: false,
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
    final response = await _apiClient.get(
      '/catalog/products/$id',
      requiresAuth: false,
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
}
