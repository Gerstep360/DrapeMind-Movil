import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drapemind_mobile/core/core.dart';
import 'package:drapemind_mobile/core/theme/app_colors.dart';
import 'package:drapemind_mobile/core/theme/app_svg.dart';
import 'package:drapemind_mobile/paquetes/carrito_pedidos_pagos/realizar_checkout_entrega_recojo/presentacion/checkout_screen.dart';
import 'package:drapemind_mobile/paquetes/reservas_atencion_tienda/reservar_varias_prendas_sucursal/aplicacion/reservar_perchero.dart';
import 'componentes/cart_checkout_bar.dart';
import 'componentes/cart_item_card.dart';

class CartScreen extends StatefulWidget {
  final VoidCallback? onOpenAiStudio;

  const CartScreen({super.key, this.onOpenAiStudio});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _reservarPerchero = ReservarPerchero();
  bool _isReserving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CartService>().getCart();
    });
  }

  void _updateQuantity(CartItem item, int delta) {
    final newQty = item.cantidad + delta;
    final cart = context.read<CartService>();
    if (newQty <= 0) {
      cart.removeItem(item.id);
    } else {
      cart.updateItemQuantity(item.id, newQty);
    }
  }

  void _consultAiStylist() {
    final ai = context.read<AiSocketService>();
    ai.sendMessage(
      'Mira mi carrito y dime que puedo quitar o que puedo combinar en mi eleccion',
    );
    if (widget.onOpenAiStudio != null) {
      widget.onOpenAiStudio!();
    }
  }

  Future<void> _reserveCart(Cart cart) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reservar este perchero'),
        content: Text(
          'Separaremos ${cart.totalItems} ${cart.totalItems == 1 ? 'prenda' : 'prendas'} '
          'en tu showroom preferido. El stock se confirma al crear la reserva.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar reserva'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isReserving = true);
    try {
      final reservation = await _reservarPerchero();
      if (!mounted) return;
      await context.read<CartService>().getCart();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reserva ${reservation.codigoPublico} creada correctamente.',
          ),
          action: SnackBarAction(label: 'Entendido', onPressed: () {}),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo crear la reserva: $error')),
      );
    } finally {
      if (mounted) setState(() => _isReserving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartService = context.watch<CartService>();
    final cart = cartService.cart;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: AppColors.ink,
                shape: BoxShape.circle,
              ),
              child: AppSvg.raw(AppSvg.bag, size: 14, color: AppColors.lime),
            ),
            const SizedBox(width: 10),
            const Text(
              'Mi Perchero',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.lime,
                borderRadius: BorderRadius.circular(999),
              ),
              child: AppSvg.raw(AppSvg.sparkle, size: 14, color: AppColors.ink),
            ),
            onPressed: _consultAiStylist,
            tooltip: 'Calificar con IA',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: cartService.isLoading && cart == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.ink))
          : cart == null || cart.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.paperDark,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: AppSvg.raw(
                        AppSvg.bag,
                        size: 36,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Tu perchero está vacío',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Explora el showroom o pide un outfit a tu estilista IA.',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // AI ADVISORY BANNER (DRAPEMIND SOFT FUTURISM STYLE)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.cyanSoft,
                    border: Border.all(color: AppColors.cyan),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppColors.lime,
                          shape: BoxShape.circle,
                        ),
                        child: AppSvg.raw(
                          AppSvg.sparkle,
                          size: 16,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Asesoría de Estilo & Armonía',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Pide a Altair IA calificar tu selección y recomendar complementos.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textMutedStrong,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.ink,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        onPressed: _consultAiStylist,
                        child: const Text(
                          'Calificar ✦',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: cart.items.length,
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      return CartItemCard(
                        item: item,
                        onDecrease: () => _updateQuantity(item, -1),
                        onIncrease: () => _updateQuantity(item, 1),
                      );
                    },
                  ),
                ),
                CartCheckoutBar(
                  itemCount: cart.totalItems,
                  total: cart.subtotal,
                  isReserving: _isReserving,
                  onReserve: () => _reserveCart(cart),
                  onCheckout: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CheckoutScreen()),
                  ),
                ),
              ],
            ),
    );
  }
}
