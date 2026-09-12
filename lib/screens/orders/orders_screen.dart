import 'package:flutter/material.dart';
import '../../core/core.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_svg.dart';
import 'reservations_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _orderService = OrderService();
  List<Order> _orders = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _orderService.getMyOrders();
      setState(() {
        _orders = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'No se pudieron cargar tus pedidos.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: AppColors.ink,
                shape: BoxShape.circle,
              ),
              child: AppSvg.raw(AppSvg.package, size: 14, color: AppColors.lime),
            ),
            const SizedBox(width: 10),
            const Text(
              'Mis Compras',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.paperDark,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.line),
              ),
              child: AppSvg.raw(AppSvg.clock, size: 15, color: AppColors.ink),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReservationsScreen()),
              );
            },
            tooltip: 'Ver mis reservas 48h',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.ink),
            )
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : _orders.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: AppColors.paperDark,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: AppSvg.raw(
                        AppSvg.package,
                        size: 32,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'No tienes pedidos registrados todavía',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              color: AppColors.ink,
              onRefresh: _loadOrders,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _orders.length,
                itemBuilder: (context, index) {
                  final order = _orders[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.line),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0410110F),
                          blurRadius: 12,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Pedido ${order.codigoPublico}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: AppColors.ink,
                              ),
                            ),
                            _buildStatusBadge(order.estado),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tipo: ${order.tipoEntrega.displayName} · Canal: ${order.canal}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Divider(),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${order.items.length} prendas',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMutedStrong,
                              ),
                            ),
                            Text(
                              'Total: Bs ${order.total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                color: AppColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildStatusBadge(OrderStatus status) {
    Color bg = AppColors.paperDark;
    Color fg = AppColors.textMain;

    if (status == OrderStatus.pagado || status == OrderStatus.entregado) {
      bg = AppColors.successBg;
      fg = AppColors.success;
    } else if (status == OrderStatus.pendientePago) {
      bg = AppColors.warningBg;
      fg = AppColors.warning;
    } else if (status == OrderStatus.cancelado) {
      bg = AppColors.dangerBg;
      fg = AppColors.danger;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
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
