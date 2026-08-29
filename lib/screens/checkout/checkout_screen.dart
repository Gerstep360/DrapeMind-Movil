import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/core.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_svg.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _orderService = OrderService();
  final _paymentService = PaymentService();
  final _addressService = AddressService();

  DeliveryType _deliveryType = DeliveryType.recojo;
  PaymentMethod _paymentMethod = PaymentMethod.qr;

  List<Address> _addresses = [];
  int? _selectedAddressId;
  bool _isLoading = false;
  Order? _completedOrder;
  Payment? _activePayment;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    try {
      final list = await _addressService.getMyAddresses();
      setState(() {
        _addresses = list;
        if (list.isNotEmpty) {
          _selectedAddressId = list.first.id;
        }
      });
    } catch (_) {}
  }

  Future<void> _processCheckout() async {
    setState(() => _isLoading = true);

    try {
      final order = await _orderService.checkout(
        CheckoutRequest(
          tipoEntrega: _deliveryType,
          direccionId: _deliveryType == DeliveryType.delivery
              ? _selectedAddressId
              : null,
          costoEnvio: _deliveryType == DeliveryType.delivery ? 25.0 : 0.0,
        ),
      );

      final payment = await _paymentService.initiatePayment(
        PaymentCreate(pedidoId: order.id, metodo: _paymentMethod),
        idempotencyKey: 'mobile-order-${order.id}-${_paymentMethod.name}',
      );

      // Refresh cart
      if (mounted) {
        context.read<CartService>().getCart();
      }

      setState(() {
        _completedOrder = order;
        _activePayment = payment;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('No se pudo procesar la compra.'),
          ),
        );
      }
    }
  }

  Future<void> _confirmMockPayment() async {
    if (_activePayment == null) return;
    setState(() => _isLoading = true);

    try {
      final updated = await _paymentService.mockConfirmPayment(
        _activePayment!.id,
      );
      setState(() {
        _activePayment = updated;
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.forest,
            content: Text('Pago aprobado con éxito'),
          ),
        );
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>().cart;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('FINALIZAR COMPRA')),
      body: _completedOrder != null
          ? _buildSuccessView()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // DELIVERY TYPE
                  _buildSectionHeader('TIPO DE ENTREGA', AppSvg.truck),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: [
                        RadioListTile<DeliveryType>(
                          value: DeliveryType.recojo,
                          groupValue: _deliveryType,
                          title: const Text(
                            'Recojo en Showroom Atelier',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: const Text(
                            'Gratis · Prueba tus prendas antes de retirar',
                            style: TextStyle(fontSize: 11),
                          ),
                          onChanged: (v) => setState(() => _deliveryType = v!),
                        ),
                        const Divider(),
                        RadioListTile<DeliveryType>(
                          value: DeliveryType.delivery,
                          groupValue: _deliveryType,
                          title: const Text(
                            'Envío a Domicilio',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: const Text(
                            'Costo: Bs 25.00 · Entrega en 24-48 horas',
                            style: TextStyle(fontSize: 11),
                          ),
                          onChanged: (v) => setState(() => _deliveryType = v!),
                        ),
                        if (_deliveryType == DeliveryType.delivery &&
                            _addresses.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: DropdownButtonFormField<int>(
                              value: _selectedAddressId,
                              decoration: const InputDecoration(
                                labelText: 'Dirección de Entrega',
                                isDense: true,
                              ),
                              items: _addresses.map((a) {
                                return DropdownMenuItem(
                                  value: a.id,
                                  child: Text(
                                    '${a.alias}: ${a.direccion}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                );
                              }).toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedAddressId = v),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // PAYMENT METHOD
                  _buildSectionHeader('MÉTODO DE PAGO', AppSvg.card),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: [
                        RadioListTile<PaymentMethod>(
                          value: PaymentMethod.qr,
                          groupValue: _paymentMethod,
                          title: Row(
                            children: [
                              AppSvg.raw(
                                AppSvg.qr,
                                size: 16,
                                color: AppColors.forest,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Pago Simple QR',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          subtitle: const Text(
                            'Genera código QR compatible con cualquier banco',
                            style: TextStyle(fontSize: 11),
                          ),
                          onChanged: (v) => setState(() => _paymentMethod = v!),
                        ),
                        const Divider(),
                        RadioListTile<PaymentMethod>(
                          value: PaymentMethod.tarjeta,
                          groupValue: _paymentMethod,
                          title: Row(
                            children: [
                              AppSvg.raw(
                                AppSvg.card,
                                size: 16,
                                color: AppColors.forest,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Tarjeta de Débito / Crédito',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          onChanged: (v) => setState(() => _paymentMethod = v!),
                        ),
                        const Divider(),
                        RadioListTile<PaymentMethod>(
                          value: PaymentMethod.efectivo,
                          groupValue: _paymentMethod,
                          title: Row(
                            children: [
                              AppSvg.raw(
                                AppSvg.store,
                                size: 16,
                                color: AppColors.forest,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Efectivo en Showroom',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          onChanged: (v) => setState(() => _paymentMethod = v!),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // SUMMARY
                  _buildSectionHeader('RESUMEN DE PAGO', AppSvg.package),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Subtotal prendas:',
                                style: TextStyle(fontSize: 12.5),
                              ),
                              Text(
                                'Bs ${(cart?.subtotal ?? 0).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Costo de envío:',
                                style: TextStyle(fontSize: 12.5),
                              ),
                              Text(
                                _deliveryType == DeliveryType.delivery
                                    ? 'Bs 25.00'
                                    : 'Bs 0.00',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total a Pagar:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                'Bs ${((cart?.subtotal ?? 0) + (_deliveryType == DeliveryType.delivery ? 25.0 : 0.0)).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                  color: AppColors.forest,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: _isLoading ? null : _processCheckout,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Confirmar y Generar Orden'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, String svgIcon) {
    return Row(
      children: [
        AppSvg.raw(svgIcon, size: 16, color: AppColors.forest),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
            color: AppColors.forestDark,
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    final isPaid = _activePayment?.isPaid ?? false;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.forest,
                  shape: BoxShape.circle,
                ),
                child: AppSvg.raw(
                  isPaid ? AppSvg.check : AppSvg.qr,
                  size: 36,
                  color: AppColors.acid,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isPaid ? '¡PAGO CONFIRMADO!' : 'ORDEN REGISTRADA',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'serif',
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.forestDark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Código de Pedido: ${_completedOrder?.codigoPublico}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.forest,
                ),
              ),
              const SizedBox(height: 18),

              // QR MOCK / PAYMENT BOX
              if (!isPaid && _paymentMethod == PaymentMethod.qr) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  color: AppColors.white,
                  child: Column(
                    children: [
                      Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          color: AppColors.paperLight,
                          border: Border.all(color: AppColors.lineStrong),
                        ),
                        child: Center(
                          child: AppSvg.raw(
                            AppSvg.qr,
                            size: 100,
                            color: AppColors.forest,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Total a pagar: Bs ${_completedOrder?.total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _isLoading ? null : _confirmMockPayment,
                        child: const Text('Simular Pago Exitoso (Demo QR)'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Volver al Atelier'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
