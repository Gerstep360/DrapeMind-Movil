import '../cu13_catalogo_offline/cu13_offline_service.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../cu23_pagos/cu23_deferred_service.dart';
import '../cu23_pagos/cu23_pedidos_locales.dart';
import 'package:drapemind_mobile/compartido/componentes/notificaciones/notification_bell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drapemind_mobile/core/core.dart';
import 'package:drapemind_mobile/core/theme/app_colors.dart';
import 'package:drapemind_mobile/core/theme/app_svg.dart';
import 'package:drapemind_mobile/segundo_parcial/cu23_pagos/cu23_pago_tarjeta.dart';
import 'package:drapemind_mobile/paquetes/reservas_atencion_tienda/consultar_qr_cancelar_reserva/presentacion/reservations_screen.dart';
import 'cu20_exchange_sheet.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late final OrderService _orderService;
  List<Order> _orders = [];
  bool _isLoading = true;
  bool _more = true, _loadingMore = false;
  String? _errorMessage;
  DeferredService? _queue;
  bool _wasOnline = true;
  final Set<String> _paidSeen = {};
  String _selectedFilter = 'TODOS';
  int _request = 0;
  void _queueChanged() {
    final queue = _queue;
    if (queue == null || !mounted) return;
    final paid = queue.purchases
        .where((r) => queue.state(r) == 'PAGADA')
        .map((r) => r['operation'].toString())
        .toSet();
    final refresh =
        paid.difference(_paidSeen).isNotEmpty || (!_wasOnline && queue.online);
    _paidSeen.addAll(paid);
    _wasOnline = queue.online;
    if (refresh) unawaited(_loadOrders());
  }

  @override
  void dispose() {
    _queue?.removeListener(_queueChanged);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _orderService = OrderService(offline: context.read<OfflineService?>());
    _queue = context.read<DeferredService?>();
    _paidSeen.addAll(
      _queue?.purchases
              .where((r) => _queue!.state(r) == 'PAGADA')
              .map((r) => r['operation'].toString()) ??
          [],
    );
    _wasOnline = _queue?.online ?? true;
    _queue?.addListener(_queueChanged);
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    final request = ++_request;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _orderService.getMyOrders();
      if (!mounted || request != _request) return;
      setState(() {
        _orders = list;
        _more =
            list.length == 50 &&
            context.read<OfflineService?>()?.online != false;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || request != _request) return;
      setState(() {
        _more = false;
        _errorMessage = 'No se pudieron cargar tus pedidos.';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_more || _orders.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final list = await _orderService.getMyOrders(beforeId: _orders.last.id);
      if (!mounted) return;
      setState(() {
        _orders = [..._orders, ...list];
        _more = list.length == 50;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudieron cargar más pedidos. Puedes reintentar.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _showReceiptModal(Order order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          _ReceiptModalSheet(orderId: order.id, initialOrder: order),
    );
  }

  @override
  Widget build(BuildContext context) {
    final queue = context.watch<DeferredService?>();
    final hasPending = queue?.purchases.isNotEmpty ?? false;
    final pendingIds =
        queue?.purchases
            .where((r) => queue.state(r) != 'PAGADA')
            .map((r) => r['remote']?['pedido_id'])
            .toSet() ??
        <int>{};
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
              child: AppSvg.raw(
                AppSvg.package,
                size: 14,
                color: AppColors.lime,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Mis Compras',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: AppColors.ink,
                ),
              ),
            ),
          ],
        ),
        actions: [
          const NotificationBell(),
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
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<DeferredService?>()?.refresh();
          await _loadOrders();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  _filterChip('TODOS', 'Todos'),
                  const SizedBox(width: 8),
                  _filterChip('PAGADO', 'Pagados'),
                  const SizedBox(width: 8),
                  _filterChip('DEVUELTO', 'Devoluciones'),
                  const SizedBox(width: 8),
                  _filterChip('PENDIENTE_PAGO', 'Por pagar'),
                  const SizedBox(width: 8),
                  _filterChip('CANCELADO', 'Cancelados'),
                ],
              ),
            ),
            PendingOrderCards(existingIds: _orders.map((o) => o.id).toSet()),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_errorMessage != null && _orders.isEmpty && !hasPending)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(_errorMessage!),
                    TextButton(
                      onPressed: _loadOrders,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            if (!_isLoading &&
                _orders.isEmpty &&
                !hasPending &&
                _errorMessage == null)
              const Padding(
                padding: EdgeInsets.all(30),
                child: Text(
                  'Aquí verás tus compras y el estado de cada pedido.',
                ),
              ),
            for (final order in _orders.where(
              (o) {
                if (o.total <= 0) return false;
                if (pendingIds.contains(o.id)) return false;
                if (_selectedFilter == 'TODOS') return true;
                if (_selectedFilter == 'DEVUELTO') return o.estado == OrderStatus.devuelto;
                if (_selectedFilter == 'PAGADO') return o.estado == OrderStatus.pagado || o.estado == OrderStatus.entregado;
                if (_selectedFilter == 'PENDIENTE_PAGO') return o.estado == OrderStatus.pendientePago;
                if (_selectedFilter == 'CANCELADO') return o.estado == OrderStatus.cancelado;
                return true;
              },
            ))
              _orderCard(order),
            if (_more)
              OutlinedButton(
                onPressed: _loadingMore ? null : _loadMore,
                child: Text(_loadingMore ? 'Cargando…' : 'Ver más pedidos'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _orderCard(Order order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
          // Responsive header with expanded title and status badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'Pedido ${order.codigoPublico}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusBadge(order.estado),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Tipo: ${order.tipoEntrega.displayName} · Canal: ${order.canal}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${order.items.length} prendas',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMutedStrong,
                  ),
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
          const SizedBox(height: 12),
          // Comprobante Oficial Button
          if (order.estado == OrderStatus.pendientePago)
            FilledButton.icon(
              icon: const Icon(Icons.credit_card),
              label: const Text('Pagar con tarjeta'),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => StripePaymentScreen(orderId: order.id),
                  ),
                );
                if (mounted) _loadOrders();
              },
            ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                side: const BorderSide(color: AppColors.ink, width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: AppColors.paper,
              ),
              onPressed: () => _showReceiptModal(order),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppSvg.raw(AppSvg.package, size: 14, color: AppColors.ink),
                  const SizedBox(width: 8),
                  const Text(
                    'Ver Comprobante Oficial',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (order.estado == OrderStatus.pagado || order.estado == OrderStatus.entregado) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  side: const BorderSide(color: AppColors.ink, width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: AppColors.paperDark,
                ),
                onPressed: () => _openExchangeSheet(order),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.swap_horiz, size: 16, color: AppColors.ink),
                    SizedBox(width: 8),
                    Text(
                      'Cambios o devoluciones',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (order.estado == OrderStatus.devuelto) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.dangerBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.assignment_return, size: 16, color: AppColors.danger),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Prenda devuelta · Reembolso registrado',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openExchangeSheet(Order order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExchangeSheet(
        order: order,
        orderService: _orderService,
        offline: context.read<OfflineService?>(),
        onConfirmed: _loadOrders,
      ),
    );
  }

  Widget _filterChip(String key, String label) {
    final active = _selectedFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.lime : AppColors.paper,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? AppColors.ink : AppColors.line,
            width: active ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: active ? FontWeight.w900 : FontWeight.w700,
            color: AppColors.ink,
          ),
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
    } else if (status == OrderStatus.devuelto) {
      bg = AppColors.dangerBg;
      fg = AppColors.danger;
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

// -----------------------------------------------------------------------------
// COMPROBANTE OFICIAL DE COMPRA (MODAL SHEET)
// -----------------------------------------------------------------------------
class _ReceiptModalSheet extends StatefulWidget {
  final int orderId;
  final Order initialOrder;

  const _ReceiptModalSheet({required this.orderId, required this.initialOrder});

  @override
  State<_ReceiptModalSheet> createState() => _ReceiptModalSheetState();
}

class _ReceiptModalSheetState extends State<_ReceiptModalSheet> {
  late final OrderService _orderService;
  bool _loading = true;
  Map<String, dynamic>? _receiptData;
  bool _downloading = false;
  String? _error;

  static num _parseNum(dynamic value, [num fallback = 0.0]) {
    if (value == null) return fallback;
    if (value is num) return value;
    if (value is String) return num.tryParse(value) ?? fallback;
    return fallback;
  }

  @override
  void initState() {
    super.initState();
    _fetchReceipt();
  }

  Future<void> _fetchReceipt() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _orderService.getOrderReceipt(widget.orderId);
      setState(() {
        _receiptData = data;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'No se pudo cargar el comprobante oficial en vivo.';
        _loading = false;
      });
    }
  }

  void _copyReceiptToClipboard() {
    final order = _receiptData?['order'] ?? {};
    final merchant = _receiptData?['empresa'] ?? {};
    final total = order['total'] ?? widget.initialOrder.total;
    final code = order['codigo_publico'] ?? widget.initialOrder.codigoPublico;
    final status = order['estado'] ?? widget.initialOrder.estado.displayName;

    final summary =
        '''
--- ${merchant['nombre'] ?? 'Comercio'} ---
Comprobante Oficial de Venta #DM-ORD-${widget.orderId.toString().padLeft(5, '0')}
${merchant['direccion'] ?? ''} ${merchant['telefono'] ?? ''}
Código: $code
Estado: $status
Total Cancelado: Bs $total BOB
Consulta las condiciones de cambios con la tienda. Documento no fiscal.
''';

    Clipboard.setData(ClipboardData(text: summary));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.ink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: const Text(
          'Datos del comprobante copiados al portapapeles',
          style: TextStyle(color: AppColors.lime, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderMap = _receiptData?['order'] as Map<String, dynamic>?;
    final sucursalMap = _receiptData?['sucursal'] as Map<String, dynamic>?;
    final merchantMap = _receiptData?['empresa'] as Map<String, dynamic>?;
    final clienteMap = _receiptData?['cliente'] as Map<String, dynamic>?;
    final itemsList = (_receiptData?['items'] as List?) ?? [];
    final paymentsList = (_receiptData?['payments'] as List?) ?? [];

    final total = _parseNum(orderMap?['total'], widget.initialOrder.total);
    final subtotal = _parseNum(
      orderMap?['subtotal'],
      widget.initialOrder.subtotal,
    );
    final deliveryCost = _parseNum(orderMap?['costo_envio'], 0.0);
    final discount = _parseNum(orderMap?['descuento'], 0.0);
    final statusStr =
        orderMap?['estado']?.toString() ??
        widget.initialOrder.estado.displayName;
    final publicCode =
        orderMap?['codigo_publico']?.toString() ??
        widget.initialOrder.codigoPublico;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.lineStrong,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header Toolbar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AppColors.ink,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      'DM',
                      style: TextStyle(
                        color: AppColors.lime,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Comprobante de compra',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        merchantMap?['nombre'] ?? 'Comercio',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Descargar PDF',
                  icon: const Icon(Icons.download_outlined),
                  onPressed: _downloading
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          setState(() => _downloading = true);
                          try {
                            final saved = await _orderService.downloadReceipt(
                              widget.orderId,
                            );
                            if (saved && mounted) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Comprobante guardado.'),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    e is ApiException
                                        ? e.message
                                        : 'No se pudo descargar el comprobante.',
                                  ),
                                ),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _downloading = false);
                          }
                        },
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 19, color: AppColors.ink),
                  tooltip: 'Copiar Comprobante',
                  onPressed: _copyReceiptToClipboard,
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: AppColors.ink),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Body Content
          Expanded(
            child: _loading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppColors.ink),
                        SizedBox(height: 14),
                        Text(
                          'Cargando comprobante oficial...',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  )
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.danger,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.ink,
                            ),
                            onPressed: _fetchReceipt,
                            child: const Text(
                              'Reintentar',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(18),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.line),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0610110F),
                            blurRadius: 16,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Brand & Legal Seal
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: AppColors.ink,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Center(
                                  child: Text(
                                    'DM',
                                    style: TextStyle(
                                      color: AppColors.lime,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      merchantMap?['nombre'] ?? 'Comercio',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.2,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                    const Text(
                                      'Comprobante de compra no fiscal',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                    Text(
                                      '${merchantMap?['direccion'] ?? ''} ${merchantMap?['telefono'] ?? ''}',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textMutedStrong,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Folio & Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.paperLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '#DM-ORD-${widget.orderId.toString().padLeft(5, '0')}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12.5,
                                    color: AppColors.ink,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.lime,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    statusStr.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Divider(),
                          const SizedBox(height: 10),

                          // Client & Branch Details
                          _buildDetailRow(
                            'CLIENTE:',
                            clienteMap?['nombre'] ?? 'Cliente Atelier',
                          ),
                          if (clienteMap?['email'] != null &&
                              clienteMap!['email'].isNotEmpty)
                            _buildDetailRow('EMAIL:', clienteMap['email']),
                          if (clienteMap?['telefono'] != null &&
                              clienteMap!['telefono'].isNotEmpty)
                            _buildDetailRow(
                              'TELÉFONO:',
                              clienteMap['telefono'],
                            ),
                          const SizedBox(height: 6),
                          _buildDetailRow(
                            'SUCURSAL:',
                            sucursalMap?['nombre'] ?? 'Sucursal no registrada',
                          ),
                          if (sucursalMap?['direccion'] != null)
                            _buildDetailRow(
                              'DIRECCIÓN:',
                              sucursalMap!['direccion'],
                            ),
                          const SizedBox(height: 6),
                          _buildDetailRow(
                            'MODALIDAD:',
                            orderMap?['tipo_entrega'] == 'RECOJO'
                                ? 'Retiro en Atelier'
                                : 'Envío a Domicilio',
                          ),
                          _buildDetailRow('UUID:', publicCode),

                          const SizedBox(height: 14),
                          const Divider(),
                          const SizedBox(height: 10),

                          // Prenda Items Table
                          const Text(
                            'PRENDAS ADQUIRIDAS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 8),

                          if (itemsList.isEmpty)
                            ...widget.initialOrder.items.map(
                              (it) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        it.nombre.isNotEmpty
                                            ? it.nombre
                                            : 'Item #${it.varianteId}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${it.cantidad}x  Bs ${it.precioUnitario.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            ...itemsList.map((item) {
                              final name = item['nombre'] ?? 'Prenda Atelier';
                              final qty = _parseNum(
                                item['cantidad'],
                                1,
                              ).toInt();
                              final unitPrice = _parseNum(
                                item['precio_unitario'],
                                0.0,
                              );
                              final sub = _parseNum(item['subtotal'], 0.0);
                              final variant =
                                  '${item['color'] ?? ""} ${item['talla'] ?? ""}'
                                      .trim();

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.ink,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Bs ${sub.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.ink,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      'SKU: ${item['sku'] ?? "DRP"} · ${variant.isNotEmpty ? variant : "Edición Limitada"} · $qty un. x Bs ${unitPrice.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),

                          const SizedBox(height: 14),
                          const Divider(),
                          const SizedBox(height: 10),

                          // Financials Breakdown
                          _buildPriceLine(
                            'Subtotal Prendas:',
                            'Bs ${subtotal.toStringAsFixed(2)}',
                          ),
                          _buildPriceLine(
                            'Costo de Entrega:',
                            deliveryCost > 0
                                ? 'Bs ${deliveryCost.toStringAsFixed(2)}'
                                : 'Gratis',
                          ),
                          if (discount > 0)
                            _buildPriceLine(
                              'Descuento Aplicado:',
                              '- Bs ${discount.toStringAsFixed(2)}',
                              isDiscount: true,
                            ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.ink,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'TOTAL CANCELADO:',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  'Bs ${total.toStringAsFixed(2)} BOB',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.lime,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Payment Details
                          if (paymentsList.isNotEmpty) ...[
                            Text(
                              'PAGO: ${paymentsList.first['metodo'] ?? "DIRECTO"} · Ref: ${paymentsList.first['referencia'] ?? publicCode}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMutedStrong,
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],

                          // QR Digital Security Seal
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.paperDark,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.line),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: AppColors.lineStrong,
                                    ),
                                  ),
                                  child: Center(
                                    child: AppSvg.raw(
                                      AppSvg.shield,
                                      size: 22,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'DOCUMENTO OFICIAL AUTÉNTICO',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.ink,
                                        ),
                                      ),
                                      const Text(
                                        'Comprobante verificado',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                      Text(
                                        'HASH: ${publicCode.length > 16 ? publicCode.substring(0, 16) : publicCode}...',
                                        style: const TextStyle(
                                          fontSize: 9,
                                          fontFamily: 'monospace',
                                          color: AppColors.textMutedStrong,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Policy Disclaimer
                          const Text(
                            'Conserva este comprobante. Consulta con la tienda las condiciones de cambios y garantías de tu compra. Documento no fiscal.',
                            style: TextStyle(
                              fontSize: 9.5,
                              color: AppColors.textMuted,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.textMutedStrong,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceLine(
    String label,
    String value, {
    bool isDiscount = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMutedStrong,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: isDiscount ? AppColors.danger : AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
