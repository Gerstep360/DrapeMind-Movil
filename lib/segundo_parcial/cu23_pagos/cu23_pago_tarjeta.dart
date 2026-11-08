import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;
import 'package:drapemind_mobile/core/core.dart';

class StripePaymentScreen extends StatefulWidget {
  final int orderId;
  const StripePaymentScreen({super.key, required this.orderId});
  @override
  State<StripePaymentScreen> createState() => _StripePaymentState();
}

class _StripePaymentState extends State<StripePaymentScreen> {
  final service = PaymentService();
  Map<String, dynamic>? intent;
  Payment? payment;
  String? error;
  bool busy = true;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    prepare();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> prepare() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (await service.provider() != 'stripe') {
        throw ApiException(
          'Stripe no está disponible en esta tienda. Tu pedido conserva su estado.',
        );
      }
      final data = await service.stripeIntent(widget.orderId);
      if (data['sandbox'] == true) {
        throw ApiException(
          'La tienda debe configurar Stripe para recibir pagos.',
        );
      }
      if (!mounted) return;
      setState(() => intent = data);
      await check();
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is ApiException
              ? e.message
              : 'No pudimos preparar el pago. Revisa la conexión y reintenta.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> check() async {
    if (intent == null) return;
    try {
      final current = await service.getPayment(intent!['payment_id']);
      if (mounted) setState(() => payment = current);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is ApiException
              ? e.message
              : 'La confirmación sigue pendiente. Consulta este mismo pedido.',
        );
      }
    }
  }

  Future<void> pay() async {
    if (busy || intent == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    final merchant =
        context.read<AuthService>().currentUser?.tenantName ?? 'Tienda';
    try {
      stripe.Stripe.publishableKey = intent!['publishable_key'];
      stripe.Stripe.urlScheme = 'drapemind';
      await stripe.Stripe.instance.applySettings();
      await stripe.Stripe.instance.initPaymentSheet(
        paymentSheetParameters: stripe.SetupPaymentSheetParameters(
          paymentIntentClientSecret: intent!['client_secret'],
          merchantDisplayName: merchant,
          returnURL: 'drapemind://stripe-redirect',
          style: ThemeMode.light,
        ),
      );
      if (!mounted) return;
      await stripe.Stripe.instance.presentPaymentSheet();
      await check();
      var count = 0;
      timer?.cancel();
      timer = Timer.periodic(const Duration(seconds: 2), (_) {
        count++;
        if (!mounted || payment?.isPaid == true || count > 15) {
          timer?.cancel();
          return;
        }
        check();
      });
    } on stripe.StripeException catch (e) {
      if (mounted) {
        setState(
          () => error = e.error.code == stripe.FailureCode.Canceled
              ? 'No autorizaste el pago. Puedes continuar después desde este pedido.'
              : 'Stripe no pudo completar el pago. Revisa tu tarjeta.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is ApiException
              ? e.message
              : 'No pudimos abrir Stripe. Consulta este mismo pedido antes de intentar otra compra.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pago seguro')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(Icons.credit_card, size: 42),
        const SizedBox(height: 20),
        Text(
          'Tu compra, con Stripe',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        Text('Pedido #${widget.orderId}'),
        const SizedBox(height: 20),
        if (intent != null)
          Text(
            'Bs ${(double.parse(intent!['amount'].toString()) / 100).toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
        const Text(
          'Autoriza el importe en la pantalla segura de Stripe. La tienda confirmará el pago desde el servidor.',
        ),
        const SizedBox(height: 24),
        if (busy) const Center(child: CircularProgressIndicator()),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(error!, style: const TextStyle(color: Colors.red)),
          ),
        if (payment?.isPaid == true) ...[
          const ListTile(
            leading: Icon(Icons.check_circle, color: Colors.green),
            title: Text('Pago confirmado'),
            subtitle: Text('Tu pedido ya está registrado.'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Listo'),
          ),
        ] else ...[
          FilledButton(
            onPressed: busy
                ? null
                : intent == null
                ? prepare
                : pay,
            child: Text(
              intent == null
                  ? 'Reintentar conexión'
                  : 'Autorizar pago con Stripe',
            ),
          ),
          TextButton(
            onPressed: busy ? null : check,
            child: const Text('Consultar estado'),
          ),
        ],
      ],
    ),
  );
}
