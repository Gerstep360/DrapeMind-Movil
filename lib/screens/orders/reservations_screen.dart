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
  final Set<int> _busyIds = {};

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

  bool _hasActiveQr(Reservation reservation) => {
    ReservationStatus.pendiente,
    ReservationStatus.confirmada,
    ReservationStatus.enPreparacion,
    ReservationStatus.lista,
  }.contains(reservation.estado);

  Future<void> _showQr(Reservation reservation) async {
    setState(() => _busyIds.add(reservation.id));
    try {
      final bytes = await _reservationService.getReservationQr(reservation.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          backgroundColor: AppColors.paperLight,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'QR DE RECOJO',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.3,
                    color: AppColors.forest,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Reserva ${reservation.codigoPublico}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                Semantics(
                  label: 'Código QR de la reserva ${reservation.codigoPublico}',
                  image: true,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    color: AppColors.white,
                    child: Image.memory(
                      bytes,
                      width: 230,
                      height: 230,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Muéstralo al personal cuando llegues al showroom. No compartas este código.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMutedStrong,
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Listo'),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('No se pudo generar el QR de esta reserva.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busyIds.remove(reservation.id));
    }
  }

  Future<void> _cancelReservation(Reservation reservation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar reserva'),
        content: const Text(
          'Las prendas volverán a estar disponibles en la sucursal. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Conservar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancelar reserva'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busyIds.add(reservation.id));
    try {
      await _reservationService.cancelReservation(reservation.id);
      await _loadReservations();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reserva cancelada y stock liberado.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('No se pudo cancelar la reserva.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busyIds.remove(reservation.id));
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
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.forest),
            )
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : _reservations.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppSvg.raw(
                    AppSvg.clock,
                    size: 50,
                    color: AppColors.textMuted,
                  ),
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
                              color: res.isExpired
                                  ? AppColors.danger
                                  : AppColors.forest,
                            ),
                          ),
                          if (res.observacion != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              res.observacion!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                          if (res.sucursalId != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Showroom asignado: #${res.sucursalId}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                          if (_hasActiveQr(res)) ...[
                            const Divider(height: 22),
                            if (_busyIds.contains(res.id))
                              const LinearProgressIndicator(
                                color: AppColors.forest,
                              )
                            else
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _showQr(res),
                                      icon: const Icon(
                                        Icons.qr_code_2,
                                        size: 18,
                                      ),
                                      label: const Text('Mostrar QR'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.danger,
                                        side: const BorderSide(
                                          color: AppColors.danger,
                                        ),
                                      ),
                                      onPressed: () => _cancelReservation(res),
                                      icon: const Icon(Icons.close, size: 17),
                                      label: const Text('Cancelar'),
                                    ),
                                  ),
                                ],
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

    if (status == ReservationStatus.confirmada ||
        status == ReservationStatus.lista) {
      bg = AppColors.successBg;
      fg = AppColors.success;
    } else if (status == ReservationStatus.enPreparacion) {
      bg = AppColors.warningBg;
      fg = AppColors.warning;
    } else if (status == ReservationStatus.vencida ||
        status == ReservationStatus.cancelada) {
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
