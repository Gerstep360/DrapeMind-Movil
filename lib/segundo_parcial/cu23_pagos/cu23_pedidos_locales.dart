import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drapemind_mobile/core/network/api_exception.dart';
import 'cu23_deferred_service.dart';

class PendingOrderCards extends StatelessWidget {
  final Set<int> existingIds;
  const PendingOrderCards({super.key, this.existingIds = const {}});
  @override
  Widget build(BuildContext context) {
    final queue = context.watch<DeferredService?>();
    if (queue == null) return const SizedBox.shrink();
    final rows = queue.purchases
        .where(
          (row) =>
              !(queue.state(row) == 'PAGADA' &&
                  existingIds.contains(row['remote']?['pedido_id'])),
        )
        .toList();
    return Column(
      children: [
        for (final row in rows)
          _PendingCard(key: ValueKey(row['operation']), row: row, queue: queue),
      ],
    );
  }
}

class _PendingCard extends StatefulWidget {
  final Map<String, dynamic> row;
  final DeferredService queue;
  const _PendingCard({super.key, required this.row, required this.queue});
  @override
  State<_PendingCard> createState() => _PendingCardState();
}

class _PendingCardState extends State<_PendingCard> {
  bool busy = false;
  String? error;
  int? card;
  Future<void> action(String type) async {
    if (busy) return;
    if (type == 'card' || type == 'save') {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            type == 'save'
                ? 'Guardar tarjeta en Stripe'
                : 'Autorizar este pago',
          ),
          content: Text(
            type == 'save'
                ? 'La tarjeta quedará guardada en Stripe. Solo se cobrarán las compras cuyo importe autorices.'
                : '¿Autorizas un único cobro de Bs ${widget.row['remote']?['total_autorizado'] ?? widget.row['body']?['total_autorizado']} con la tarjeta elegida?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Ahora no'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                type == 'save' ? 'Guardar tarjeta' : 'Autorizar pago',
              ),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted) return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (type == 'cancel') {
        await widget.queue.cancel(widget.row);
      } else if (type == 'card' && card != null) {
        await widget.queue.chooseCard(widget.row, card!);
      } else if (type == 'save') {
        await widget.queue.saveCard(true);
      } else if (type == 'bank') {
        await widget.queue.authenticate(widget.row);
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is ApiException
              ? e.message
              : 'No pudimos completar esta acción. Puedes continuar con tu pedido al recuperar conexión.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row, queue = widget.queue, state = queue.state(row);
    final methods = queue.rows('cards');
    final selected = methods.any((m) => m['id'] == card) ? card : null;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              DeferredService.label(state),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: state == 'PAGADA' ? Colors.green.shade800 : null,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              row['label'] ?? 'Compra de esta tienda',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Bs ${row['remote']?['total_autorizado'] ?? row['body']?['total_autorizado'] ?? ""}',
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              row['remote']?['mensaje'] ??
                  'Guardada en este dispositivo. Comprobaremos disponibilidad y pago al recuperar conexión.',
            ),
            if (state == 'REQUIERE_METODO') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: selected,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Tarjeta para este pedido',
                ),
                items: [
                  for (final method in methods)
                    DropdownMenuItem<int>(
                      value: method['id'],
                      child: Text(
                        '${method['marca']} ···· ${method['ultimos_cuatro']}',
                      ),
                    ),
                ],
                onChanged: busy
                    ? null
                    : (value) => setState(() => card = value),
              ),
              TextButton(
                onPressed: busy || !queue.online ? null : () => action('save'),
                child: const Text('Guardar otra tarjeta con Stripe'),
              ),
              FilledButton(
                onPressed: busy || !queue.online || selected == null
                    ? null
                    : () => action('card'),
                child: const Text('Autorizar pago'),
              ),
            ],
            if (state == 'REQUIERE_AUTENTICACION')
              FilledButton(
                onPressed: busy || !queue.online ? null : () => action('bank'),
                child: const Text('Verificar con mi banco'),
              ),
            if (!queue.terminal(row))
              TextButton(
                onPressed: busy ? null : () => action('cancel'),
                child: const Text('Cancelar compra'),
              ),
            if (busy) const LinearProgressIndicator(),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    );
  }
}
