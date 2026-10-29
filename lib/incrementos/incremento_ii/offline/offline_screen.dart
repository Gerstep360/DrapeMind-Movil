import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:provider/provider.dart';
import 'package:drapemind_mobile/core/config/api_config.dart';
import 'package:drapemind_mobile/core/network/api_exception.dart';
import 'package:drapemind_mobile/core/theme/app_colors.dart';
import 'package:drapemind_mobile/paquetes/reservas_atencion_tienda/consultar_qr_cancelar_reserva/presentacion/reservations_screen.dart';
import 'offline_service.dart';
import 'models.dart';

class OfflineScreen extends StatefulWidget {
  const OfflineScreen({super.key});
  @override
  State<OfflineScreen> createState() => _OfflineScreenState();
}

class _OfflineScreenState extends State<OfflineScreen> {
  String _search = '', _size = '', _color = '';
  int _branch = 0;
  String date(String value) {
    final d = DateTime.parse(value).toLocal();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<OfflineService>(),
        bundle = context.watch<OfflineService>().bundle;
    final variants = bundle?.variants ?? <Map<String, dynamic>>[];
    final sizes = variants.map((v) => v['talla'] as String).toSet().toList()
      ..sort();
    final colors = variants.map((v) => v['color'] as String).toSet().toList()
      ..sort();
    if (!sizes.contains(_size)) _size = '';
    if (!colors.contains(_color)) _color = '';
    if (bundle?.branches.any((b) => b['id'] == _branch) != true) _branch = 0;
    final products = (bundle?.products ?? <Map<String, dynamic>>[])
        .where(
          (p) =>
              p['nombre'].toString().toLowerCase().contains(
                _search.toLowerCase(),
              ) &&
              variants.any(
                (v) =>
                    v['producto_id'] == p['id'] &&
                    (_size.isEmpty || v['talla'] == _size) &&
                    (_color.isEmpty || v['color'] == _color) &&
                    (_branch == 0 || service.available(v['id'], _branch) > 0),
              ),
        )
        .toList();
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('Sin conexión')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Tu tienda contigo',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                  ),
                ),
                Icon(
                  service.online ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                ),
                const SizedBox(width: 7),
                Text(service.online ? 'Con señal' : 'Sin señal'),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.limeSoft,
                border: Border.all(color: AppColors.ink),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    bundle?.tenantName ?? 'Prepara tu próxima visita',
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    bundle == null
                        ? 'Guarda prendas, tallas, colores y disponibilidad para elegir incluso sin Internet.'
                        : '${bundle.products.length} prendas guardadas · Actualizado ${date(bundle.data['downloaded_at'])}',
                  ),
                  if (bundle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Disponible hasta ${date(bundle.data['valid_until'])}. La tienda comprobará el precio y el stock al enviar.',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: service.downloading ? null : service.download,
                    icon: Icon(
                      service.downloading
                          ? Icons.downloading
                          : Icons.download_for_offline_outlined,
                    ),
                    label: Text(
                      service.downloading
                          ? service.phase
                          : bundle == null
                          ? 'Guardar catálogo'
                          : 'Actualizar descarga',
                    ),
                  ),
                  if (service.downloading)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: LinearProgressIndicator(),
                    ),
                ],
              ),
            ),
            if (service.message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(service.message, semanticsLabel: service.message),
              ),
            if (bundle != null && !service.usable)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Esta descarga o tu sesión necesitan actualizarse. Conéctate antes de guardar nuevas solicitudes.',
                ),
              ),
            if (service.usable) ...[
              const SizedBox(height: 22),
              const Text(
                'Tu colección guardada',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Buscar una prenda',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => _search = value),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _size,
                      decoration: const InputDecoration(labelText: 'Talla'),
                      items: [
                        const DropdownMenuItem(value: '', child: Text('Todas')),
                        ...sizes.map(
                          (s) => DropdownMenuItem(value: s, child: Text(s)),
                        ),
                      ],
                      onChanged: (v) => setState(() => _size = v ?? ''),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _color,
                      decoration: const InputDecoration(labelText: 'Color'),
                      items: [
                        const DropdownMenuItem(value: '', child: Text('Todos')),
                        ...colors.map(
                          (s) => DropdownMenuItem(value: s, child: Text(s)),
                        ),
                      ],
                      onChanged: (v) => setState(() => _color = v ?? ''),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                isExpanded: true,
                value: _branch,
                decoration: const InputDecoration(labelText: 'Sucursal'),
                items: [
                  const DropdownMenuItem(
                    value: 0,
                    child: Text('Todas las sucursales'),
                  ),
                  ...bundle!.branches.map(
                    (b) => DropdownMenuItem<int>(
                      value: b['id'],
                      child: Text(
                        '${b['nombre']} · ${b['ciudad']}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _branch = v ?? 0),
              ),
              const SizedBox(height: 18),
              if (products.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No hay prendas con esos filtros. Prueba otra talla o sucursal.',
                  ),
                ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = (constraints.maxWidth - 12) / 2;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: products
                        .map(
                          (p) => SizedBox(
                            width: width,
                            child: _product(p, service),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
            const SizedBox(height: 30),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Tus solicitudes',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Enviar y comprobar solicitudes',
                  onPressed: service.syncing ? null : service.checkConnection,
                  icon: const Icon(Icons.sync),
                ),
              ],
            ),
            const Text(
              'Una solicitud guardada no garantiza stock. El QR estará disponible cuando la tienda reciba la reserva.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (service.queue.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('Las prendas que elijas aparecerán aquí.'),
              ),
            ...service.queue.map((r) => _request(r, service)),
          ],
        ),
      ),
    );
  }

  Widget _product(Map<String, dynamic> product, OfflineService service) {
    final images = (product['imagenes'] as List?) ?? [];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.lineStrong),
        borderRadius: BorderRadius.circular(5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 135,
            child: images.isEmpty
                ? const ColoredBox(
                    color: AppColors.paperDark,
                    child: Icon(
                      Icons.checkroom_outlined,
                      size: 38,
                      color: AppColors.textMuted,
                    ),
                  )
                : FutureBuilder<Uint8List?>(
                    future: service.photo(images.first.toString()),
                    builder: (context, snapshot) {
                      const fallback = ColoredBox(
                        color: AppColors.paperDark,
                        child: Icon(
                          Icons.checkroom_outlined,
                          size: 38,
                          color: AppColors.textMuted,
                        ),
                      );
                      if (snapshot.data != null) {
                        return Image.memory(
                          snapshot.data!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, e, s) => fallback,
                        );
                      }
                      if (!service.online) return fallback;
                      return Image.network(
                        ApiConfig.resolveMediaUrl(images.first.toString()),
                        fit: BoxFit.cover,
                        errorBuilder: (_, e, s) => fallback,
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  product['nombre'],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Bs ${(num.tryParse(product['precio'].toString()) ?? 0).toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => _reserve(product, service),
                  child: const Text('Elegir'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _request(OfflineRequest record, OfflineService service) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: record.state == 'CONFLICT'
          ? const Color(0xfffff0d4)
          : AppColors.white,
      border: Border.all(color: AppColors.lineStrong),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          record.label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 7),
        Text(record.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        Text(
          '${record.branch} · ${(record.body['items'] as List).first['cantidad']} unidad(es)',
        ),
        if (record.message != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(record.message!, style: const TextStyle(fontSize: 12)),
          ),
        if (record.reservation != null)
          Text(
            'Código ${record.reservation!['codigo_publico'].toString().substring(0, 8)} · ${record.reservation!['estado']}',
            style: const TextStyle(fontSize: 12),
          ),
        Wrap(
          spacing: 8,
          children: [
            if (record.state == 'CONFLICT')
              TextButton(
                onPressed: service.syncing ? null : () => service.retry(record),
                child: const Text('Volver a intentar'),
              ),
            if (record.kind == 'RESERVATION' &&
                ['PENDING', 'CONFLICT'].contains(record.state))
              TextButton(
                onPressed: service.syncing
                    ? null
                    : () => service.cancel(record),
                child: const Text('Cancelar solicitud'),
              ),
            if (record.state == 'CONFIRMED' && record.kind == 'RESERVATION')
              TextButton(
                onPressed: service.online
                    ? () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ReservationsScreen(),
                        ),
                      )
                    : null,
                child: const Text('Ver reserva y QR'),
              ),
          ],
        ),
      ],
    ),
  );
  Future<void> _reserve(
    Map<String, dynamic> product,
    OfflineService service,
  ) async {
    final variants = service.bundle!.variants
            .where((v) => v['producto_id'] == product['id'])
            .toList(),
        branches = service.bundle!.branches;
    if (variants.isEmpty || branches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No hay tallas o sucursales autorizadas para esta prenda.',
          ),
        ),
      );
      return;
    }
    var variant = variants.first['id'] as int,
        branch = _branch > 0 ? _branch : branches.first['id'] as int,
        quantity = 1;
    var saving = false;
    String? error;
    final form = GlobalKey<FormState>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            24,
            20,
            24 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  product['nombre'],
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  value: variant,
                  decoration: const InputDecoration(labelText: 'Talla y color'),
                  items: variants
                      .map(
                        (v) => DropdownMenuItem<int>(
                          value: v['id'],
                          child: Text('${v['talla']} · ${v['color']}'),
                        ),
                      )
                      .toList(),
                  onChanged: saving
                      ? null
                      : (value) => setModal(() => variant = value!),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  value: branch,
                  decoration: const InputDecoration(labelText: 'Sucursal'),
                  items: branches
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
                  onChanged: saving
                      ? null
                      : (value) => setModal(() => branch = value!),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  initialValue: '1',
                  decoration: const InputDecoration(labelText: 'Cantidad'),
                  keyboardType: TextInputType.number,
                  enabled: !saving,
                  onChanged: (v) => quantity = int.tryParse(v) ?? 0,
                  validator: (v) {
                    final n = int.tryParse(v ?? '') ?? 0;
                    return n < 1 || n > 100
                        ? 'Elige entre 1 y 100 unidades'
                        : null;
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    '${service.available(variant, branch)} unidades en la copia guardada. La tienda confirmará el stock cuando se envíe la solicitud.',
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text(
                      error!,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!form.currentState!.validate()) return;
                          setModal(() => saving = true);
                          try {
                            await service.reserve(variant, branch, quantity);
                            if (ctx.mounted) Navigator.pop(ctx);
                          } on ApiException catch (e) {
                            if (ctx.mounted) {
                              setModal(() {
                                error = e.message;
                                saving = false;
                              });
                            }
                          } catch (_) {
                            if (ctx.mounted) {
                              setModal(() {
                                error =
                                    'No se pudo guardar. Revisa el almacenamiento del dispositivo.';
                                saving = false;
                              });
                            }
                          }
                        },
                  child: Text(saving ? 'Guardando…' : 'Guardar solicitud'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
