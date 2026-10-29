import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:drapemind_mobile/core/theme/app_colors.dart';
import 'package:drapemind_mobile/core/config/api_config.dart';
import 'package:drapemind_mobile/core/network/api_exception.dart';
import 'package:drapemind_mobile/paquetes/acceso_gestion_usuarios/datos/servicios/auth_service.dart';
import 'package:drapemind_mobile/paquetes/acceso_gestion_usuarios/gestionar_cuenta/presentacion/account_screen.dart';
import '../offline/models.dart';
import '../offline/offline_service.dart';
import '../offline/offline_screen.dart';

class RetailScreen extends StatefulWidget {
  const RetailScreen({super.key});
  @override
  State<RetailScreen> createState() => _RetailScreenState();
}

class _RetailScreenState extends State<RetailScreen> {
  int _tab = 0, _branch = 0, _variant = 0, _quantity = 1;
  String _search = '', _error = '', _success = '', _filter = '';
  bool _busy = false;
  final _cash = TextEditingController();
  final List<Map<String, dynamic>> _lines = [];
  String? _owner;
  String money(Object? value) =>
      'Bs ${(num.tryParse(value.toString()) ?? 0).toStringAsFixed(2)}';
  @override
  void dispose() {
    _cash.dispose();
    super.dispose();
  }

  Future<void> action(Future<void> Function() work) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = '';
      _success = '';
    });
    try {
      await work();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No pudimos completar la acción. Tus operaciones guardadas se conservan.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  int branchId(OfflineService service) =>
      service.bundle?.branches.any((b) => b['id'] == _branch) == true
      ? _branch
      : (service.bundle?.branches.firstOrNull?['id'] as int? ?? 0);
  num price(OfflineService service, int id) {
    final variant = service.bundle?.variants
        .where((v) => v['id'] == id)
        .firstOrNull;
    final product = service.bundle?.products
        .where((p) => p['id'] == variant?['producto_id'])
        .firstOrNull;
    return num.tryParse(product?['precio'].toString() ?? '') ?? 0;
  }

  num total(OfflineService service) =>
      _lines.fold<int>(
        0,
        (n, i) =>
            n +
            (price(service, i['variante_id']) * 100).round() *
                (i['cantidad'] as int),
      ) /
      100;
  num reservationTotal(Map<String, dynamic> r) =>
      (r['items'] as List).fold<int>(
        0,
        (n, i) =>
            n +
            ((num.tryParse(i['precio_unitario'].toString()) ?? 0) * 100)
                    .round() *
                (i['cantidad'] as int),
      ) /
      100;
  void add(OfflineService service) {
    final existing = _lines
        .where((l) => l['variante_id'] == _variant)
        .firstOrNull;
    final quantity = (existing?['cantidad'] as int? ?? 0) + _quantity;
    if (_variant < 1 ||
        _quantity < 1 ||
        quantity > 100 ||
        quantity > service.available(_variant, branchId(service))) {
      setState(
        () => _error =
            'Elige una talla y una cantidad disponible en la sucursal.',
      );
      return;
    }
    setState(() {
      if (existing == null) {
        _lines.add({'variante_id': _variant, 'cantidad': _quantity});
      } else {
        existing['cantidad'] = quantity;
      }
      _quantity = 1;
      _error = '';
    });
  }

  Future<void> save(OfflineService service) async {
    await action(() async {
      await service.cashSale(
        _lines.map((i) => Map<String, dynamic>.from(i)).toList(),
        branchId(service),
        _cash.text,
      );
      if (mounted) {
        setState(() {
          _lines.clear();
          _cash.clear();
          _tab = 2;
          _success = 'Venta guardada. Consulta el comprobante y su resultado.';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<OfflineService>(), data = service.bundle;
    if (service.owner != _owner) {
      _owner = service.owner;
      _lines.clear();
      _cash.clear();
      _branch = 0;
      _variant = 0;
      _search = '';
    }
    final branch = branchId(service);
    final variants = (data?.variants ?? <Map<String, dynamic>>[])
        .where(
          (v) =>
              service
                  .variantName(v['id'])
                  .toLowerCase()
                  .contains(_search.toLowerCase()) ||
              v['sku'].toString().toLowerCase().contains(_search.toLowerCase()),
        )
        .take(100)
        .toList();
    if (!variants.any((v) => v['id'] == _variant)) _variant = 0;
    final reservations = (data?.reservations ?? <Map<String, dynamic>>[])
        .where(
          (r) =>
              r['sucursal_id'] == branch &&
              ('${r['id']}' == _search ||
                  r['codigo_publico'].toString().toLowerCase().contains(
                    _search.toLowerCase(),
                  )),
        )
        .toList();
    final operations =
        service.queue
            .where((r) => _filter.isEmpty || r.state == _filter)
            .toList()
          ..sort(
            (a, b) => b.body['creado_at'].toString().compareTo(
              a.body['creado_at'].toString(),
            ),
          );
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: const Text('Caja y reservas'),
        actions: [
          IconButton(
            tooltip: 'Catálogo sin conexión',
            icon: const Icon(Icons.download_for_offline_outlined),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const OfflineScreen())),
          ),
          IconButton(
            tooltip: 'Mi cuenta',
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const AccountScreen())),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    data?.tenantName ?? 'Tu sucursal',
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Icon(service.online ? Icons.wifi : Icons.wifi_off),
                const SizedBox(width: 6),
                Text(service.online ? 'Con señal' : 'Sin señal'),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in {
                  0: 'Nueva venta',
                  1: 'Reservas',
                  2: 'Operaciones',
                }.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: _tab == entry.key,
                    onSelected: _busy
                        ? null
                        : (_) {
                            setState(() {
                              _tab = entry.key;
                              _search = '';
                            });
                            if (entry.key == 1 && service.online) {
                              action(service.refreshReservations);
                            }
                          },
                  ),
              ],
            ),
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _error,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
            if (_success.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_success),
              ),
            if (_busy || service.syncing)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(),
              ),
            if (!service.canSell)
              const Text('Este espacio requiere una cuenta de caja autorizada.')
            else ...[
              if (!service.usable)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  padding: const EdgeInsets.all(16),
                  color: AppColors.limeSoft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Guarda o actualiza el catálogo antes de cobrar. Los pendientes se conservan.',
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: service.downloading
                            ? null
                            : () => action(service.download),
                        icon: const Icon(Icons.download_outlined),
                        label: Text(
                          service.downloading
                              ? service.phase
                              : 'Guardar catálogo',
                        ),
                      ),
                    ],
                  ),
                ),
              if (data != null) ...[
                const SizedBox(height: 18),
                DropdownButtonFormField<int>(
                  value: branch == 0 ? null : branch,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Sucursal de atención',
                  ),
                  items: data.branches
                      .map(
                        (b) => DropdownMenuItem<int>(
                          value: b['id'],
                          child: Text(
                            '${b['nombre']} · ${b['ciudad']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (v) => setState(() {
                          _branch = v ?? 0;
                          _lines.clear();
                        }),
                ),
                if (_tab == 0) ...[
                  const SizedBox(height: 22),
                  const Text(
                    'Prendas para esta venta',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Buscar nombre o código',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: _variant,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Prenda, talla y color',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 0,
                        child: Text('Elige una variante'),
                      ),
                      ...variants.map(
                        (v) => DropdownMenuItem<int>(
                          value: v['id'],
                          child: Text(
                            '${service.variantName(v['id'])} · ${service.available(v['id'], branch)} disponibles',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _variant = v ?? 0),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Cantidad'),
                      IconButton(
                        tooltip: 'Quitar una unidad',
                        onPressed: _busy || _quantity <= 1
                            ? null
                            : () => setState(() => _quantity--),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text('$_quantity'),
                      IconButton(
                        tooltip: 'Añadir una unidad',
                        onPressed: _busy || _quantity >= 100
                            ? null
                            : () => setState(() => _quantity++),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                      const Spacer(),
                      OutlinedButton(
                        onPressed: _busy ? null : () => add(service),
                        child: const Text('Añadir'),
                      ),
                    ],
                  ),
                  ..._lines.map(
                    (line) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(service.variantName(line['variante_id'])),
                      subtitle: Text(
                        "${line['cantidad']} × ${money(price(service, line['variante_id']))}",
                      ),
                      trailing: IconButton(
                        tooltip: 'Quitar prenda',
                        onPressed: _busy
                            ? null
                            : () => setState(() => _lines.remove(line)),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  ),
                  if (_lines.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text('Añade las prendas que el cliente llevará.'),
                    ),
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 16),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.limeSoft,
                      border: Border.all(color: AppColors.ink),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Contado en efectivo',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          money(total(service)),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _cash,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          enabled: !_busy,
                          decoration: const InputDecoration(
                            labelText: 'Efectivo recibido',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Cambio: ${money(((num.tryParse(_cash.text) ?? 0) - total(service)).clamp(0, double.infinity))}',
                          ),
                        ),
                        const Text(
                          'Guarda cuando hayas recibido el dinero y entregado las prendas. Sin señal tendrás un comprobante provisional.',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _busy || !service.usable || _lines.isEmpty
                              ? null
                              : () => save(service),
                          child: const Text('Guardar venta de contado'),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_tab == 1) ...[
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Reservas por atender',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Actualizar reservas',
                        onPressed: _busy || !service.online
                            ? null
                            : () => action(service.refreshReservations),
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Número o código de reserva',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                  const SizedBox(height: 16),
                  for (final reservation in reservations)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        border: Border.all(color: AppColors.lineStrong),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reserva ${reservation['id']} · ${reservation['estado']}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          for (final i in reservation['items'] as List)
                            Text(
                              "${i['cantidad']} × ${service.variantName(i['variante_id'])}",
                            ),
                          const SizedBox(height: 8),
                          Text('Total ${money(reservationTotal(reservation))}'),
                          Text(
                            'Vence ${DateTime.parse(reservation['vence_at']).toLocal()}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed:
                                    _busy ||
                                        !service.online ||
                                        [
                                          'LISTA',
                                          'RETIRADA',
                                        ].contains(reservation['estado'])
                                    ? null
                                    : () => action(
                                        () => service.prepareReservation(
                                          reservation['id'],
                                          'LISTA',
                                        ),
                                      ),
                                child: const Text('Marcar lista'),
                              ),
                              FilledButton(
                                onPressed: _busy || !service.usable
                                    ? null
                                    : () => collect(service, reservation),
                                child: const Text('Cobrar y entregar'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  if (reservations.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No hay reservas de esta sucursal con ese código.',
                      ),
                    ),
                ],
              ],
              if (_tab == 2) ...[
                const SizedBox(height: 20),
                const Text(
                  'Operaciones y resultados',
                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy || service.syncing || !service.online
                      ? null
                      : () => action(service.checkConnection),
                  icon: const Icon(Icons.sync),
                  label: const Text('Sincronizar y consultar resultados'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _filter,
                  decoration: const InputDecoration(labelText: 'Estado'),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('Todos')),
                    DropdownMenuItem(
                      value: 'PENDING',
                      child: Text('Guardadas'),
                    ),
                    DropdownMenuItem(
                      value: 'UNCERTAIN',
                      child: Text('Por comprobar'),
                    ),
                    DropdownMenuItem(
                      value: 'CONFLICT',
                      child: Text('En revisión'),
                    ),
                    DropdownMenuItem(
                      value: 'CONFIRMED',
                      child: Text('Confirmadas'),
                    ),
                    DropdownMenuItem(
                      value: 'REJECTED',
                      child: Text('Anuladas'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _filter = v ?? ''),
                ),
                const SizedBox(height: 16),
                for (final record in operations)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: record.state == 'CONFLICT'
                          ? const Color(0xfffff0d4)
                          : AppColors.white,
                      border: Border.all(color: AppColors.lineStrong),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.label,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          record.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text('${record.branch} · ${record.attempts} intentos'),
                        for (final i in record.body['items'] as List)
                          Text(
                            "${i['cantidad']} × ${service.variantName(i['variante_id'])}",
                          ),
                        if (record.message != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(record.message!),
                          ),
                        if (record.sale != null)
                          Text(
                            "Pedido ${record.sale!['pedido_id']} · ${money(record.sale!['total'])}",
                          ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (record.kind != 'RESERVATION')
                              TextButton(
                                onPressed: () => receipt(service, record),
                                child: Text(
                                  record.sale == null
                                      ? 'Ver comprobante provisional'
                                      : 'Ver comprobante',
                                ),
                              ),
                            if (record.state == 'CONFLICT')
                              TextButton(
                                onPressed: service.online && !service.syncing
                                    ? () => action(() => service.retry(record))
                                    : null,
                                child: const Text('Volver a comprobar'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                if (operations.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Las ventas y reservas guardadas aparecerán aquí con su resultado.',
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> collect(
    OfflineService service,
    Map<String, dynamic> reservation,
  ) async {
    final cash = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Cobrar reserva ${reservation['id']}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total ${money(reservationTotal(reservation))}'),
            const SizedBox(height: 16),
            TextField(
              controller: cash,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Efectivo recibido'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Al guardar registras el cobro y la entrega. El servidor validará la reserva al sincronizar.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, cash.text),
            child: const Text('Guardar cobro'),
          ),
        ],
      ),
    );
    cash.dispose();
    if (value == null || !mounted) return;
    await action(() async {
      await service.pickup(reservation, value);
      if (mounted) {
        setState(() {
          _tab = 2;
          _success = 'Cobro de la reserva guardado.';
        });
      }
    });
  }

  Future<void> receipt(OfflineService service, OfflineRequest r) async {
    final total = (r.body['items'] as List).fold<num>(
      0,
      (n, i) =>
          n +
          (num.tryParse(i['precio_unitario'].toString()) ?? 0) *
              (i['cantidad'] as int),
    );
    final received = num.tryParse(r.body['efectivo_recibido'].toString()) ?? 0;
    final text = [
      r.sale == null
          ? 'COMPROBANTE PROVISIONAL · PENDIENTE DE SINCRONIZACIÓN'
          : 'COMPROBANTE DE VENTA',
      service.bundle?.tenantName ?? 'Tienda',
      r.branch,
      "Operación ${r.body['operacion_id']}",
      r.body['creado_at'].toString(),
      for (final i in r.body['items'] as List)
        "${i['cantidad']} × ${service.variantName(i['variante_id'])} · ${money(i['precio_unitario'])}",
      'Total: ${money(total)}',
      'Efectivo recibido: ${money(received)}',
      'Cambio: ${money(received - total)}',
      r.label,
      if (r.sale != null)
        "Pedido ${r.sale!['pedido_id']} · ${r.sale!['codigo_publico']}",
      'Documento interno no fiscal.',
    ].join('\n');
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          r.sale == null ? 'Comprobante provisional' : 'Comprobante de venta',
        ),
        content: SingleChildScrollView(child: SelectableText(text)),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
            },
            child: const Text('Copiar'),
          ),
          if (r.sale != null && service.online)
            TextButton(
              onPressed: () async {
                final slug =
                    context.read<AuthService>().currentUser?.tenantSlug ?? '';
                final uri =
                    Uri.parse(
                      "${ApiConfig.baseUrl}/receipt/${r.sale!['pedido_id']}",
                    ).replace(
                      queryParameters: {
                        'code': r.sale!['codigo_publico'].toString(),
                        'store': slug,
                      },
                    );
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              child: const Text('Abrir comprobante de la tienda'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
