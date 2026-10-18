import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drapemind_mobile/core/theme/app_colors.dart';
import 'package:drapemind_mobile/compartido/componentes/altair/altair_message_body.dart';
import 'package:drapemind_mobile/compartido/componentes/productos/dm_product_image.dart';
import 'package:drapemind_mobile/paquetes/carrito_pedidos_pagos/datos/servicios/cart_service.dart';
import 'package:drapemind_mobile/paquetes/catalogo_comercializacion/consultar_detalle_talla_color_variante/presentacion/product_detail_screen.dart';
import 'package:drapemind_mobile/paquetes/carrito_pedidos_pagos/consultar_pedidos_historial_compras/presentacion/orders_screen.dart';
import 'package:drapemind_mobile/paquetes/reservas_atencion_tienda/consultar_qr_cancelar_reserva/presentacion/reservations_screen.dart';
import 'package:drapemind_mobile/paquetes/inteligencia_artificial_asistencia_moda/datos/servicios/ai_socket_service.dart';
import 'package:drapemind_mobile/paquetes/inteligencia_artificial_asistencia_moda/dominio/modelos/ai_models.dart';
import 'package:drapemind_mobile/paquetes/inteligencia_artificial_asistencia_moda/aplicar_recomendacion_carrito/aplicacion/aplicar_recomendacion_carrito.dart';
import 'componentes/altair_composer.dart';
import 'componentes/altair_welcome_state.dart';

class AiStudioScreen extends StatefulWidget {
  const AiStudioScreen({super.key});
  @override
  State<AiStudioScreen> createState() => _AiStudioScreenState();
}

class _AiStudioScreenState extends State<AiStudioScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final Set<String> _actions = {};
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AiSocketService>().connect();
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? prompt]) {
    final text = (prompt ?? _input.text).trim();
    final service = context.read<AiSocketService>();
    if (text.isEmpty || !service.canSend) return;
    service.sendMessage(text);
    _input.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _apply(AiActionItem item) async {
    final key = '${item.accion}-${item.id}';
    if (_actions.contains(key)) return;
    setState(() => _actions.add(key));
    try {
      final result = await AplicarRecomendacionCarrito(
        context.read<CartService>(),
      ).execute(item);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No pudimos actualizar el carrito. Revisa la disponibilidad e intenta de nuevo.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _actions.remove(key));
    }
  }

  void _history() {
    final service = context.read<AiSocketService>();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Tus conversaciones',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
            ),
            for (final session in service.sessions)
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline_rounded),
                title: Text(
                  session.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                selected: session.id == service.currentSession.id,
                onTap: service.isBusy
                    ? null
                    : () {
                        service.switchSession(session.id);
                        Navigator.pop(sheet);
                      },
                trailing: IconButton(
                  tooltip: 'Eliminar conversación',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: service.isBusy
                      ? null
                      : () async {
                          await service.deleteSession(session.id);
                          if (sheet.mounted) Navigator.pop(sheet);
                        },
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AiSocketService>();
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Altair',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Tu asistente de estilo',
              style: TextStyle(fontSize: 11, color: AppColors.textMutedStrong),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Tus conversaciones',
            onPressed: _history,
            icon: const Icon(Icons.history_rounded),
          ),
          IconButton(
            tooltip: 'Nueva conversación',
            onPressed: ai.isBusy ? null : () => ai.createNewSession(),
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ai.messages.isEmpty
                ? AltairWelcomeState(
                    onPrompt: _send,
                    onOpenPreferences: () =>
                        _send('Ayúdame a descubrir mi estilo.'),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                    itemCount: ai.messages.length,
                    itemBuilder: (context, index) =>
                        _message(ai.messages[index]),
                  ),
          ),
          if (ai.isBusy)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  ),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Text(
                      'Altair está preparando tu respuesta…',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMutedStrong,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: ai.cancelGeneration,
                    child: const Text('Detener'),
                  ),
                ],
              ),
            ),
          AltairComposer(
            controller: _input,
            isBusy: !ai.canSend,
            onSend: _send,
            onCancel: ai.cancelGeneration,
            onQuestionnaire: () => _send('Ayúdame a armar un look.'),
          ),
        ],
      ),
    );
  }

  Widget _message(ChatMessage message) {
    final user = message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: user
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (!user)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Altair',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          if (message.content.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxWidth: 580),
              padding: user
                  ? const EdgeInsets.symmetric(horizontal: 16, vertical: 13)
                  : EdgeInsets.zero,
              decoration: user
                  ? BoxDecoration(
                      color: AppColors.ink,
                      borderRadius: BorderRadius.circular(18),
                    )
                  : null,
              child: AltairMessageBody(
                text: message.content,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: user
                      ? AppColors.white
                      : message.error
                      ? AppColors.danger
                      : AppColors.ink,
                ),
              ),
            ),
          for (final notice in message.notices)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                notice.message,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMutedStrong,
                ),
              ),
            ),
          for (final item in message.actionItems)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _product(item),
            ),
          if (message.responseMeta?.productPicker.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final option in message.responseMeta!.productPicker)
                    ActionChip(
                      label: Text(
                        '${option['label'] ?? option['nombre'] ?? 'Ver opción'}',
                      ),
                      onPressed: () {
                        final id = int.tryParse(
                          '${option['id'] ?? option['product_id']}',
                        );
                        if (id != null) {
                          context.read<AiSocketService>().selectProduct(id);
                        }
                      },
                    ),
                ],
              ),
            ),
          if (message.suggestedActions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final suggestion in message.suggestedActions)
                    ActionChip(
                      label: Text(suggestion.label),
                      onPressed: () => _send(suggestion.prompt),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _product(AiActionItem item) {
    final isProduct =
        item.accion == AiActionType.agregar ||
        item.accion == AiActionType.quitar ||
        item.accion == AiActionType.reemplazar;
    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isProduct)
              SizedBox(
                width: 78,
                height: 102,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: DmProductImage(
                    imageUrl: item.fullImageUrl,
                    semanticLabel: item.nombre,
                  ),
                ),
              ),
            if (isProduct) const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Bs ${item.precio.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  if (item.talla != null || item.color != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        [
                          item.talla,
                          item.color,
                        ].whereType<String>().join(' · '),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMutedStrong,
                        ),
                      ),
                    ),
                  const SizedBox(height: 7),
                  if (isProduct)
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ProductDetailScreen(productId: item.id),
                            ),
                          ),
                          child: const Text('Ver prenda'),
                        ),
                        if (item.accion == AiActionType.agregar &&
                                item.varianteId != null ||
                            item.accion == AiActionType.quitar &&
                                item.itemId != null)
                          FilledButton(
                            onPressed:
                                _actions.contains('${item.accion}-${item.id}')
                                ? null
                                : () => _apply(item),
                            child: Text(
                              item.accion == AiActionType.quitar
                                  ? 'Quitar'
                                  : 'Agregar',
                            ),
                          ),
                      ],
                    ),
                  if (item.accion == AiActionType.verPedido ||
                      item.accion == AiActionType.verReserva)
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => item.accion == AiActionType.verPedido
                              ? const OrdersScreen()
                              : const ReservationsScreen(),
                        ),
                      ),
                      child: Text(
                        item.accion == AiActionType.verPedido
                            ? 'Ver mis pedidos'
                            : 'Ver mis reservas',
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
