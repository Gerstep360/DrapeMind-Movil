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
        title: Row(
          children: [
            AppSvg.raw(AppSvg.bag, size: 18, color: AppColors.white),
            const SizedBox(width: 8),
            const Text('MI PERCHERO'),
          ],
        ),
        actions: [
          IconButton(
            icon: AppSvg.raw(AppSvg.sparkle, size: 18, color: AppColors.acid),
            onPressed: _consultAiStylist,
            tooltip: 'Calificar con IA',
          ),
        ],
      ),
      body: cartService.isLoading && cart == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.forest),
            )
          : cart == null || cart.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppSvg.raw(AppSvg.bag, size: 56, color: AppColors.textMuted),
                  const SizedBox(height: 14),
                  const Text(
                    'Tu perchero está vacío',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.forestDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Explora el showroom o pide un outfit a tu estilista IA.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // AI ADVISORY BANNER
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.paperLight,
                    border: Border.all(color: AppColors.forest),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      AppSvg.raw(
                        AppSvg.sparkle,
                        size: 22,
                        color: AppColors.forest,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Asesoría de Estilo & Armonía',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.forest,
                              ),
                            ),
                            Text(
                              'Pide a la IA calificar tu selección y recomendar complementos.',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textMutedStrong,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: _consultAiStylist,
                        child: const Text(
                          'Calificar',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                ),

                // CART ITEMS LIST
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: cart.items.length,
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: [
                              // IMAGE
                              Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  color: AppColors.paperDark,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: item.fullImageUrl.isNotEmpty
                                    ? Image.network(
                                        item.fullImageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Center(
                                          child: AppSvg.raw(
                                            AppSvg.tshirt,
                                            size: 24,
                                            color: AppColors.forest,
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: AppSvg.raw(
                                          AppSvg.tshirt,
                                          size: 24,
                                          color: AppColors.forest,
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 12),

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
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${item.color} · Talla ${item.talla}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Bs ${item.subtotal.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.forest,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // QUANTITY CONTROLS
                              Row(
                                children: [
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: AppSvg.raw(
                                      AppSvg.minus,
                                      size: 14,
                                      color: AppColors.forest,
                                    ),
                                    onPressed: () => _updateQuantity(item, -1),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: Text(
                                      '${item.cantidad}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: AppSvg.raw(
                                      AppSvg.plus,
                                      size: 14,
                                      color: AppColors.forest,
                                    ),
                                    onPressed: () => _updateQuantity(item, 1),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // CHECKOUT BAR
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    border: Border(
                      top: BorderSide(color: AppColors.lineStrong),
                    ),
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
                                color: AppColors.textMutedStrong,
                              ),
                            ),
                            Text(
                              'Bs ${cart.subtotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: AppColors.forest,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
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
                                AppSvg.package,
                                size: 16,
                                color: AppColors.white,
                              ),
                              const SizedBox(width: 8),
                              const Text('Proceder a Comprar'),
                            ],
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
