import 'package:flutter/material.dart';
import '../../core/core.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_svg.dart';

class ReservationsScreen extends StatefulWidget {
  const ReservationsScreen({super.key});

  @override
  State<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen> {
  final _reservationService = ReservationService();
  List<Reservation> _reservations = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReservations();
  }

  Future<void> _loadReservations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _reservationService.getMyReservations();
      setState(() {
        _reservations = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'No se pudieron cargar tus reservas.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Row(
          children: [
            AppSvg.raw(AppSvg.clock, size: 18, color: AppColors.white),
            const SizedBox(width: 8),
            const Text('MIS RESERVAS 48H'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.forest))
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : _reservations.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AppSvg.raw(AppSvg.clock, size: 50, color: AppColors.textMuted),
                          const SizedBox(height: 12),
                          const Text(
                            'No tienes reservas activas',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.forestDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Puedes apartar cualquier prenda del catálogo durante 48h para probártela en el atelier.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: AppColors.forest,
                      onRefresh: _loadReservations,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _reservations.length,
                        itemBuilder: (context, index) {
                          final res = _reservations[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Reserva ${res.codigoPublico}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                      _buildStatusBadge(res.estado),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Vence: ${res.venceAt.toString().substring(0, 16)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: res.isExpired ? AppColors.danger : AppColors.forest,
                                    ),
                                  ),
                                  if (res.observacion != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      res.observacion!,
                                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _buildStatusBadge(ReservationStatus status) {
    Color bg = AppColors.paperLight;
    Color fg = AppColors.textMain;

    if (status == ReservationStatus.confirmada) {
      bg = AppColors.successBg;
      fg = AppColors.success;
    } else if (status == ReservationStatus.vencida || status == ReservationStatus.cancelada) {
      bg = AppColors.dangerBg;
      fg = AppColors.danger;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}
