import 'package:drapemind_mobile/core/network/api_client.dart';
import 'package:drapemind_mobile/segundo_parcial/cu07_sucursales/cu07_branch_models.dart';

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
