import 'package:flutter/material.dart';
import 'package:drapemind_mobile/core/network/api_client.dart';
import 'package:drapemind_mobile/core/network/api_exception.dart';
import 'package:drapemind_mobile/core/theme/app_colors.dart';

class BusinessDashboardScreen extends StatefulWidget {
  final ApiClient? api;
  const BusinessDashboardScreen({super.key, this.api});
  @override
  State<BusinessDashboardScreen> createState() =>
      _BusinessDashboardScreenState();
}

class _BusinessDashboardScreenState extends State<BusinessDashboardScreen> {
  late final _api = widget.api ?? ApiClient();
  Map<String, dynamic>? _data;
  String? _error;
  int _days = 30;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await _api.get(
        '/business-dashboard',
        queryParams: {'days': _days},
      );
      if (mounted) setState(() => _data = Map<String, dynamic>.from(result));
    } catch (e) {
      if (mounted) {
        setState(() {
          _data = null;
          _error = e is ApiException
              ? e.message
              : 'No se pudieron consultar tus indicadores.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      appBar: AppBar(title: const Text('Tu negocio', maxLines: 1)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'El pulso de tu tienda',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: _days,
              decoration: const InputDecoration(labelText: 'Periodo'),
              items: [7, 30, 90]
                  .map(
                    (days) => DropdownMenuItem(
                      value: days,
                      child: Text('Últimos $days días'),
                    ),
                  )
                  .toList(),
              onChanged: _busy
                  ? null
                  : (days) {
                      if (days != null) {
                        _days = days;
                        _load();
                      }
                    },
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
              TextButton(onPressed: _load, child: const Text('Reintentar')),
            ],
            if (data != null) ...[
              const SizedBox(height: 20),
              Text('${data['empresa']} · ${data['sucursal']}'),
              Text('${data['desde']} — ${data['hasta']}'),
              const SizedBox(height: 20),
              for (final metric in [
                [
                  'Ingreso neto cobrado',
                  'Bs ${(double.tryParse('${data['ingreso_neto_cobrado']}') ?? 0).toStringAsFixed(2)}',
                ],
                ['Pedidos pagados', '${data['pedidos_pagados']}'],
                [
                  'Unidades disponibles ahora',
                  '${data['inventario_actual']['unidades_disponibles']}',
                ],
                [
                  'Variantes con stock bajo',
                  '${data['inventario_actual']['variantes_con_stock_bajo']}',
                ],
              ])
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(metric[0]),
                        Text(
                          metric[1],
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              Text(
                'Prendas vendidas',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if ((data['prendas_vendidas'] as List).isEmpty)
                const Text('Todavía no hay ventas pagadas en este periodo.'),
              for (final item in data['prendas_vendidas'])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${item['nombre']}'),
                  trailing: Text('${item['cantidad']}'),
                ),
              const SizedBox(height: 20),
              Text(
                '${data['alcance']}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
