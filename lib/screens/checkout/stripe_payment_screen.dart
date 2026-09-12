import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;
import '../../core/services/payment_service.dart';
import '../../core/models/payment_models.dart';
import '../../core/theme/app_colors.dart';

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
  String? _error;
  Timer? _pollTimer;

  Future<void> _pay() async {
    if (_busy) return;
    _pollTimer?.cancel();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final intent = await _service.stripeIntent(widget.orderId);
      if (!mounted) return;
      _paymentId = intent['payment_id'] as int;
      // Only the public key and one intent's client_secret leave the backend.
      stripe.Stripe.publishableKey = intent['publishable_key'] as String;
      stripe.Stripe.urlScheme = 'drapemind';
      await stripe.Stripe.instance.applySettings();
      if (!mounted) return;
      await stripe.Stripe.instance.initPaymentSheet(
        paymentSheetParameters: stripe.SetupPaymentSheetParameters(
          paymentIntentClientSecret: intent['client_secret'] as String,
          merchantDisplayName: 'DrapeMind',
          returnURL: 'drapemind://stripe-redirect',
          style: ThemeMode.light,
        ),
      );
      if (!mounted) return;
      await stripe.Stripe.instance.presentPaymentSheet();
      // SDK completion is not proof of fulfillment: only the webhook can approve.
      if (mounted) await _poll(0);
    } on stripe.StripeException catch (e) {
      if (mounted) {
        setState(
          () => _error = e.error.code == stripe.FailureCode.Canceled
              ? 'Pago cancelado. Tu pedido permanece disponible.'
              : 'La tarjeta no se pudo confirmar. Consulta el estado antes de reintentar.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No se pudo preparar o consultar Stripe. No repitas la compra: reintenta este mismo pedido.',
        );
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
              () => _error =
                  'Confirmación pendiente. Consulta el estado desde Mis compras.',
            );
          }
        });
      });
    }
  }

  Future<void> _check() async {
    if (_busy) return;
    _pollTimer?.cancel();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final payments = await _service.getOrderPayments(widget.orderId);
      if (!mounted) return;
      final matches = payments.where((p) => p.proveedor == 'STRIPE').toList();
      if (matches.isNotEmpty) {
        setState(() {
          _payment = matches.first;
          _paymentId = matches.first.id;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo consultar el estado del pago.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.paper,
    appBar: AppBar(title: const Text('Pago seguro')),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 48,
                  color: AppColors.ink,
                ),
                const SizedBox(height: 20),
                Text(
                  'Pedido #${widget.orderId}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Revisa el importe y confirma tu tarjeta en Stripe. Tus datos bancarios no se guardan en DrapeMind.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (_payment != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _payment!.isPaid
                          ? 'Pago confirmado por el servidor'
                          : 'Estado registrado: ${_payment!.estado.displayName}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ),
                if (_payment?.isPaid != true)
                  FilledButton(
                    onPressed: _busy ? null : _pay,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.lime,
                      foregroundColor: AppColors.ink,
                    ),
                    child: Text(_busy ? 'Procesando…' : 'Continuar con Stripe'),
                  ),
                TextButton(
                  onPressed: _busy ? null : _check,
                  child: const Text('Consultar estado del pago'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Si la confirmación tarda, vuelve a Mis compras. No necesitas generar otro pedido.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
