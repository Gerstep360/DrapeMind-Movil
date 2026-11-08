import '../compartido/voice_input_button.dart';
import 'package:flutter/material.dart';
import 'package:drapemind_mobile/core/network/api_client.dart';
import 'package:drapemind_mobile/core/network/api_exception.dart';
import 'package:drapemind_mobile/core/theme/app_colors.dart';
import 'package:drapemind_mobile/segundo_parcial/cu25_reportes_voz/cu25_native_actions.dart';

class ReportsScreen extends StatefulWidget {
  final ApiClient? api;
  final NativeActions? actions;
  const ReportsScreen({super.key, this.api, this.actions});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late final ApiClient _api = widget.api ?? ApiClient();
  late final NativeActions _actions = widget.actions ?? NativeActions();
  final _query = TextEditingController();
  bool _busy = false, _voiceBusy = false;
  String _error = '', _entry = 'TEXTO';
  List<Map<String, dynamic>> _history = [];
  Map<String, dynamic>? _report;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  String message(Object e) => e is ApiException
      ? e.message
      : 'No se pudo completar la acción. Puedes reintentar.';
  Future<void> _load() async {
    try {
      final rows = await _api.get('/business-reports');
      if (mounted) {
        setState(
          () => _history = (rows as List)
              .map((r) => Map<String, dynamic>.from(r))
              .toList(),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = message(e));
    }
  }

  Future<void> _generate() async {
    if (_busy || _voiceBusy || _query.text.trim().length < 5) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final result = await _api.post(
        '/business-reports',
        body: {'consulta': _query.text.trim(), 'entrada': _entry},
        timeout: const Duration(seconds: 90),
      );
      if (mounted) {
        setState(() {
          _report = Map<String, dynamic>.from(result);
          _history = [_report!, ..._history];
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _download() async {
    final row = _report;
    if (row == null || _busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _api.getBytes(
        '/business-reports/${row['id']}/pdf',
        headers: {'Accept': 'application/pdf'},
      );
      final saved = await _actions.savePdf('reporte-${row['id']}.pdf', bytes);
      if (saved && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Reporte guardado.')));
      }
    } catch (e) {
      if (mounted) setState(() => _error = message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _report;
    final data = r?['datos'] as Map?;
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('Reportes de tu negocio')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Pregunta por tus ventas o inventario',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _query,
              minLines: 3,
              maxLines: 5,
              maxLength: 1000,
              onChanged: (_) => _entry = 'TEXTO',
              decoration: const InputDecoration(
                labelText: '¿Qué necesitas conocer?',
                hintText: '¿Cómo van las ventas de este mes?',
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                VoiceInputButton(
                  api: _api,
                  purpose: 'REPORTE',
                  label: 'Dictar consulta',
                  disabled: _busy,
                  onBusy: (value) {
                    if (mounted) setState(() => _voiceBusy = value);
                  },
                  onText: (text) {
                    setState(() {
                      _query.text = [
                        _query.text.trim(),
                        text,
                      ].where((v) => v.isNotEmpty).join(' ');
                      _entry = 'VOZ';
                    });
                  },
                ),
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () {
                          _query.text =
                              'Revisa el inventario actual y el stock bajo';
                          _entry = 'TEXTO';
                        },
                  child: const Text('Revisar inventario'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Puedes pedir hoy, ayer, esta semana, este mes o últimos N días. Por defecto se usan los últimos 30 días. El inventario es actual.',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy || _voiceBusy ? null : _generate,
              child: Text(_busy ? 'Preparando reporte…' : 'Generar reporte'),
            ),
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _error,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
            if (r != null && data != null) ...[
              const Divider(height: 40),
              Text(
                data['empresa'].toString(),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                r['titulo'].toString(),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text('${data['desde']} — ${data['hasta']} · ${data['sucursal']}'),
              const SizedBox(height: 16),
              _metric(
                'Ingreso neto cobrado',
                'Bs ${data['ingreso_neto_cobrado']}',
              ),
              _metric('Pedidos pagados', '${data['pedidos_pagados']}'),
              _metric(
                'Unidades disponibles ahora',
                '${data['inventario_actual']['unidades_disponibles']}',
              ),
              const SizedBox(height: 16),
              Text(
                r['analisis'].toString(),
                style: const TextStyle(height: 1.6),
              ),
              const SizedBox(height: 16),
              const Text(
                'Acciones sugeridas',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              for (final item in (r['recomendaciones'] as List))
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(item.toString()),
                ),
              const SizedBox(height: 16),
              Text(
                data['alcance'].toString(),
                style: const TextStyle(fontSize: 12),
              ),
              OutlinedButton(
                onPressed: _busy ? null : _download,
                child: const Text('Descargar PDF'),
              ),
            ],
            if (_history.isNotEmpty) ...[
              const Divider(height: 40),
              const Text(
                'Reportes guardados',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              for (final row in _history)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(row['titulo'].toString()),
                  subtitle: Text(
                    '${row['datos']['desde']} — ${row['datos']['hasta']}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => setState(() => _report = row),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}
