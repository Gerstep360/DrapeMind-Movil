import '../models/order_models.dart';
import '../models/reservation_models.dart';
import '../network/api_client.dart';

class ReservationService {
  final ApiClient _apiClient;

  ReservationService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// Retrieve the current user's reservations
  Future<List<Reservation>> getMyReservations() async {
    final response = await _apiClient.get('/reservations');
    if (response is List) {
      return response
          .map((r) => Reservation.fromJson(r as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Create a garment reservation for 48h
  Future<Reservation> createReservation({
    required int varianteId,
    String? observacion,
  }) async {
    final response = await _apiClient.post(
      '/reservations',
      body: {
        'variante_id': varianteId,
        if (observacion != null && observacion.isNotEmpty)
          'observacion': observacion,
      },
    );
    return Reservation.fromJson(response as Map<String, dynamic>);
  }

  /// Validate a showroom QR token
  Future<Reservation> validateQr(String qrToken) async {
    final response = await _apiClient.post(
      '/reservations/validate-qr',
      body: {'qr_token': qrToken.trim()},
    );
    return Reservation.fromJson(response as Map<String, dynamic>);
  }

  /// Convert a showroom reservation into a completed purchase order
  Future<Order> convertReservationToOrder(int reservationId) async {
    final response = await _apiClient.post(
      '/reservations/$reservationId/convert-to-order',
      body: {},
    );
    return Order.fromJson(response as Map<String, dynamic>);
  }
}
