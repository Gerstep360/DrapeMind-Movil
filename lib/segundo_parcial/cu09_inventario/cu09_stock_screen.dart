import 'package:flutter/material.dart';
import 'package:drapemind_mobile/core/network/api_client.dart';
import 'package:drapemind_mobile/core/network/api_exception.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryState();
}

class _InventoryState extends State<InventoryScreen> {
  final api = ApiClient();
  List<Map<String, dynamic>> branches = [], stock = [];
  int? branch;
  bool busy = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (branches.isEmpty) {
        final data = await api.get('/branches/staff/assigned');
        branches = (data as List)
            .map((v) => Map<String, dynamic>.from(v))
            .toList();
        branch = branches.firstOrNull?['id'];
      }
      if (branch != null) {
        final data = await api.get(
          '/branches/$branch/availability',
          queryParams: {'con_stock': false},
        );
        stock = (data as List)
            .map((v) => Map<String, dynamic>.from(v))
            .toList();
      }
    } catch (e) {
      error = e is ApiException
          ? e.message
          : 'No pudimos consultar las existencias.';
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> adjust(Map<String, dynamic> row) async {
    final quantity = TextEditingController(text: '${row['stock_total']}'),
        reason = TextEditingController();
    var saving = false;
    String? failure;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, change) => AlertDialog(
          title: Text('${row['producto']} · ${row['talla']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Hay ${row['stock_reservado']} unidades reservadas. El total debe incluirlas.',
                ),
                TextField(
                  controller: quantity,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Total físico contado',
                  ),
                ),
                TextField(
                  controller: reason,
                  decoration: const InputDecoration(
                    labelText: 'Motivo del ajuste',
                  ),
                ),
                if (failure != null)
                  Text(failure!, style: const TextStyle(color: Colors.red)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final value = int.tryParse(quantity.text);
                      if (value == null ||
                          value < (row['stock_reservado'] as num) ||
                          reason.text.trim().length < 3) {
                        change(
                          () => failure =
                              'Revisa la cantidad y explica el motivo.',
                        );
                        return;
                      }
                      change(() => saving = true);
                      try {
                        await api.post(
                          '/admin/inventory/adjustments',
                          body: {
                            'sucursal_id': branch,
                            'variante_id': row['variante_id'],
                            'nuevo_stock_total': value,
                            'observacion': reason.text.trim(),
                            'tipo': 'AJUSTE',
                          },
                        );
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        change(() {
                          failure = e is ApiException
                              ? e.message
                              : 'No pudimos guardar el ajuste.';
                          saving = false;
                        });
                      }
                    },
              child: Text(saving ? 'Guardando…' : 'Guardar ajuste'),
            ),
          ],
        ),
      ),
    );
    quantity.dispose();
    reason.dispose();
    if (mounted) load();
  }

  Future<void> addVariant() async {
    if (branch == null) return;
    try {
      final data = await api.get('/admin/variants');
      if (!mounted) return;
      final rows = (data as List)
          .map((v) => Map<String, dynamic>.from(v))
          .toList();
      int? selected;
      final choice = await showDialog<int>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, change) => AlertDialog(
            title: const Text('Agregar existencias'),
            content: DropdownButtonFormField<int>(
              value: selected,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Prenda, talla y color',
              ),
              items: rows
                  .map(
                    (v) => DropdownMenuItem<int>(
                      value: v['id'],
                      child: Text(
                        '${v['sku']} · ${v['talla']} · ${v['color']}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => change(() => selected = v),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: selected == null
                    ? null
                    : () => Navigator.pop(context, selected),
                child: const Text('Continuar'),
              ),
            ],
          ),
        ),
      );
      if (choice == null || !mounted) return;
      final variant = rows.firstWhere((v) => v['id'] == choice);
      final current = stock
          .where((s) => s['variante_id'] == choice)
          .firstOrNull;
      await adjust(
        current ??
            {
              'variante_id': choice,
              'producto': variant['sku'],
              'talla': variant['talla'],
              'stock_total': 0,
              'stock_reservado': 0,
            },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is ApiException
                  ? e.message
                  : 'No pudimos cargar las variantes.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Inventario'),
      actions: [
        IconButton(
          tooltip: 'Agregar existencias',
          onPressed: busy ? null : addVariant,
          icon: const Icon(Icons.add),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          DropdownButtonFormField<int>(
            value: branch,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Sucursal'),
            items: branches
                .map(
                  (b) => DropdownMenuItem<int>(
                    value: b['id'],
                    child: Text(b['nombre']),
                  ),
                )
                .toList(),
            onChanged: busy
                ? null
                : (v) {
                    branch = v;
                    load();
                  },
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (error != null) ...[
            Text(error!),
            TextButton(onPressed: load, child: const Text('Reintentar')),
          ],
          if (!busy && stock.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Esta sucursal todavía no tiene existencias registradas.',
              ),
            ),
          for (final row in stock)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              title: Text('${row['producto']}'),
              subtitle: Text(
                '${row['talla']} · ${row['color']}\n${row['stock_disponible']} disponibles · ${row['stock_reservado']} reservadas',
              ),
              trailing: IconButton(
                tooltip: 'Ajustar existencias',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => adjust(row),
              ),
            ),
        ],
      ),
    ),
  );
}
