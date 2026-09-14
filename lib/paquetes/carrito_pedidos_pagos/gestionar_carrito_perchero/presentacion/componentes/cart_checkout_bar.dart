import 'package:flutter/material.dart';

import 'package:drapemind_mobile/core/theme/app_colors.dart';
import 'package:drapemind_mobile/core/theme/app_design_tokens.dart';
import 'package:drapemind_mobile/core/theme/app_svg.dart';

class CartCheckoutBar extends StatelessWidget {
  final int itemCount;
  final double total;
  final VoidCallback onCheckout;
  final VoidCallback? onReserve;
  final bool isReserving;

  const CartCheckoutBar({
    super.key,
    required this.itemCount,
    required this.total,
    required this.onCheckout,
    this.onReserve,
    this.isReserving = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
    decoration: const BoxDecoration(
      color: AppColors.white,
      border: Border(top: BorderSide(color: AppColors.line)),
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.large)),
      boxShadow: AppShadows.surface,
    ),
    child: SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$itemCount ${itemCount == 1 ? 'prenda' : 'prendas'}',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ),
              Text(
                'Bs ${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.lime,
                foregroundColor: AppColors.ink,
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: onCheckout,
              icon: AppSvg.raw(AppSvg.bag, size: 18, color: AppColors.ink),
              label: const Text(
                'Continuar al pago',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
          if (onReserve != null) ...[
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isReserving ? null : onReserve,
                icon: isReserving
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : AppSvg.raw(AppSvg.store, size: 17, color: AppColors.ink),
                label: Text(
                  isReserving ? 'Reservando…' : 'Reservar en mi showroom',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
