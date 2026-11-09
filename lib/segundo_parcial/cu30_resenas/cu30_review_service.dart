import 'package:drapemind_mobile/core/network/api_client.dart';
import 'package:drapemind_mobile/segundo_parcial/cu30_resenas/cu30_review_models.dart';

class ReviewService {
  final ApiClient _apiClient;

  ReviewService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// Obtiene el resumen de calificaciones y la lista de reseñas para una prenda
  Future<ProductReviewsResponse> getProductReviews(int productId) async {
    final response = await _apiClient.get('/products/$productId/reviews');
    return ProductReviewsResponse.fromJson(response as Map<String, dynamic>);
  }

  /// Crea o actualiza la reseña del cliente autenticado
  Future<ProductReviewItem> submitReview({
    required int productId,
    required int rating,
    String? title,
    required String comment,
  }) async {
    final response = await _apiClient.post(
      '/products/$productId/reviews',
      body: {
        'calificacion': rating,
        if (title != null && title.isNotEmpty) 'titulo': title,
        'comentario': comment,
      },
    );
    return ProductReviewItem.fromJson(response as Map<String, dynamic>);
  }

  /// Elimina la reseña propia del cliente autenticado
  Future<bool> deleteReview(int productId) async {
    final response = await _apiClient.delete('/products/$productId/reviews');
    if (response is Map && response['ok'] == true) {
      return true;
    }
    return true;
  }
}
