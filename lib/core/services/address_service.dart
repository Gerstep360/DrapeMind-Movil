import '../models/address_models.dart';
import '../network/api_client.dart';

class AddressService {
  final ApiClient _apiClient;

  AddressService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// Retrieve user saved delivery addresses
  Future<List<Address>> getMyAddresses() async {
    final response = await _apiClient.get('/users/me/addresses');
    if (response is List) {
      return response
          .map((a) => Address.fromJson(a as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Create a new delivery address
  Future<Address> createAddress(AddressInput input) async {
    final response = await _apiClient.post(
      '/users/me/addresses',
      body: input.toJson(),
    );
    return Address.fromJson(response as Map<String, dynamic>);
  }

  /// Delete a saved address
  Future<void> deleteAddress(int addressId) async {
    await _apiClient.delete('/users/me/addresses/$addressId');
  }
}
