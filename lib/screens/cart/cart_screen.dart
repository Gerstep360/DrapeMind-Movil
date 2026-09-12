import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/core.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_svg.dart';
import '../checkout/checkout_screen.dart';

class CartScreen extends StatefulWidget {
  final VoidCallback? onOpenAiStudio;

  const CartScreen({super.key, this.onOpenAiStudio});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
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
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.ink),
            )
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
                      child: AppSvg.raw(AppSvg.bag, size: 36, color: AppColors.textMuted),
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
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
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
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                        ),
                        onPressed: _consultAiStylist,
                        child: const Text(
                          'Calificar ✦',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),

                // CART ITEMS LIST
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: cart.items.length,
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.line),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0410110F),
                              blurRadius: 10,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            // IMAGE
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                width: 64,
                                height: 64,
                                color: AppColors.paperDark,
                                child: item.fullImageUrl.isNotEmpty
                                    ? Image.network(
                                        item.fullImageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Center(
                                          child: AppSvg.raw(
                                            AppSvg.tshirt,
                                            size: 24,
                                            color: AppColors.ink,
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: AppSvg.raw(
                                          AppSvg.tshirt,
                                          size: 24,
                                          color: AppColors.ink,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 14),

                            // DETAILS
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.nombre,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${item.color} · Talla ${item.talla}',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    'Bs ${item.subtotal.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // QUANTITY PILL CONTROLS
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.paperDark,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                    icon: AppSvg.raw(
                                      AppSvg.minus,
                                      size: 13,
                                      color: AppColors.ink,
                                    ),
                                    onPressed: () => _updateQuantity(item, -1),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    child: Text(
                                      '${item.cantidad}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                    icon: AppSvg.raw(
                                      AppSvg.plus,
                                      size: 13,
                                      color: AppColors.ink,
                                    ),
                                    onPressed: () => _updateQuantity(item, 1),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // CHECKOUT BAR (DRAPEMIND LIME CTA PILL)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    border: Border(
                      top: BorderSide(color: AppColors.line),
                    ),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x0A10110F),
                        blurRadius: 20,
                        offset: Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total (${cart.totalItems} prendas):',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMuted,
                              ),
                            ),
                            Text(
                              'Bs ${cart.subtotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: AppColors.ink,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.lime,
                              foregroundColor: AppColors.ink,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CheckoutScreen(),
                                ),
                              );
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AppSvg.raw(
                                  AppSvg.bag,
                                  size: 18,
                                  color: AppColors.ink,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Proceder a Comprar',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
