import '../models/branch_models.dart';
import '../network/api_client.dart';

class BranchService {
  final ApiClient _apiClient;

  BranchService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  Future<List<Branch>> getBranches() async {
    final response = await _apiClient.get('/branches', requiresAuth: false);
    return response is List
        ? response
              .map((item) => Branch.fromJson(item as Map<String, dynamic>))
              .toList()
        : [];
  }

  Future<List<BranchStock>> getProductAvailability(int productId) async {
    final response = await _apiClient.get(
      '/branches/products/$productId/availability',
      requiresAuth: false,
    );
    return response is List
        ? response
              .map((item) => BranchStock.fromJson(item as Map<String, dynamic>))
              .toList()
        : [];
  }
}
