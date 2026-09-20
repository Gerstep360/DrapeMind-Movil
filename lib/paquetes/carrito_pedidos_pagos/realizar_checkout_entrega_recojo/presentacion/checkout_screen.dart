import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drapemind_mobile/core/core.dart';
import 'package:drapemind_mobile/core/theme/app_colors.dart';
import 'package:drapemind_mobile/core/theme/app_svg.dart';
import 'package:drapemind_mobile/paquetes/carrito_pedidos_pagos/procesar_confirmar_pago_electronico/presentacion/stripe_payment_screen.dart';

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
  bool _stripeEnabled = false;
  Order? _completedOrder;
  Payment? _activePayment;

  // CU-36: Promociones y Cupones
  final _couponController = TextEditingController();
  bool _validatingCoupon = false;
  String? _appliedCouponCode;
  double _appliedDiscount = 0.0;
  String? _couponFeedback;
  bool _couponValid = false;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
    _paymentService
        .provider()
        .then((value) {
          if (mounted) {
            setState(() {
              _stripeEnabled = value == 'stripe';
              if (_stripeEnabled) _paymentMethod = PaymentMethod.tarjeta;
            });
          }
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _loadAddresses() async {
    try {
      final list = await _addressService.getMyAddresses();
      if (!mounted) return;
      setState(() {
        _addresses = list;
        if (list.isNotEmpty) {
          _selectedAddressId = list.first.id;
        }
      });
    } catch (_) {}
  }

  Future<void> _applyCoupon(double subtotal, List<int> productIds) async {
    final code = _couponController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() {
      _validatingCoupon = true;
      _couponFeedback = null;
    });

    try {
      final res = await _orderService.validatePromotion(
        code: code,
        subtotal: subtotal,
        productIds: productIds,
      );

      final isValid = res['valido'] == true;
      final discount = (res['descuento_calculado'] as num?)?.toDouble() ?? 0.0;
      final msg = res['mensaje'] as String? ?? (isValid ? 'Cupón aplicado con éxito.' : 'Cupón no aplicable.');

      if (!mounted) return;
      setState(() {
        _couponValid = isValid;
        _couponFeedback = msg;
        if (isValid) {
          _appliedCouponCode = res['codigo'] as String? ?? code;
          _appliedDiscount = discount;
        } else {
          _appliedCouponCode = null;
          _appliedDiscount = 0.0;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _couponValid = false;
        _couponFeedback = 'No se pudo conectar para validar el cupón.';
        _appliedCouponCode = null;
        _appliedDiscount = 0.0;
      });
    } finally {
      if (mounted) setState(() => _validatingCoupon = false);
    }
  }

  void _removeCoupon() {
    setState(() {
      _couponController.clear();
      _appliedCouponCode = null;
      _appliedDiscount = 0.0;
      _couponFeedback = null;
      _couponValid = false;
    });
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
          codigoPromocion: _appliedCouponCode,
        ),
      );

      if (!mounted) return;
      setState(() => _completedOrder = order);
      context.read<CartService>().getCart();
      if (_stripeEnabled && _paymentMethod == PaymentMethod.tarjeta) {
        setState(() => _isLoading = false);
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => StripePaymentScreen(orderId: order.id),
          ),
        );
        return;
      }
      final payment = await _paymentService.initiatePayment(
        PaymentCreate(pedidoId: order.id, metodo: _paymentMethod),
        idempotencyKey: 'mobile-order-${order.id}-${_paymentMethod.name}',
      );

      // Refresh cart
      if (mounted) {
        context.read<CartService>().getCart();
      }

      if (!mounted) return;
      setState(() {
        _completedOrder = order;
        _activePayment = payment;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
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

  Future<void> _refreshPayment() async {
    if (_activePayment == null || _isLoading) return;
    setState(() => _isLoading = true);
    try {
      final updated = await _paymentService.getPayment(_activePayment!.id);
      if (!mounted) return;
      setState(() => _activePayment = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Estado registrado: ${updated.estado.displayName}'),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo consultar el pago. Reintenta.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>().cart;

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
            const Text(
              'Finalizar Compra',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      ),
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
                        if (!_stripeEnabled)
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
                              'La disponibilidad depende de la pasarela configurada',
                              style: TextStyle(fontSize: 11),
                            ),
                            onChanged: (v) =>
                                setState(() => _paymentMethod = v!),
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

                  // CUPON O PROMOCION
                  _buildSectionHeader('CUPÓN O PROMOCIÓN', AppSvg.sparkle),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_appliedCouponCode != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.acid.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.forest, width: 1.2),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.confirmation_num_outlined, color: AppColors.forest, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'CUPÓN: $_appliedCouponCode',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 12.5,
                                            color: AppColors.forestDark,
                                          ),
                                        ),
                                        Text(
                                          'Descuento: -Bs ${_appliedDiscount.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.forest,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _removeCoupon,
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      foregroundColor: AppColors.danger,
                                    ),
                                    child: const Text('Quitar', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _couponController,
                                    textCapitalization: TextCapitalization.characters,
                                    decoration: const InputDecoration(
                                      hintText: 'Ingresa código (ej. ALTAIR15)',
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: _validatingCoupon
                                      ? null
                                      : () {
                                          final sub = cart?.subtotal ?? 0.0;
                                          final pIds = cart?.items.map((it) => it.productoId).toList() ?? [];
                                          _applyCoupon(sub, pIds);
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.ink,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  ),
                                  child: _validatingCoupon
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Text('Aplicar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                                ),
                              ],
                            ),
                          ],
                          if (_couponFeedback != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              _couponFeedback!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _couponValid ? AppColors.forest : AppColors.danger,
                              ),
                            ),
                          ],
                        ],
                      ),
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
                          if (_appliedDiscount > 0) ...[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Descuento Cupón:',
                                  style: TextStyle(fontSize: 12.5, color: AppColors.forest, fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  '-Bs ${_appliedDiscount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: AppColors.forest,
                                  ),
                                ),
                              ],
                            ),
                          ],
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
                                'Bs ${(((cart?.subtotal ?? 0) - _appliedDiscount + (_deliveryType == DeliveryType.delivery ? 25.0 : 0.0)).clamp(0.0, double.infinity)).toStringAsFixed(2)}',
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
              if (!isPaid && _stripeEnabled)
                TextButton.icon(
                  icon: const Icon(Icons.credit_card),
                  label: const Text('Pagar con tarjeta'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          StripePaymentScreen(orderId: _completedOrder!.id),
                    ),
                  ),
                ),
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
                      const Text(
                        'Vista de demostración. Este icono no es un QR bancario.',
                        textAlign: TextAlign.center,
                      ),
                      if (_activePayment?.proveedor == 'MOCK')
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
              if (_activePayment != null && !isPaid)
                OutlinedButton(
                  onPressed: _isLoading ? null : _refreshPayment,
                  child: Text(
                    _isLoading ? 'Consultando…' : 'Consultar estado del pago',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
