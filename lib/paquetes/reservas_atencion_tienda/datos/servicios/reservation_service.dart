import 'dart:typed_data';

import 'package:drapemind_mobile/core/network/api_client.dart';
import 'package:drapemind_mobile/paquetes/carrito_pedidos_pagos/dominio/modelos/order_models.dart';
import 'package:drapemind_mobile/paquetes/reservas_atencion_tienda/dominio/modelos/reservation_models.dart';

class ReservationService {
  final ApiClient _apiClient;

  ReservationService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

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
    int cantidad = 1,
    int? sucursalId,
    String? observacion,
  }) => createReservationItems(
    items: [ReservationItemRequest(varianteId: varianteId, cantidad: cantidad)],
    sucursalId: sucursalId,
    observacion: observacion,
  );

  /// Reserva varias variantes verificadas por el backend en una sola operación.
  Future<Reservation> createReservationItems({
    required List<ReservationItemRequest> items,
    int? sucursalId,
    String? observacion,
  }) async {
    if (items.isEmpty) {
      throw ArgumentError.value(
        items,
        'items',
        'Debe incluir al menos una prenda',
      );
    }
    final response = await _apiClient.post(
      '/reservations',
      body: {
        if (sucursalId != null) 'sucursal_id': sucursalId,
        'items': items.map((item) => item.toJson()).toList(growable: false),
        if (observacion != null && observacion.isNotEmpty)
          'observacion': observacion,
      },
    );
    return Reservation.fromJson(response as Map<String, dynamic>);
  }

  /// Reserva el perchero actual. El servidor toma sus prendas de forma
  /// transaccional y marca el carrito como convertido si la operación termina.
  Future<Reservation> createReservationFromCart({
    int? sucursalId,
    String? observacion,
  }) async {
    final response = await _apiClient.post(
      '/reservations',
      body: {
        if (sucursalId != null) 'sucursal_id': sucursalId,
        if (observacion != null && observacion.isNotEmpty)
          'observacion': observacion,
      },
    );
    return Reservation.fromJson(response as Map<String, dynamic>);
  }

  Future<Reservation> getReservation(int reservationId) async {
    final response = await _apiClient.get('/reservations/$reservationId');
    return Reservation.fromJson(response as Map<String, dynamic>);
  }

  Future<Uint8List> getReservationQr(int reservationId) =>
      _apiClient.getBytes('/reservations/$reservationId/qr');

  Future<Reservation> cancelReservation(int reservationId) async {
    final response = await _apiClient.post(
      '/reservations/$reservationId/cancel',
      body: {},
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
