import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../cu13_catalogo_offline/cu13_offline_service.dart';
import '../cu23_pagos/cu23_deferred_service.dart';
import '../cu22_carrito_checkout/cu22_cart_service.dart';
import '../cu24_pedidos/cu24_order_service.dart';

class StoreDownloadButton extends StatelessWidget {
  const StoreDownloadButton({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.watch<OfflineService?>();
    if (store?.owner == null) return const SizedBox.shrink();
    final purchases = context.watch<DeferredService?>();
    final count =
        store!.pending +
        (purchases?.purchases.where((r) => !purchases.terminal(r)).length ?? 0);
    return IconButton(
      tooltip: 'Tienda descargada',
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
        backgroundColor: AppColors.paper,
        builder: (_) => const StoreDownloadSheet(),
      ),
    );
  }
}

class StoreDownloadSheet extends StatefulWidget {
  final OrderService? orders;
  const StoreDownloadSheet({super.key, this.orders});
  @override
  State<StoreDownloadSheet> createState() => _DownloadState();
}

class _DownloadState extends State<StoreDownloadSheet> {
  bool busy = false;
  int completed = 0, orderCount = 0;
  String? error;
  Future<void> download() async {
    if (busy) return;
    final store = context.read<OfflineService>(),
        cart = context.read<CartService>(),
        purchases = context.read<DeferredService>();
    final scope = store.owner;
    void next(int step) {
      if (store.owner != scope) {
        throw ApiException('La tienda cambió. Abre nuevamente la descarga.');
      }
      if (mounted) setState(() => completed = step);
    }

    setState(() {
      busy = true;
      completed = 0;
      error = null;
      orderCount = 0;
    });
    try {
      await store.download(strict: true);
      if (!store.usable) {
        throw ApiException('Actualiza tu sesión para guardar esta tienda.');
      }
      next(1);
      await cart.prepareDownload();
      next(2);
      if (store.auth.currentUser?.rol.toServerString() == 'CLIENTE') {
        await purchases.prepareDownload();
      }
      next(3);
      await (widget.orders ?? OrderService(offline: store)).prepareDownload(
        onProgress: (count) {
          if (mounted) setState(() => orderCount = count);
        },
      );
      next(4);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is ApiException
              ? e.message
              : 'No se completó la descarga. Revisa la conexión y el espacio disponible y vuelve a intentar.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<OfflineService>();
    final client = store.auth.currentUser?.rol.toServerString() == 'CLIENTE';
    final labels = [
      'Prendas, tallas y fotografías',
      'Tu carrito habitual',
      client
          ? 'Entrega y tarjeta guardada'
          : 'Inventario y reservas de tus sucursales',
      'Pedidos y comprobantes',
    ];
    final details = [
      busy && completed == 0
          ? store.phase
          : store.bundle == null
          ? 'Colección y disponibilidad de esta tienda'
          : '${store.bundle!.products.length} prendas · ${store.photosSaved} de ${store.photosTotal} fotos guardadas',
      'Tu selección se conserva en el mismo carrito',
      client
          ? 'El banco confirmará el pago al volver a conectar'
          : 'Disponibilidad descargada por sucursal',
      orderCount > 0
          ? '$orderCount pedidos recuperados'
          : 'Historial completo de tu cuenta en esta tienda',
    ];
    final photoFraction = store.photosTotal == 0
        ? 0.0
        : store.photosProcessed / store.photosTotal;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .91,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Tu tienda, contigo',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar tienda descargada',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Sigue eligiendo prendas, comprando y viendo tus pedidos en las mismas pestañas, incluso sin Internet.',
              ),
              const SizedBox(height: 20),
              if (busy || completed == 4) ...[
                LinearProgressIndicator(
                  value: completed == 0 && busy
                      ? photoFraction * .25
                      : completed / 4,
                  minHeight: 7,
                  backgroundColor: AppColors.paperDark,
                  color: AppColors.ink,
                ),
                const SizedBox(height: 8),
                Text('$completed de 4 apartados guardados'),
                const SizedBox(height: 12),
              ],
              for (var i = 0; i < labels.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        completed > i
                            ? Icons.check_circle
                            : busy && completed == i
                            ? Icons.downloading
                            : Icons.circle_outlined,
                        color: completed > i ? AppColors.ink : AppColors.muted,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              labels[i],
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              details[i],
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              if (store.photosFailed > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    '${store.photosFailed} fotos no pudieron guardarse. Las prendas siguen disponibles; actualiza la descarga para reintentar las fotos.',
                  ),
                ),
              if (error != null)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  padding: const EdgeInsets.all(12),
                  color: AppColors.dangerBg,
                  child: Text(
                    error!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
              if (completed == 4 && !busy)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  color: AppColors.lime,
                  child: const Text(
                    'Descarga lista. Continúa en Tienda, Carrito o Pedidos.',
                  ),
                ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: busy ? null : download,
                icon: Icon(
                  error != null ? Icons.refresh : Icons.download_outlined,
                ),
                label: Text(
                  busy
                      ? 'Guardando tu tienda…'
                      : error != null
                      ? 'Reintentar descarga'
                      : store.bundle == null
                      ? 'Descargar esta tienda'
                      : 'Actualizar descarga',
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Sin conexión, la compra queda en espera. Al conectar se revisan stock, precios y autorización de la tarjeta. Altair y los cambios o devoluciones necesitan conexión.',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
