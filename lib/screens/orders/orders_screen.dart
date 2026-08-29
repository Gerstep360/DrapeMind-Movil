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
        title: Row(
          children: [
            AppSvg.raw(AppSvg.package, size: 18, color: AppColors.white),
            const SizedBox(width: 8),
            const Text('MIS COMPRAS Y PEDIDOS'),
          ],
        ),
        actions: [
          IconButton(
            icon: AppSvg.raw(AppSvg.clock, size: 18, color: AppColors.acid),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReservationsScreen()),
              );
            },
            tooltip: 'Ver mis reservas 48h',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.forest),
            )
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : _orders.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppSvg.raw(
                    AppSvg.package,
                    size: 50,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No tienes pedidos registrados todavía',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.forestDark,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              color: AppColors.forest,
              onRefresh: _loadOrders,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _orders.length,
                itemBuilder: (context, index) {
                  final order = _orders[index];
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
                                'Pedido ${order.codigoPublico}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13.5,
                                ),
                              ),
                              _buildStatusBadge(order.estado),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tipo: ${order.tipoEntrega.displayName} · Canal: ${order.canal}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Divider(),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${order.items.length} prendas',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMutedStrong,
                                ),
                              ),
                              Text(
                                'Total: Bs ${order.total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: AppColors.forest,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildStatusBadge(OrderStatus status) {
    Color bg = AppColors.paperLight;
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
