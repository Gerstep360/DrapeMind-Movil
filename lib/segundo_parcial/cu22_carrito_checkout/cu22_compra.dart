import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drapemind_mobile/core/core.dart';
import '../cu23_pagos/cu23_deferred_screen.dart';
import 'package:drapemind_mobile/segundo_parcial/cu23_pagos/cu23_pago_tarjeta.dart';
import '../cu24_pedidos/cu24_orders_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});
  @override
  State<CheckoutScreen> createState() => _CheckoutState();
}

class _CheckoutState extends State<CheckoutScreen> {
  final _api = ApiClient(), _orders = OrderService();
  final _coupon = TextEditingController();
  bool _loading = true, _busy = false;
  String? _error, _pending, _couponCode;
  double _fee = 0, _discount = 0;
  DeliveryType _delivery = DeliveryType.recojo;
  int? _branch, _address;
  List<Map<String, dynamic>> _branches = [];
  List<Address> _addresses = [];
  Order? _order;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _coupon.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await Future.wait([
        _api.get('/orders/checkout-options'),
        _api.get('/commerce/config'),
        AddressService().getMyAddresses(),
      ]);
      if (!mounted) return;
      final options = result[0] as Map;
      setState(() {
        _branches = (options['sucursales'] as List)
            .map((v) => Map<String, dynamic>.from(v))
            .toList();
        _branch = _branches
            .where((b) => b['disponible'] == true)
            .firstOrNull?['id'];
        _pending = options['compra_pendiente'];
        _fee = double.parse((result[1] as Map)['costo_delivery'].toString());
        _addresses = result[2] as List<Address>;
        _address = _addresses.firstOrNull?.id;
        if (options['vacio'] == true) {
          _error =
              'Tu carrito ya cambió o se confirmó. Revisa tus pedidos y vuelve a elegir las prendas.';
        } else if (_pending != null) {
          _error =
              'Estas prendas ya tienen una compra pendiente. Revisa su pago antes de crear otra.';
        } else if (_branch == null) {
          _error =
              'Ninguna sucursal tiene todas las cantidades solicitadas. Ajusta tu carrito para continuar.';
        }
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ApiException
              ? e.message
              : 'No pudimos comprobar tu compra. Recupera conexión y reintenta.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _applyCoupon() async {
    final cart = context.read<CartService>().cart;
    if (cart == null || _coupon.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final data = await _orders.validatePromotion(
        code: _coupon.text,
        subtotal: cart.subtotal,
        productIds: cart.items.map((i) => i.productoId).toList(),
      );
      if (!mounted) return;
      if (data['valido'] != true) {
        throw ApiException(
          data['mensaje'] ?? 'Este cupón no se aplica a tu compra.',
        );
      }
      setState(() {
        _couponCode = data['codigo'];
        _discount = double.parse(data['descuento_calculado'].toString());
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is ApiException ? e.message : 'No pudimos validar el cupón.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pay() async {
    if (_busy || _loading || _error != null) return;
    if (_delivery == DeliveryType.recojo && _branch == null ||
        _delivery == DeliveryType.delivery && _address == null) {
      setState(
        () => _error =
            'Selecciona la sucursal o una dirección guardada para continuar.',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final order =
          _order ??
          await _orders.checkout(
            CheckoutRequest(
              tipoEntrega: _delivery,
              sucursalId: _delivery == DeliveryType.recojo ? _branch : null,
              direccionId: _delivery == DeliveryType.delivery ? _address : null,
              costoEnvio: _delivery == DeliveryType.delivery ? _fee : 0,
              codigoPromocion: _couponCode,
            ),
          );
      if (!mounted) return;
      setState(() => _order = order);
      await context.read<CartService>().getCart();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => StripePaymentScreen(orderId: order.id),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ApiException
              ? e.message
              : 'No pudimos preparar la compra. Stripe debe confirmar cualquier cobro.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>().cart;
    final subtotal = _order?.subtotal ?? cart?.subtotal ?? 0;
    final total =
        _order?.total ??
        (subtotal - _discount).clamp(0, double.infinity) +
            (_delivery == DeliveryType.delivery ? _fee : 0);
    return Scaffold(
      appBar: AppBar(title: const Text('Completar compra')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            _order == null
                ? 'Tus prendas, a un paso'
                : 'Tu pedido está preparado',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          if (_order != null) ...[
            Text('Pedido ${_order!.codigoPublico}'),
            const Text(
              'El pago se confirma después de la respuesta de Stripe.',
            ),
          ],
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: Colors.red)),
            TextButton(
              onPressed: _loading ? null : _load,
              child: const Text('Actualizar disponibilidad'),
            ),
            if (_pending != null)
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const DeferredPurchasesScreen(),
                  ),
                ),
                child: const Text('Revisar compra pendiente'),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const OrdersScreen()),
              ),
              child: const Text('Ver mis pedidos'),
            ),
          ],
          if (_order == null) ...[
            for (final item in cart?.items ?? <CartItem>[])
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.nombre),
                subtitle: Text(
                  '${item.talla} · ${item.color} · ${item.cantidad} unidades',
                ),
                trailing: Text('Bs ${item.subtotal.toStringAsFixed(2)}'),
              ),
            const Divider(height: 32),
            DropdownButtonFormField<DeliveryType>(
              value: _delivery,
              decoration: const InputDecoration(
                labelText: '¿Cómo recibirás tus prendas?',
              ),
              items: const [
                DropdownMenuItem(
                  value: DeliveryType.recojo,
                  child: Text('Recoger en tienda'),
                ),
                DropdownMenuItem(
                  value: DeliveryType.delivery,
                  child: Text('Entrega a domicilio'),
                ),
              ],
              onChanged: _busy
                  ? null
                  : (v) {
                      if (v != null) setState(() => _delivery = v);
                    },
            ),
            const SizedBox(height: 16),
            if (_delivery == DeliveryType.recojo)
              DropdownButtonFormField<int>(
                value: _branch,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Sucursal de recojo',
                ),
                items: _branches
                    .map(
                      (b) => DropdownMenuItem<int>(
                        value: b['id'],
                        enabled: b['disponible'] == true,
                        child: Text(
                          '${b['nombre']}${b['disponible'] == true ? '' : ' · Cantidad insuficiente'}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _busy ? null : (v) => setState(() => _branch = v),
              ),
            if (_delivery == DeliveryType.delivery)
              DropdownButtonFormField<int>(
                value: _address,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Dirección guardada',
                ),
                items: _addresses
                    .map(
                      (a) => DropdownMenuItem(
                        value: a.id,
                        child: Text(
                          '${a.alias} · ${a.ciudad}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _busy ? null : (v) => setState(() => _address = v),
              ),
            if (_delivery == DeliveryType.delivery && _addresses.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Agrega una dirección desde Mi cuenta antes de confirmar el envío.',
                ),
              ),
            const SizedBox(height: 24),
            TextField(
              controller: _coupon,
              decoration: InputDecoration(
                labelText: 'Cupón (opcional)',
                suffixIcon: TextButton(
                  onPressed: _busy ? null : _applyCoupon,
                  child: const Text('Aplicar'),
                ),
              ),
            ),
            if (_couponCode != null)
              Text('$_couponCode · Ahorras Bs ${_discount.toStringAsFixed(2)}'),
          ],
          const Divider(height: 32),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.credit_card),
            title: Text('Pago seguro con Stripe'),
            subtitle: Text(
              'Revisa el importe y autoriza el pago. Stripe procesa los datos de tu tarjeta.',
            ),
          ),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 24,
            children: [
              const Text('Total de tu compra'),
              Text(
                'Bs ${total.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
          ),
          if (_delivery == DeliveryType.delivery)
            Text('Incluye Bs ${_fee.toStringAsFixed(2)} de envío.'),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy || _loading || _error != null ? null : _pay,
            child: Text(_busy ? 'Preparando…' : 'Continuar con Stripe'),
          ),
          if (context.read<AuthService>().currentUser?.rol.toServerString() ==
              'CLIENTE')
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DeferredPurchasesScreen(),
                ),
              ),
              child: const Text('Guardar para cuando vuelva la conexión'),
            ),
        ],
      ),
    );
  }
}
