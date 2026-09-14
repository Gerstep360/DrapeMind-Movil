import 'package:flutter/material.dart';

import 'package:drapemind_mobile/compartido/componentes/productos/dm_product_image.dart';
import 'package:drapemind_mobile/core/theme/app_colors.dart';
import 'package:drapemind_mobile/core/theme/app_design_tokens.dart';
import 'package:drapemind_mobile/paquetes/carrito_pedidos_pagos/dominio/modelos/cart_models.dart';

class CartItemCard extends StatelessWidget {
  final CartItem item;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  const CartItemCard({
    super.key,
    required this.item,
    required this.onDecrease,
    required this.onIncrease,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(AppSpacing.sm),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppRadii.medium),
      border: Border.all(color: AppColors.line),
    ),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.small),
          child: SizedBox.square(
            dimension: 68,
            child: DmProductImage(
              imageUrl: item.fullImageUrl,
              semanticLabel: item.nombre,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.nombre,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                '${item.color} · Talla ${item.talla}',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Bs ${item.subtotal.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
        _QuantityControl(
          quantity: item.cantidad,
          onDecrease: onDecrease,
          onIncrease: item.cantidad < item.stockDisponible ? onIncrease : null,
        ),
      ],
    ),
  );
}

class _QuantityControl extends StatelessWidget {
  final int quantity;
  final VoidCallback onDecrease;
  final VoidCallback? onIncrease;

  const _QuantityControl({
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease,
  });

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.paperDark,
      borderRadius: BorderRadius.circular(AppRadii.pill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: quantity == 1 ? 'Quitar' : 'Restar una unidad',
          onPressed: onDecrease,
          icon: Icon(quantity == 1 ? Icons.delete_outline : Icons.remove),
        ),
        Text('$quantity', style: const TextStyle(fontWeight: FontWeight.w900)),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Añadir una unidad',
          onPressed: onIncrease,
          icon: const Icon(Icons.add),
        ),
      ],
    ),
  );
}
