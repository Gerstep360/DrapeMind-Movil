import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;
import 'package:drapemind_mobile/paquetes/carrito_pedidos_pagos/datos/servicios/payment_service.dart';
import 'package:drapemind_mobile/paquetes/carrito_pedidos_pagos/dominio/modelos/payment_models.dart';
import 'package:drapemind_mobile/core/theme/app_colors.dart';

class StripePaymentScreen extends StatefulWidget {
  final int orderId;
  const StripePaymentScreen({super.key, required this.orderId});

  @override
  State<StripePaymentScreen> createState() => _StripePaymentScreenState();
}

class _StripePaymentScreenState extends State<StripePaymentScreen> {
  final _service = PaymentService();
  Payment? _payment;
  int? _paymentId;
  bool _busy = false;
  bool _isSandbox = true;
  String? _error;
  String? _status;
  Timer? _pollTimer;

  Map<String, dynamic>? _intentData;

  @override
  void initState() {
    super.initState();
    _initPayment();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _initPayment() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final intent = await _service.stripeIntent(widget.orderId);
      if (!mounted) return;

      _intentData = intent;
      _paymentId = intent['payment_id'] as int?;

      final pubKey = (intent['publishable_key'] as String? ?? '').trim();
      final isRealKey =
          pubKey.startsWith('pk_test_') || pubKey.startsWith('pk_live_');
      final isSandboxMode = intent['sandbox'] == true || !isRealKey;

      setState(() {
        _isSandbox = isSandboxMode;
        _busy = false;
      });

      // Check current status
      await _check();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSandbox = true;
          _busy = false;
        });
      }
    }
  }

  Future<void> _paySandbox() async {
    if (_busy || _paymentId == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _status = 'Confirmando con Stripe Sandbox...';
    });

    try {
      final updated = await _service.confirmStripeSandbox(_paymentId!);
      if (!mounted) return;

      setState(() {
        _payment = updated;
        _busy = false;
        _status = '¡Pago aprobado con éxito!';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.forest,
          content: Text('¡Pago con Tarjeta aprobado en tiempo real!'),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'No se pudo confirmar el pago en sandbox. Reintenta.';
        });
      }
    }
  }

  Future<void> _payRealStripe() async {
    if (_busy || _intentData == null) return;
    _pollTimer?.cancel();
    setState(() {
      _busy = true;
      _error = null;
      _status = 'Conectando con pasarela Stripe...';
    });

    try {
      final pubKey = _intentData!['publishable_key'] as String;
      stripe.Stripe.publishableKey = pubKey;
      stripe.Stripe.urlScheme = 'drapemind';
      await stripe.Stripe.instance.applySettings();

      if (!mounted) return;
      await stripe.Stripe.instance.initPaymentSheet(
        paymentSheetParameters: stripe.SetupPaymentSheetParameters(
          paymentIntentClientSecret: _intentData!['client_secret'] as String,
          merchantDisplayName: 'DrapeMind Atelier',
          returnURL: 'drapemind://stripe-redirect',
          style: ThemeMode.dark,
        ),
      );

      if (!mounted) return;
      await stripe.Stripe.instance.presentPaymentSheet();

      if (mounted) {
        setState(() => _status = 'Verificando confirmación del pago...');
        await _poll(0);
      }
    } on stripe.StripeException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.error.code == stripe.FailureCode.Canceled
              ? 'Pago cancelado. Tu pedido permanece reservado.'
              : 'La tarjeta no pudo ser procesada. Revisa los datos o reintenta.';
        });
      }
    } catch (_) {
      if (mounted) {
        // Fallback to sandbox if SDK setup fails
        setState(() => _isSandbox = true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _poll(int attempt) async {
    if (_paymentId == null || !mounted) return;
    final payment = await _service.getPayment(_paymentId!);
    if (!mounted) return;

    setState(() => _payment = payment);
    if (!payment.isPaid &&
        payment.estado == PaymentStatus.pendiente &&
        attempt < 9) {
      _pollTimer = Timer(const Duration(seconds: 2), () {
        _poll(attempt + 1).catchError((_) {
          if (mounted) {
            setState(
              () => _error = 'Confirmación pendiente. Revisa Mis compras.',
            );
          }
        });
      });
    }
  }

  Future<void> _check() async {
    if (_paymentId == null) return;
    try {
      final payment = await _service.getPayment(_paymentId!);
      if (mounted) setState(() => _payment = payment);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isApproved =
        _payment?.isPaid == true || _payment?.estado == PaymentStatus.aprobado;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: const Text('Pasarela Stripe'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // HEADER ICON & TITLE
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF635BFF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'stripe',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Pago Seguro',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pedido #${widget.orderId}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.ink.withValues(alpha: 0.6),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // APPROVED BANNER
                  if (isApproved) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2D24),
                        border: Border.all(
                          color: const Color(0xFF4ADE80).withValues(alpha: 0.4),
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF4ADE80),
                            size: 48,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            '¡Pago Aprobado con Éxito!',
                            style: TextStyle(
                              color: Color(0xFF4ADE80),
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'La transacción ha sido registrada y confirmada en DrapeMind.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.ink,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Volver a Mis Pedidos',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ] else ...[
                    // VIRTUAL CREDIT CARD (SANDBOX OR REAL)
                    _buildCreditCardPreview(),
                    const SizedBox(height: 20),

                    // STATUS OR ERROR
                    if (_status != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _status!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.1),
                          border: Border.all(
                            color: AppColors.danger.withValues(alpha: 0.3),
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: AppColors.danger,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: AppColors.danger,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // PAY BUTTON
                    FilledButton(
                      onPressed: _busy
                          ? null
                          : (_isSandbox ? _paySandbox : _payRealStripe),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.lime,
                        foregroundColor: AppColors.ink,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.ink,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.credit_card_rounded, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  _isSandbox
                                      ? 'Pagar con Tarjeta (Stripe Sandbox)'
                                      : 'Pagar con Tarjeta (Stripe)',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 12),

                    TextButton(
                      onPressed: _busy ? null : _check,
                      child: const Text('Consultar estado del pago'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreditCardPreview() {
    return Container(
      height: 210,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E222D), Color(0xFF101217)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // CHIP
              Container(
                width: 40,
                height: 30,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE5BE01), Color(0xFFC49E00)],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Container(
                    width: 32,
                    height: 1,
                    color: Colors.black.withValues(alpha: 0.2),
                  ),
                ),
              ),
              // BADGE
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _isSandbox
                      ? AppColors.lime.withValues(alpha: 0.15)
                      : const Color(0xFF22C55E).withValues(alpha: 0.15),
                  border: Border.all(
                    color: _isSandbox
                        ? AppColors.lime.withValues(alpha: 0.4)
                        : const Color(0xFF22C55E).withValues(alpha: 0.4),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _isSandbox ? 'SANDBOX TEST' : 'ENCRIPTADO 256-BIT',
                  style: TextStyle(
                    color: _isSandbox
                        ? AppColors.lime
                        : const Color(0xFF4ADE80),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          // CARD NUMBER
          const Text(
            '4242  ••••  ••••  4242',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              letterSpacing: 3,
              fontFamily: 'Courier',
              fontWeight: FontWeight.bold,
            ),
          ),
          // CARD FOOTER
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TITULAR',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 9,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'CLIENTE DRAPEMIND',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'EXPIRA',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 9,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '12/28',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const Text(
                'VISA',
                style: TextStyle(
                  color: AppColors.lime,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
