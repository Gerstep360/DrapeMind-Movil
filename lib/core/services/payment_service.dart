import '../models/payment_models.dart';
import '../network/api_client.dart';

class PaymentService {
  final ApiClient _apiClient;

  PaymentService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// Initiate a payment for an existing order (QR, Tarjeta, Efectivo)
  Future<Payment> initiatePayment(PaymentCreate request) async {
    final response = await _apiClient.post(
      '/payments',
      body: request.toJson(),
    );
    return Payment.fromJson(response as Map<String, dynamic>);
  }

  /// Get payments registered for a specific order
  Future<List<Payment>> getOrderPayments(int orderId) async {
    final response = await _apiClient.get('/payments/order/$orderId');
    if (response is List) {
      return response
          .map((p) => Payment.fromJson(p as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Mock confirm a QR / Card payment (for test environments and demos)
  Future<Payment> mockConfirmPayment(int paymentId) async {
    final response = await _apiClient.post(
      '/payments/$paymentId/mock-confirm',
      body: {},
    );
    return Payment.fromJson(response as Map<String, dynamic>);
  }
}
