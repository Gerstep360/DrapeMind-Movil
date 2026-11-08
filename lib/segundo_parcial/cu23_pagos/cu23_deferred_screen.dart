import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drapemind_mobile/core/theme/app_colors.dart';
import 'package:drapemind_mobile/segundo_parcial/cu23_pagos/cu23_deferred_service.dart';

class DeferredPurchasesScreen extends StatefulWidget {
  const DeferredPurchasesScreen({super.key});
  @override
  State<DeferredPurchasesScreen> createState() =>
      _DeferredPurchasesScreenState();
}

class _DeferredPurchasesScreenState extends State<DeferredPurchasesScreen> {
  String delivery = 'RECOJO';
  int? branch, address, card;
  bool consent = false, busy = false;
  double? consentTotal;
  String? error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<DeferredService>().refresh();
    });
  }

  double total(DeferredService service) =>
      (double.tryParse('${service.contextData?['cart']?['subtotal'] ?? 0}') ??
          0) +
      (delivery == 'DELIVERY'
          ? (double.tryParse('${service.contextData?['delivery_fee'] ?? 0}') ??
                0)
          : 0);
  Future<void> perform(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<bool> authorize(String title, String terms) async {
    var accepted = false;
    return await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialog) => AlertDialog(
              title: Text(title),
              content: SingleChildScrollView(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: accepted,
                  onChanged: (value) =>
                      setDialog(() => accepted = value == true),
                  title: Text(terms, style: const TextStyle(fontSize: 14)),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: accepted
                      ? () => Navigator.pop(context, true)
                      : null,
                  child: const Text('Autorizar'),
                ),
              ],
            ),
          ),
        ) ??
        false;
  }

  Future<void> save(DeferredService service) async {
    if (delivery == 'RECOJO' && branch == null) {
      throw Exception('Selecciona la sucursal donde recogerás tus prendas.');
    }
    if (delivery == 'DELIVERY' && address == null) {
      throw Exception('Selecciona una dirección guardada.');
    }
    if (card != null && (!consent || consentTotal != total(service))) {
      throw Exception('Autoriza el importe del cobro antes de continuar.');
    }
    await service.enqueue(
      delivery: delivery,
      branch: branch,
      address: address,
      card: card,
      total: total(service),
      consent: consent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DeferredService>();
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: const Text('Compras pendientes'),
        backgroundColor: AppColors.paper,
        actions: [
          IconButton(
            onPressed: busy || service.busy
                ? null
                : () => perform(service.refresh),
            icon: const Icon(Icons.refresh),
            tooltip: 'Sincronizar compras',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            service.online
                ? 'Tu compra, a tu ritmo.'
                : 'Sin conexión. Tu compra queda guardada.',
            style: const TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Al reconectar comprobaremos stock y precio antes de cobrar. Stripe debe confirmar el pago para completar tu pedido.',
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                error!,
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
          if (service.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(service.error!, style: const TextStyle(fontSize: 12)),
            ),
          const SizedBox(height: 20),
          const Divider(thickness: 2),
          const Text(
            'Prendas de tu carrito',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
          ),
          if (service.contextData == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'Abre esta pantalla con conexión para descargar tu carrito, sucursales y tarjetas.',
              ),
            ),
          for (final item in service.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item['nombre']}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${item['talla']} · ${item['color']} · ${item['cantidad']} unidades',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('Bs ${item['subtotal']}'),
                ],
              ),
            ),
          if (service.contextData != null) ...[
            const Text(
              'La disponibilidad local es orientativa; se confirma al sincronizar.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: delivery,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Recibir mis prendas',
              ),
              items: const [
                DropdownMenuItem(
                  value: 'RECOJO',
                  child: Text('Recoger en tienda'),
                ),
                DropdownMenuItem(
                  value: 'DELIVERY',
                  child: Text('Entrega a domicilio'),
                ),
              ],
              onChanged: (value) => setState(() => delivery = value!),
            ),
            const SizedBox(height: 16),
            if (delivery == 'RECOJO')
              DropdownButtonFormField<int>(
                value: branch,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Sucursal'),
                items: service
                    .rows('branches')
                    .map(
                      (b) => DropdownMenuItem<int>(
                        value: b['id'],
                        child: Text(
                          '${b['nombre']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => branch = value),
              ),
            if (delivery == 'DELIVERY')
              DropdownButtonFormField<int>(
                value: address,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Dirección guardada',
                ),
                items: service
                    .rows('addresses')
                    .map(
                      (b) => DropdownMenuItem<int>(
                        value: b['id'],
                        child: Text(
                          '${b['alias']} · ${b['ciudad']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => address = value),
              ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: service.rows('cards').any((item) => item['id'] == card)
                  ? card
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Tarjeta para esta compra',
              ),
              items: [
                const DropdownMenuItem<int>(
                  value: null,
                  child: Text(
                    'Elegiré tarjeta al reconectar',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ...service
                    .rows('cards')
                    .map(
                      (b) => DropdownMenuItem<int>(
                        value: b['id'],
                        child: Text(
                          '${b['marca']} ···· ${b['ultimos_cuatro']}',
                        ),
                      ),
                    ),
              ],
              onChanged: (value) => setState(() => card = value),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: busy
                    ? null
                    : () => perform(() async {
                        if (await authorize(
                          'Guardar tarjeta en Stripe',
                          'Acepto guardar mi tarjeta en Stripe para futuros cobros que autorice expresamente, con su importe y antes de 24 horas. Podré cancelar las compras pendientes antes de su pago.',
                        )) {
                          await service.saveCard(true);
                        }
                      }),
                child: const Text('Guardar tarjeta con conexión'),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 18,
              runSpacing: 6,
              children: [
                const Text('Importe autorizado'),
                Text(
                  'Bs ${total(service).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            if (card != null)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: consent,
                onChanged: (value) => setState(() {
                  consent = value == true;
                  consentTotal = consent ? total(service) : null;
                }),
                title: Text(
                  'Autorizo un único cobro de Bs ${total(service).toStringAsFixed(2)} al recuperar conexión, dentro de 24 horas. Si cambia el importe o falta stock, no se cobrará.',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            if (card == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Sin tarjeta se guardará la solicitud y tendrás que autorizar el pago cuando vuelva Internet.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            FilledButton(
              onPressed:
                  busy || service.items.isEmpty || (card != null && !consent)
                  ? null
                  : () => perform(() => save(service)),
              child: Text(busy ? 'Guardando…' : 'Guardar compra pendiente'),
            ),
          ],
          const SizedBox(height: 28),
          const Divider(thickness: 2),
          const Text(
            'Estado de tus compras',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
          ),
          if (service.purchases.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'Las compras guardadas aparecerán aquí, separadas por cuenta y tienda.',
              ),
            ),
          for (final row in service.purchases)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DeferredService.label(service.state(row)),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text('${row['label']}'),
                  const SizedBox(height: 6),
                  Text(
                    'Bs ${row['remote']?['total_autorizado'] ?? row['body']?['total_autorizado'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${row['remote']?['mensaje'] ?? 'Guardada en este teléfono; el pago y el stock aún no están confirmados.'}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  if (!service.terminal(row))
                    Wrap(
                      spacing: 10,
                      children: [
                        if (service.state(row) == 'REQUIERE_AUTENTICACION')
                          TextButton(
                            onPressed: busy
                                ? null
                                : () =>
                                      perform(() => service.authenticate(row)),
                            child: const Text('Verificar con mi banco'),
                          ),
                        if (service.state(row) == 'REQUIERE_METODO')
                          TextButton(
                            onPressed: busy || card == null
                                ? null
                                : () => perform(() async {
                                    if (await authorize(
                                      'Autorizar compra pendiente',
                                      'Autorizo un único cobro de Bs ${row['remote']?['total_autorizado']} con la tarjeta seleccionada para esta compra.',
                                    )) {
                                      await service.chooseCard(row, card!);
                                    }
                                  }),
                            child: const Text('Autorizar tarjeta elegida'),
                          ),
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => perform(() => service.cancel(row)),
                          child: const Text('Cancelar compra'),
                        ),
                      ],
                    ),
                  const Divider(),
                ],
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
