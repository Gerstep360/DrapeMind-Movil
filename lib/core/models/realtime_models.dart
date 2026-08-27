class RealtimeEvent {
  final String type;
  final int? orderId;
  final int? reservationId;
  final int? paymentId;
  final String? status;
  final Map<String, dynamic> raw;

  RealtimeEvent({
    required this.type,
    this.orderId,
    this.reservationId,
    this.paymentId,
    this.status,
    this.raw = const {},
  });

  factory RealtimeEvent.fromJson(Map<String, dynamic> json) {
    return RealtimeEvent(
      type: json['type']?.toString() ?? 'unknown',
      orderId: json['order_id'] is int
          ? json['order_id']
          : int.tryParse(json['order_id']?.toString() ?? ''),
      reservationId: json['reservation_id'] is int
          ? json['reservation_id']
          : int.tryParse(json['reservation_id']?.toString() ?? ''),
      paymentId: json['payment_id'] is int
          ? json['payment_id']
          : int.tryParse(json['payment_id']?.toString() ?? ''),
      status: json['status']?.toString(),
      raw: json,
    );
  }
}
