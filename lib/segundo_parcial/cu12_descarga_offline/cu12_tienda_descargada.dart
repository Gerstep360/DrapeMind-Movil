import '../cu24_pedidos/cu24_order_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../cu13_catalogo_offline/cu13_offline_service.dart';
import '../cu23_pagos/cu23_deferred_service.dart';
import '../cu22_carrito_checkout/cu22_cart_service.dart';

class StoreDownloadButton extends StatelessWidget {
  const StoreDownloadButton({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.watch<OfflineService?>();
    if (store == null) return const SizedBox.shrink();
    final purchases = context.watch<DeferredService?>();
    final count =
        store.pending +
        (purchases?.purchases.where((r) => !purchases.terminal(r)).length ?? 0);
    return IconButton(
      tooltip: 'Datos de esta tienda',
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: Icon(
          store.online
              ? Icons.cloud_download_outlined
              : Icons.cloud_off_outlined,
        ),
      ),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const _DownloadSheet(),
      ),
    );
  }
}

class _DownloadSheet extends StatefulWidget {
  const _DownloadSheet();
  @override
  State<_DownloadSheet> createState() => _DownloadState();
}

class _DownloadState extends State<_DownloadSheet> {
  bool busy = false;
  String? error;
  Future<void> download() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final store = context.read<OfflineService>(),
          cart = context.read<CartService>(),
          purchases = context.read<DeferredService>();
      await store.download();
      if (!store.usable) throw Exception(store.message);
      await cart.synchronizeDraft();
      await cart.getCart();await OrderService(offline:store).getMyOrders();
      if (store.auth.currentUser?.rol.toServerString() == 'CLIENTE') {
        await purchases.refresh();
        if (purchases.contextData == null) {
          throw Exception(
            'La colección está guardada. Recupera conexión para completar los datos de pago y entrega.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<OfflineService>();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Tu tienda, contigo',
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar datos de tienda',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              store.bundle == null
                  ? 'Guarda esta tienda para seguir eligiendo prendas y comprando sin Internet.'
                  : '${store.bundle!.products.length} prendas disponibles en tu descarga.',
            ),
            const SizedBox(height: 12),
            const Text(
              'Usarás el mismo catálogo y carrito. Al recuperar conexión comprobaremos las existencias y procesaremos el pago.',
            ),
            if (busy) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
              Text(
                store.phase.isEmpty
                    ? 'Guardando los datos de tu tienda…'
                    : store.phase,
              ),
            ],
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: busy ? null : download,
              child: Text(
                busy
                    ? 'Descargando…'
                    : store.bundle == null
                    ? 'Descargar esta tienda'
                    : 'Actualizar descarga',
              ),
            ),
            if (!store.online)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Sin conexión. Puedes seguir usando la última descarga de esta tienda.',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
