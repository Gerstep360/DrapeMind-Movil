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

  bool _isAnalyzingStyle = false;
  bool _isOptimizingValue = false;

  Future<void> _analyzeStyle() async {
    final cartService = context.read<CartService>();
    if (cartService.isEmpty || _isAnalyzingStyle) return;

    setState(() => _isAnalyzingStyle = true);
    try {
      final res = await cartService.checkStyle(
        objetivo: 'Evaluar coherencia cromática, balance y formalidad del perchero',
      );
      if (mounted) {
        _showAiResultModal(
          title: 'Crítica Estilística de Altair',
          eyebrow: 'ANÁLISIS DE ESTILO',
          result: res,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo completar el análisis de estilo.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzingStyle = false);
    }
  }

  Future<void> _optimizeValue() async {
    final cartService = context.read<CartService>();
    if (cartService.isEmpty || _isOptimizingValue) return;

    setState(() => _isOptimizingValue = true);
    try {
      final res = await cartService.checkValue(
        objetivo: 'Optimizar calidad de materiales, precio y ahorro del perchero',
      );
      if (mounted) {
        _showAiResultModal(
          title: 'Optimización de Outfit y Ahorro',
          eyebrow: 'VALOR Y AHORRO',
          result: res,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo calcular la optimización de valor.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isOptimizingValue = false);
    }
  }

  List<TextSpan> _buildMarkdownSpans(String text) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.*?)\*\*');
    int lastMatchEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: text.substring(lastMatchEnd, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
        ),
      );
      lastMatchEnd = match.end;
    }
    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd)));
    }
    return spans;
  }

  void _showAiResultModal({
    required String title,
    required String eyebrow,
    required Map<String, dynamic> result,
  }) {
    final answer = result['respuesta'] as String? ?? 'Análisis completado.';
    final rawProducts = result['productos'];
    final rawRecs = result['recomendaciones'];
    final allProducts = (rawProducts is List) ? rawProducts : [];
    final allRecs = (rawRecs is List) ? rawRecs : [];

    final auditedItems = allProducts.where((p) {
      if (p is Map) {
        return p['en_carrito'] == true || p['accion'] == 'QUITAR' || (!p.containsKey('en_carrito') && !p.containsKey('accion'));
      }
      return false;
    }).toList();

    final suggestedItems = <dynamic>[];
    suggestedItems.addAll(allRecs);
    for (final p in allProducts) {
      if (p is Map && (p['accion'] == 'AGREGAR' || p['en_carrito'] == false)) {
        if (!suggestedItems.any((item) => item is Map && item['variante_id'] == p['variante_id'])) {
          suggestedItems.add(p);
        }
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paperLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.lineStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                eyebrow,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.line),
                ),
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.ink,
                      fontFamily: 'Manrope',
                    ),
                    children: _buildMarkdownSpans(answer),
                  ),
                ),
              ),

              // 1. PRENDAS AUDITADAS EN PERCHERO
              if (auditedItems.isNotEmpty) ...[
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'PRENDAS EN TU PERCHERO (AUDITADAS):',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: AppColors.muted,
                      ),
                    ),
                    Text(
                      '${auditedItems.length} items',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...auditedItems.map((p) {
                  final name = (p is Map) ? (p['nombre'] ?? 'Prenda') : 'Prenda';
                  final price = (p is Map) ? (p['precio'] ?? p['precio_base']) : null;
                  final color = (p is Map) ? p['color'] : null;
                  final talla = (p is Map) ? p['talla'] : null;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  if (color != null) ...[
                                    Text(
                                      '$color',
                                      style: const TextStyle(fontSize: 11, color: AppColors.muted),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  if (talla != null) ...[
                                    Text(
                                      'Talla $talla',
                                      style: const TextStyle(fontSize: 11, color: AppColors.muted),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  if (price != null) ...[
                                    Text(
                                      'Bs $price',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.paperDark,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'En Perchero',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],

              // 2. COMPLEMENTOS SUGERIDOS PARA ELEVAR TU LOOK
              if (suggestedItems.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'COMPLEMENTOS SUGERIDOS A TU MEDIDA:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...suggestedItems.map((p) {
                  final name = (p is Map) ? (p['nombre'] ?? 'Prenda') : 'Prenda';
                  final price = (p is Map) ? (p['precio'] ?? p['precio_base']) : null;
                  final color = (p is Map) ? p['color'] : null;
                  final talla = (p is Map) ? p['talla'] : null;
                  final rawVarId = (p is Map) ? (p['variante_id'] ?? p['id']) : null;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  if (color != null) ...[
                                    Text(
                                      '$color',
                                      style: const TextStyle(fontSize: 11, color: AppColors.muted),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  if (talla != null) ...[
                                    Text(
                                      'Talla $talla',
                                      style: const TextStyle(fontSize: 11, color: AppColors.muted),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  if (price != null) ...[
                                    Text(
                                      'Bs $price',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.forest,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.ink,
                            foregroundColor: AppColors.lime,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () {
                            if (rawVarId != null) {
                              final int? varId = (rawVarId is int) ? rawVarId : int.tryParse(rawVarId.toString());
                              if (varId != null) {
                                context.read<CartService>().addItem(varId, cantidad: 1);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('"$name" añadida al perchero.'),
                                    backgroundColor: AppColors.forest,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            }
                          },
                          child: const Text('+ Añadir'),
                        ),
                      ],
                    ),
                  );
                }),
              ],

              // 3. CARD DESTACADA: DISEÑAR OUTFIT COMPLETO COORDINADO
              Container(
                margin: const EdgeInsets.only(top: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.auto_awesome, color: AppColors.lime, size: 18),
                        SizedBox(width: 6),
                        Text(
                          '¿DESEAS ARMAR UN OUTFIT COMPLETO?',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: AppColors.lime,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Altair AI puede combinar las prendas de tu perchero con calzado y accesorios coordinados en tus tallas.',
                      style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.paperLight),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.lime,
                          foregroundColor: AppColors.ink,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          final ai = context.read<AiSocketService>();
                          ai.sendMessage('Arma un outfit completo y coordinado con las prendas de mi perchero actual');
                          if (widget.onOpenAiStudio != null) {
                            widget.onOpenAiStudio!();
                          }
                        },
                        child: const Text(
                          'Diseñar Outfit Completo →',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
                // AI ASISTENCIA DIRECTA (CU-22 & CU-23)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.cyanSoft,
                    border: Border.all(color: AppColors.cyan),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Row(
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
                                  'Inteligencia Sastrera Altair',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.ink,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Audita coherencia de estilo y optimiza balance calidad/ahorro.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textMutedStrong,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.ink,
                                foregroundColor: AppColors.lime,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              onPressed: _isAnalyzingStyle ? null : _analyzeStyle,
                              icon: _isAnalyzingStyle
                                  ? const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        color: AppColors.lime,
                                      ),
                                    )
                                  : const Icon(Icons.style_outlined, size: 14),
                              label: const Text(
                                'Estilo',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.ink,
                                side: const BorderSide(color: AppColors.ink),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              onPressed: _isOptimizingValue ? null : _optimizeValue,
                              icon: _isOptimizingValue
                                  ? const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        color: AppColors.ink,
                                      ),
                                    )
                                  : const Icon(Icons.monetization_on_outlined, size: 14),
                              label: const Text(
                                'Ahorro',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
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
