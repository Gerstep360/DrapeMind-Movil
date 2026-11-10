import 'dart:math';
import 'package:flutter/material.dart';
import 'package:drapemind_mobile/core/theme/app_colors.dart';
import 'package:drapemind_mobile/core/network/api_exception.dart';
import 'package:drapemind_mobile/segundo_parcial/cu24_pedidos/cu24_order_models.dart';
import 'package:drapemind_mobile/segundo_parcial/cu24_pedidos/cu24_order_service.dart';
import 'package:drapemind_mobile/segundo_parcial/cu13_catalogo_offline/cu13_offline_service.dart';

class ExchangeSheet extends StatefulWidget {
  final Order order;
  final OrderService orderService;
  final OfflineService? offline;
  final VoidCallback onConfirmed;

  const ExchangeSheet({
    super.key,
    required this.order,
    required this.orderService,
    this.offline,
    required this.onConfirmed,
  });

  @override
  State<ExchangeSheet> createState() => _ExchangeSheetState();
}

class _ExchangeSheetState extends State<ExchangeSheet> {
  bool _isLoading = true;
  bool _isBusy = false;
  String? _errorMessage;
  Map<String, dynamic>? _orderData;

  // Items seleccionados para devolver: item_pedido_id -> cantidad
  final Map<int, int> _returns = {};

  // Prendas nuevas elegidas para cambio
  bool _wantNewGarment = false;
  int _selectedVariantId = 0;
  final List<Map<String, dynamic>> _newLines = [];

  final TextEditingController _noteCtrl = TextEditingController(
    text: 'Cambio o devolución de prenda',
  );

  Map<String, dynamic>? _quote;

  String _uuid() {
    final random = Random.secure();
    final b = List<int>.generate(16, (_) => random.nextInt(256));
    b[6] = (b[6] & 15) | 64;
    b[8] = (b[8] & 63) | 128;
    final s = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
  }

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await widget.orderService.findOrderForExchange(
        widget.order.id.toString(),
      );
      if (!mounted) return;
      setState(() {
        _orderData = res;
        _isLoading = false;
        final items = res['items'] as List? ?? [];
        for (final item in items) {
          final id = item['id'] as int;
          final available = (item['disponible_cambio'] as num?)?.toInt() ?? 0;
          if (available > 0) {
            _returns[id] = 1; // Por defecto devolver 1 unidad
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      String msg = 'No se pudo consultar el pedido para cambio.';
      if (e is ApiException) {
        if (e.details is Map && e.details['detail'] != null) {
          final d = e.details['detail'];
          msg = d is Map ? (d['message'] ?? d.toString()) : d.toString();
        } else {
          msg = e.message;
        }
      }
      setState(() {
        _errorMessage = msg;
        _isLoading = false;
      });
    }
  }

  bool get _hasReturns => _returns.values.any((q) => q > 0);

  Map<String, dynamic> _buildPayload({required bool preview}) {
    final sucursalId = _orderData?['sucursal_id'] ?? widget.order.sucursalId ?? 1;
    final diff = _quote != null ? (num.tryParse(_quote!['diferencia']?.toString() ?? '0') ?? 0) : 0;
    final received = max(0, diff).toStringAsFixed(2);
    final refunded = max(0, -diff).toStringAsFixed(2);

    return {
      'operacion_id': _uuid(),
      'pedido_origen_id': widget.order.id,
      'sucursal_id': sucursalId,
      'motivo': _noteCtrl.text.trim().isEmpty ? 'Cambio o devolución' : _noteCtrl.text.trim(),
      'devoluciones': _returns.entries
          .where((e) => e.value > 0)
          .map((e) => {'item_pedido_id': e.key, 'cantidad': e.value})
          .toList(),
      'prendas_nuevas': _newLines.map((l) => {
        'variante_id': l['variante_id'],
        'cantidad': l['cantidad'],
      }).toList(),
      'efectivo_recibido': received,
      'efectivo_devuelto': refunded,
    };
  }

  Future<void> _calculateQuote() async {
    if (!_hasReturns) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos una prenda para devolver.')),
      );
      return;
    }

    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });

    try {
      final payload = _buildPayload(preview: true);
      final res = await widget.orderService.quoteExchange(payload);
      if (!mounted) return;
      setState(() {
        _quote = res;
        _isBusy = false;
      });
    } catch (e) {
      if (!mounted) return;
      String msg = 'No se pudo calcular la diferencia.';
      if (e is ApiException) {
        if (e.details is Map && e.details['detail'] != null) {
          final d = e.details['detail'];
          msg = d is Map ? (d['message'] ?? d.toString()) : d.toString();
        } else {
          msg = e.message;
        }
      }
      setState(() {
        _errorMessage = msg;
        _isBusy = false;
      });
    }
  }

  Future<void> _confirmOperation() async {
    if (_quote == null) {
      await _calculateQuote();
      if (_quote == null) return;
    }

    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });

    try {
      final payload = _buildPayload(preview: false);
      await widget.orderService.confirmExchange(payload);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onConfirmed();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.ink,
          content: Text(
            _newLines.isEmpty
                ? '¡Devolución y reembolso confirmados correctamente!'
                : '¡Cambio de prenda confirmado con éxito!',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      String msg = 'No se pudo procesar la operación.';
      if (e is ApiException) {
        if (e.details is Map && e.details['detail'] != null) {
          final d = e.details['detail'];
          msg = d is Map ? (d['message'] ?? d.toString()) : d.toString();
        } else {
          msg = e.message;
        }
      }
      setState(() {
        _errorMessage = msg;
        _isBusy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final variants = widget.offline?.bundle?.variants ?? [];
    final products = widget.offline?.bundle?.products ?? [];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.paperDark,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.swap_horiz, color: AppColors.ink, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cambio o Devolución · Pedido #${widget.order.id}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        'Total compra: Bs ${widget.order.total.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 24),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.dangerBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.danger,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (!_isLoading && _orderData != null) ...[
              // Sección 1: Prendas a devolver
              const Text(
                '1. Prendas a devolver',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              ...((_orderData!['items'] as List? ?? []).map((item) {
                final id = item['id'] as int;
                final available = (item['disponible_cambio'] as num?)?.toInt() ?? 0;
                final qty = _returns[id] ?? 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.paperDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: qty > 0 ? AppColors.ink : AppColors.line,
                      width: qty > 0 ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${item['nombre']} · ${item['talla']} · ${item['color']}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Crédito: Bs ${item['credito_unitario']} · Disp: $available unid.',
                              style: const TextStyle(fontSize: 11, color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                      if (available > 0)
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, size: 20),
                              onPressed: qty > 0
                                  ? () => setState(() {
                                        _returns[id] = qty - 1;
                                        _quote = null;
                                      })
                                  : null,
                            ),
                            Text(
                              '$qty',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, size: 20),
                              onPressed: qty < available
                                  ? () => setState(() {
                                        _returns[id] = qty + 1;
                                        _quote = null;
                                      })
                                  : null,
                            ),
                          ],
                        )
                      else
                        const Text(
                          'Ya cambiada',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.danger,
                          ),
                        ),
                    ],
                  ),
                );
              })),
              const SizedBox(height: 12),

              // Sección 2: ¿Quieres llevar otra prenda o solo reembolso?
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: !_wantNewGarment ? AppColors.lime : AppColors.paperDark,
                        side: BorderSide(
                          color: !_wantNewGarment ? AppColors.ink : AppColors.line,
                          width: !_wantNewGarment ? 1.8 : 1.0,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => setState(() {
                        _wantNewGarment = false;
                        _newLines.clear();
                        _quote = null;
                      }),
                      child: const Text(
                        'Solo Devolución\n(Reembolso)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _wantNewGarment ? AppColors.lime : AppColors.paperDark,
                        side: BorderSide(
                          color: _wantNewGarment ? AppColors.ink : AppColors.line,
                          width: _wantNewGarment ? 1.8 : 1.0,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => setState(() {
                        _wantNewGarment = true;
                        _quote = null;
                      }),
                      child: const Text(
                        'Cambiar prenda\n(Otra talla / modelo)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Selector de nueva prenda si eligió cambio
              if (_wantNewGarment) ...[
                const Text(
                  '2. Selecciona la nueva prenda',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.paperDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: _selectedVariantId == 0 ? null : _selectedVariantId,
                      hint: const Text('Elige una variante disponible'),
                      items: variants.map((v) {
                        final vid = (v['id'] as num).toInt();
                        final prodId = (v['producto_id'] as num?)?.toInt();
                        final p = products.cast<Map<String, dynamic>?>().firstWhere(
                              (prod) => (prod?['id'] as num?)?.toInt() == prodId,
                              orElse: () => null,
                            );
                        final name = p != null
                            ? '${p['nombre']} · ${v['talla']} · ${v['color']} (Bs ${p['precio']})'
                            : 'Variante $vid · ${v['talla']} · ${v['color']}';
                        return DropdownMenuItem<int>(
                          value: vid,
                          child: Text(name, style: const TextStyle(fontSize: 12)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedVariantId = val;
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.ink,
                        foregroundColor: AppColors.paper,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Añadir prenda nueva', style: TextStyle(fontSize: 12)),
                      onPressed: _selectedVariantId == 0
                          ? null
                          : () {
                              final v = variants.firstWhere(
                                (varItem) => (varItem['id'] as num).toInt() == _selectedVariantId,
                              );
                              final prodId = (v['producto_id'] as num?)?.toInt();
                              final p = products.cast<Map<String, dynamic>?>().firstWhere(
                                    (prod) => (prod?['id'] as num?)?.toInt() == prodId,
                                    orElse: () => null,
                                  );
                              setState(() {
                                final existing = _newLines.indexWhere(
                                  (l) => l['variante_id'] == _selectedVariantId,
                                );
                                if (existing >= 0) {
                                  _newLines[existing]['cantidad'] += 1;
                                } else {
                                  _newLines.add({
                                    'variante_id': _selectedVariantId,
                                    'cantidad': 1,
                                    'name': p != null ? '${p['nombre']} (${v['talla']})' : 'Prenda #${v['id']}',
                                    'precio': p?['precio'] ?? 0,
                                  });
                                }
                                _quote = null;
                              });
                            },
                    ),
                  ],
                ),
                if (_newLines.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ..._newLines.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final line = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.paperDark,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${line['cantidad']} × ${line['name']}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                            onPressed: () => setState(() {
                              _newLines.removeAt(idx);
                              _quote = null;
                            }),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 12),
              ],

              // Motivo
              TextField(
                controller: _noteCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Motivo del cambio o devolución',
                  hintText: 'Talla inadecuada, defecto, preferencia de color…',
                  filled: true,
                  fillColor: AppColors.paperDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.line),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Botón de Cotización
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: AppColors.ink, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isBusy || !_hasReturns ? null : _calculateQuote,
                  child: Text(
                    _wantNewGarment && _newLines.isNotEmpty
                        ? 'Calcular diferencia de precios'
                        : 'Calcular reembolso de devolución',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ),

              // Resumen de la cotización
              if (_quote != null) ...[
                const SizedBox(height: 14),
                Builder(builder: (context) {
                  final diff = num.tryParse(_quote!['diferencia']?.toString() ?? '0') ?? 0;
                  final credit = num.tryParse(_quote!['credito']?.toString() ?? '0') ?? 0;
                  final totalNew = num.tryParse(_quote!['total_nuevo']?.toString() ?? '0') ?? 0;

                  Color boxBg = AppColors.paperDark;
                  Color boxBorder = AppColors.line;
                  String title = 'Cambio sin diferencia: Bs 0.00';
                  String subtitle = 'Prendas de igual valor económico.';

                  if (diff < 0) {
                    boxBg = AppColors.successBg;
                    boxBorder = AppColors.success.withValues(alpha: 0.5);
                    title = 'Reembolso a tu favor: Bs ${(-diff).toStringAsFixed(2)}';
                    subtitle = 'Sobra dinero por devolver. Te reembolsamos la diferencia.';
                  } else if (diff > 0) {
                    boxBg = AppColors.warningBg;
                    boxBorder = AppColors.warning.withValues(alpha: 0.5);
                    title = 'Diferencia a abonar: Bs ${diff.toStringAsFixed(2)}';
                    subtitle = 'La nueva prenda tiene mayor valor. Debes abonar la diferencia.';
                  }

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: boxBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: boxBorder, width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                        const Divider(height: 16),
                        Text(
                          'Crédito por prendas devueltas: Bs ${credit.toStringAsFixed(2)}\nPrendas nuevas: Bs ${totalNew.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.ink),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: AppColors.ink,
                      foregroundColor: AppColors.paper,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isBusy ? null : _confirmOperation,
                    child: Text(
                      _wantNewGarment && _newLines.isNotEmpty
                          ? 'Confirmar cambio de prendas'
                          : 'Confirmar devolución y reembolso',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

