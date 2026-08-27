import '../models/ar_models.dart';
import '../network/api_client.dart';

class ArService {
  final ApiClient _apiClient = ApiClient();

  /// Obtiene la configuración de probador AR, matriz de tallas y físicas textiles
  Future<ArConfigModel> getTryOnConfig(
    int productId, {
    double? userChest,
    double? userWaist,
    double? userHeight,
  }) async {
    final queryParams = <String, String>{};
    if (userChest != null) queryParams['user_chest'] = userChest.toString();
    if (userWaist != null) queryParams['user_waist'] = userWaist.toString();
    if (userHeight != null) queryParams['user_height'] = userHeight.toString();

    final queryString = queryParams.isNotEmpty
        ? '?${Uri(queryParameters: queryParams).query}'
        : '';

    final response = await _apiClient.get('/ar/products/$productId/try-on-config$queryString');
    return ArConfigModel.fromJson(response as Map<String, dynamic>);
  }
}
