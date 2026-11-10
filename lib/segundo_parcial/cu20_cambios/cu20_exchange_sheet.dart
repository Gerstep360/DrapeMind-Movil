import 'package:flutter/material.dart';
import '../../core/config/api_config.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../compartido/componentes/productos/dm_product_image.dart';
import '../cu13_catalogo_offline/cu13_offline_service.dart';
import '../cu23_pagos/cu23_deferred_store.dart';
import '../cu23_pagos/cu23_pago_tarjeta.dart';
import '../cu24_pedidos/cu24_order_models.dart';
import '../cu24_pedidos/cu24_order_service.dart';
import 'cu20_exchange_service.dart';

class ExchangeSheet extends StatefulWidget {
  final Order order;
  final OrderService orderService;
  final OfflineService? offline;
  final VoidCallback onConfirmed;
  final ExchangeOperation? operation;
  final Widget Function(int orderId)? paymentBuilder;
  const ExchangeSheet({
    super.key,
    required this.order,
    required this.orderService,
    this.offline,
    required this.onConfirmed,
    this.operation,
    this.paymentBuilder,
  });
  @override
  State<ExchangeSheet> createState() => _ExchangeState();
}

class _ExchangeState extends State<ExchangeSheet> {
  final note = TextEditingController(), search = TextEditingController();
  final returns = <int, int>{};
  final newLines = <Map<String, dynamic>>[];
  Map<String, dynamic>? details, quote, result, selected;
  List<Map<String, dynamic>> products = [], variants = [];
  bool loading = true,
      busy = false,
      finding = false,
      exchange = false,
      cashConfirmed = false;
  String? error, catalogError;
  String method = 'STRIPE';
  ExchangeOperation? operation;
  bool get frozen => operation?.payload != null;
  bool get staff => widget.offline?.canSell == true;
  int? get branch => details?['sucursal_id'] as int? ?? widget.order.sucursalId;
  double money(dynamic value) => double.tryParse(value?.toString() ?? '') ?? 0;
  String message(Object e) => e is ApiException
      ? e.message
      : 'No se pudo completar la consulta. Revisa la conexión y vuelve a intentar.';

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    note.dispose();
    search.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final local = widget.offline;
      final owner = local?.owner;
      final role = local?.auth.currentUser?.rol.toServerString();
      if (operation == null) {
        if (widget.operation != null) {
          operation = widget.operation;
        } else if (owner != null && local != null) {
          operation = ExchangeOperation(
            api: widget.orderService,
            store: DeferredStore(store: local.store),
            owner: '$owner|$role',
            orderId: widget.order.id,
            authorized: () =>
                local.owner == owner &&
                local.auth.hasValidToken &&
                local.auth.currentUser?.rol.toServerString() == role,
          );
        } else {
          throw ApiException(
            'Abre la tienda con tu cuenta para gestionar esta compra.',
          );
        }
        await operation!.restore();
      }
      if (operation!.payload != null) {
        await operation!.recover();
        if (!mounted) return;
        setState(() {
          result = operation!.result;
          loading = false;
        });
        return;
      }
      final data = await widget.orderService.findOrderForExchange(
        widget.order.id.toString(),
      );
      if (!mounted) return;
      operation!.check();
      setState(() {
        details = data;
        loading = false;
        returns.clear();
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          error = message(e);
          loading = false;
        });
      }
    }
  }

  Future<void> findProducts() async {
    setState(() {
      finding = true;
      catalogError = null;
    });
    try {
      final rows = await widget.orderService.exchangeProducts(
        search.text.trim(),
      );
      operation!.check();
      if (mounted) setState(() => products = rows);
    } catch (e) {
      if (mounted) setState(() => catalogError = message(e));
    } finally {
      if (mounted) setState(() => finding = false);
    }
  }

  Future<void> selectProduct(Map<String, dynamic> product) async {
    setState(() {
      finding = true;
      catalogError = null;
      selected = null;
      variants = [];
    });
    try {
      final data = await widget.orderService.exchangeProduct(product['id']);
      final stock = await widget.orderService.exchangeAvailability(
        product['id'],
      );
      operation!.check();
      final rows = ((data['variantes'] as List?) ?? [])
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
      for (final v in rows) {
        final row = stock
            .where(
              (s) => s['variante_id'] == v['id'] && s['sucursal_id'] == branch,
            )
            .firstOrNull;
        v['disponible_sucursal'] = row?['stock_disponible'] ?? 0;
      }
      if (mounted) {
        setState(() {
          selected = data;
          products = [product];
          variants = rows;
        });
      }
    } catch (e) {
      if (mounted) setState(() => catalogError = message(e));
    } finally {
      if (mounted) setState(() => finding = false);
    }
  }

  void addVariant(Map<String, dynamic> v) {
    final prior = newLines
        .where((r) => r['variante_id'] == v['id'])
        .firstOrNull;
    final quantity = (prior?['cantidad'] as int? ?? 0) + 1;
    if (quantity > (v['disponible_sucursal'] as num).toInt()) return;
    setState(() {
      if (prior != null) {
        prior['cantidad'] = quantity;
      } else {
        newLines.add({
          'variante_id': v['id'],
          'cantidad': 1,
          'nombre': selected!['nombre'],
          'talla': v['talla'],
          'color': v['color'],
        });
      }
      quote = null;
      cashConfirmed = false;
    });
  }

  Map<String, dynamic> selection() {
    if (branch == null) {
      throw ApiException(
        'La compra no tiene sucursal de origen. Contacta con la tienda para gestionar el cambio.',
      );
    }
    final diff = money(quote?['diferencia']);
    return {
      'operacion_id': ExchangeOperation.uuid(),
      'pedido_origen_id': widget.order.id,
      'sucursal_id': branch,
      'motivo': note.text.trim().isEmpty
          ? 'Cambio o devolución de prendas'
          : note.text.trim(),
      'devoluciones': returns.entries
          .where((e) => e.value > 0)
          .map((e) => {'item_pedido_id': e.key, 'cantidad': e.value})
          .toList(),
      'prendas_nuevas': newLines
          .map(
            (r) => {'variante_id': r['variante_id'], 'cantidad': r['cantidad']},
          )
          .toList(),
      'metodo_pago': method,
      'efectivo_recibido': method == 'EFECTIVO' && diff > 0
          ? diff.toStringAsFixed(2)
          : '0.00',
      'efectivo_devuelto': method == 'EFECTIVO' && diff < 0
          ? (-diff).toStringAsFixed(2)
          : '0.00',
    };
  }

  Future<void> calculate() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final data = await widget.orderService.quoteExchange(selection());
      operation!.check();
      if (mounted) setState(() => quote = data);
    } catch (e) {
      if (mounted) setState(() => error = message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> confirm() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final data = await operation!.confirm(
        frozen ? operation!.payload! : selection(),
      );
      if (!mounted) return;
      setState(() => result = data);
      widget.onConfirmed();
      if (data['stripe_payment_needed'] == true) await pay();
    } catch (e) {
      if (mounted) setState(() => error = message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> pay() async {
    final id = result?['pedido_nuevo_id'];
    if (id is! int || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            widget.paymentBuilder?.call(id) ?? StripePaymentScreen(orderId: id),
      ),
    );
    if (!mounted) return;
    // Recover the original exchange; never create another sale after cancellation.
    final data = await operation!.confirm(operation!.payload!);
    if (mounted) {
      setState(() => result = data);
      widget.onConfirmed();
    }
  }

  Future<void> done() async {
    try {
      final refund = result?['stripe_refund'];
      if (refund == null || refund['estado'] == 'REEMBOLSADO') {
        await operation!.clearCompleted();
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = message(e));
    }
  }

  Widget notice(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Text(
      text,
      style: const TextStyle(color: AppColors.muted, fontSize: 13),
    ),
  );
  Widget resultView() {
    final refund = result!['stripe_refund'] as Map?;
    final pending = result!['stripe_payment_needed'] == true;
    final difference = money(result!['diferencia']);
    final text = pending
        ? 'Cambio registrado. Falta autorizar Bs ${difference.toStringAsFixed(2)} con tu tarjeta.'
        : refund?['estado'] == 'REEMBOLSADO'
        ? 'Devolución registrada. Stripe confirmó el reembolso de Bs ${money(refund?['monto']).toStringAsFixed(2)} a la tarjeta original.'
        : refund != null
        ? 'Devolución registrada. El reembolso de Bs ${money(refund['monto']).toStringAsFixed(2)} está ${refund['estado'] == 'REEMBOLSO_FALLIDO' ? 'pendiente de revisión por la tienda' : 'en proceso en Stripe'}.'
        : '${money(result!['total_nuevo']) == 0 ? 'Devolución' : 'Cambio'} registrado. ${difference < 0 ? 'Efectivo devuelto: Bs ${(-difference).toStringAsFixed(2)}.' : 'La compra conserva su comprobante.'}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          color: AppColors.lime,
          child: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        notice(
          'Operación ${result!['id']} · Pedido #${result!['pedido_nuevo_id']}',
        ),
        if (pending) ...[
          FilledButton.icon(
            onPressed: busy ? null : () => runPay(),
            icon: const Icon(Icons.credit_card),
            label: const Text('Pagar diferencia con Stripe'),
          ),
          notice(
            'Si cerraste el pago, puedes retomarlo aquí o en Pedidos. Se conserva la misma operación.',
          ),
        ] else
          FilledButton(
            onPressed: busy ? null : done,
            child: const Text('Volver a mis pedidos'),
          ),
        if (refund != null && refund['estado'] != 'REEMBOLSADO')
          TextButton(
            onPressed: busy ? null : refreshResult,
            child: const Text('Actualizar estado del reembolso'),
          ),
      ],
    );
  }

  Future<void> refreshResult() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final data = await operation!.recover();
      if (data == null) {
        throw ApiException(
          'Aún no se encontró un resultado. Reintenta con conexión.',
        );
      }
      if (mounted) {
        setState(() => result = data);
        widget.onConfirmed();
      }
    } catch (e) {
      if (mounted) setState(() => error = message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> runPay() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await pay();
    } catch (e) {
      if (mounted) setState(() => error = message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ((details?['items'] as List?) ?? [])
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
    final hasReturns = returns.values.any((q) => q > 0);
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .94,
        ),
        decoration: const BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.swap_horiz),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Cambios y devoluciones',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar cambios y devoluciones',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              notice(
                'Pedido #${widget.order.id} · Compra de Bs ${widget.order.total.toStringAsFixed(2)}',
              ),
              const Divider(),
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (result != null)
                resultView()
              else if (frozen) ...[
                notice(
                  'Esta solicitud ya se envió. Comprobaremos su resultado antes de repetirla.',
                ),
                FilledButton(
                  onPressed: busy ? null : confirm,
                  child: const Text('Comprobar mi cambio'),
                ),
              ] else if (details != null) ...[
                const Text(
                  '¿Qué prendas quieres devolver?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                notice(
                  'Elige la cantidad de cada prenda. Después puedes seleccionar otra talla o solicitar la devolución.',
                ),
                for (final item in items)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppColors.paperDark),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['nombre']?.toString() ?? 'Prenda',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '${item['talla']} · ${item['color']} · ${item['disponible_cambio']} disponibles para devolver',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          children: [
                            IconButton(
                              tooltip: 'Quitar una unidad de ${item['nombre']}',
                              onPressed: busy || (returns[item['id']] ?? 0) == 0
                                  ? null
                                  : () => setState(() {
                                      returns[item['id']] =
                                          (returns[item['id']] ?? 0) - 1;
                                      quote = null;
                                      cashConfirmed = false;
                                    }),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            Text(
                              '${returns[item['id']] ?? 0}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            IconButton(
                              tooltip:
                                  'Devolver una unidad de ${item['nombre']}',
                              onPressed:
                                  busy ||
                                      (returns[item['id']] ?? 0) >=
                                          (item['disponible_cambio'] as num? ??
                                              0)
                                  ? null
                                  : () => setState(() {
                                      returns[item['id']] =
                                          (returns[item['id']] ?? 0) + 1;
                                      quote = null;
                                      cashConfirmed = false;
                                    }),
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                            Text(
                              'Bs ${money(item['credito_unitario']).toStringAsFixed(2)} / unidad',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Elegir otra prenda'),
                  subtitle: const Text('Cambia talla, color o modelo'),
                  value: exchange,
                  onChanged: busy
                      ? null
                      : (v) {
                          setState(() {
                            exchange = v;
                            quote = null;
                            cashConfirmed = false;
                            if (!v) {
                              newLines.clear();
                              selected = null;
                            }
                          });
                          if (v && products.isEmpty) findProducts();
                        },
                ),
                if (exchange) ...[
                  TextField(
                    controller: search,
                    enabled: !busy && !finding,
                    decoration: InputDecoration(
                      labelText: 'Buscar una prenda',
                      suffixIcon: IconButton(
                        tooltip: 'Buscar prendas',
                        onPressed: busy || finding ? null : findProducts,
                        icon: const Icon(Icons.search),
                      ),
                    ),
                    onSubmitted: (_) => findProducts(),
                  ),
                  if (finding) const LinearProgressIndicator(),
                  if (catalogError != null) ...[
                    notice(catalogError!),
                    TextButton(
                      onPressed: finding ? null : findProducts,
                      child: const Text('Reintentar catálogo'),
                    ),
                  ],
                  for (final p in products)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: SizedBox(
                        width: 45,
                        height: 55,
                        child: DmProductImage(
                          imageUrl: ApiConfig.resolveMediaUrl(
                            ((p['imagenes'] as List?) ?? []).firstOrNull
                                    ?.toString() ??
                                '',
                          ),
                          semanticLabel: p['nombre']?.toString() ?? 'Prenda',
                        ),
                      ),
                      title: Text(
                        p['nombre']?.toString() ?? '',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        'Bs ${money(p['precio']).toStringAsFixed(2)}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: busy || finding ? null : () => selectProduct(p),
                    ),
                  if (products.isEmpty && !finding && catalogError == null)
                    notice('No hay resultados. Prueba otro nombre de prenda.'),
                  if (selected != null) ...[
                    Text(
                      selected!['nombre'].toString(),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    notice('Disponibilidad en la sucursal de tu compra'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final v in variants)
                          OutlinedButton(
                            onPressed:
                                busy ||
                                    (v['disponible_sucursal'] as num) <=
                                        (newLines
                                                    .where(
                                                      (r) =>
                                                          r['variante_id'] ==
                                                          v['id'],
                                                    )
                                                    .firstOrNull?['cantidad']
                                                as int? ??
                                            0)
                                ? null
                                : () => addVariant(v),
                            child: Text('${v['talla']} · ${v['color']} (+1)'),
                          ),
                      ],
                    ),
                    if (variants.every(
                      (v) => (v['disponible_sucursal'] as num) <= 0,
                    ))
                      notice(
                        'Esta prenda no tiene stock en la sucursal de tu compra.',
                      ),
                  ],
                  for (final row in newLines)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${row['nombre']} · ${row['talla']} · ${row['color']}',
                      ),
                      subtitle: Text('${row['cantidad']} unidad(es)'),
                      trailing: IconButton(
                        tooltip: 'Quitar ${row['nombre']}',
                        onPressed: busy
                            ? null
                            : () => setState(() {
                                newLines.remove(row);
                                quote = null;
                                cashConfirmed = false;
                              }),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                ],
                const SizedBox(height: 14),
                TextField(
                  controller: note,
                  enabled: !busy,
                  maxLength: 300,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Motivo del cambio o devolución',
                  ),
                  onChanged: (_) => setState(() {
                    quote = null;
                    cashConfirmed = false;
                  }),
                ),
                if (staff)
                  DropdownButtonFormField<String>(
                    value: method,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Cobro o devolución',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'STRIPE',
                        child: Text('Tarjeta con Stripe'),
                      ),
                      DropdownMenuItem(
                        value: 'EFECTIVO',
                        child: Text('Efectivo en caja'),
                      ),
                    ],
                    onChanged: busy
                        ? null
                        : (v) => setState(() {
                            method = v!;
                            quote = null;
                            cashConfirmed = false;
                          }),
                  ),
                if (quote != null) ...[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.paperDark,
                      border: Border.all(color: AppColors.ink),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Crédito por devolución: Bs ${money(quote!['credito']).toStringAsFixed(2)}',
                        ),
                        Text(
                          'Prendas nuevas: Bs ${money(quote!['total_nuevo']).toStringAsFixed(2)}',
                        ),
                        const Divider(),
                        Text(
                          '${money(quote!['diferencia']) > 0
                              ? 'Diferencia a pagar'
                              : money(quote!['diferencia']) < 0
                              ? 'Importe a devolver'
                              : 'Sin diferencia'}: Bs ${money(quote!['diferencia']).abs().toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!staff &&
                      money(quote!['diferencia']) < 0 &&
                      quote!['stripe_refund_eligible'] != true)
                    notice(
                      'Esta compra se pagó sin tarjeta. Acércate a la sucursal para recibir el reembolso en caja.',
                    ),
                  if (staff &&
                      method == 'EFECTIVO' &&
                      money(quote!['diferencia']) != 0)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: cashConfirmed,
                      onChanged: busy
                          ? null
                          : (v) => setState(() => cashConfirmed = v == true),
                      title: Text(
                        'Confirmo que ${money(quote!['diferencia']) > 0 ? 'recibí' : 'devolví'} Bs ${money(quote!['diferencia']).abs().toStringAsFixed(2)} en caja',
                      ),
                    ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed:
                      busy ||
                          !hasReturns ||
                          (exchange && newLines.isEmpty) ||
                          (quote != null &&
                              staff &&
                              method == 'EFECTIVO' &&
                              money(quote!['diferencia']) != 0 &&
                              !cashConfirmed) ||
                          (quote != null &&
                              !staff &&
                              money(quote!['diferencia']) < 0 &&
                              quote!['stripe_refund_eligible'] != true)
                      ? null
                      : quote == null
                      ? calculate
                      : confirm,
                  child: Text(
                    busy
                        ? 'Comprobando…'
                        : quote == null
                        ? 'Revisar importes'
                        : newLines.isEmpty
                        ? 'Confirmar devolución'
                        : 'Confirmar cambio',
                  ),
                ),
                notice(
                  'La tienda verifica las cantidades y existencias antes de confirmar. Los reembolsos a tarjeta conservan el estado real de Stripe.',
                ),
              ],
              if (error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  color: AppColors.dangerBg,
                  child: Text(
                    error!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
                if (details == null && !frozen && !loading)
                  TextButton(
                    onPressed: load,
                    child: const Text('Reintentar consulta'),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
