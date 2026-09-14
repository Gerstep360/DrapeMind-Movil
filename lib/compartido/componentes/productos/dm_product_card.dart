import 'package:flutter/material.dart';

import 'package:drapemind_mobile/compartido/componentes/productos/dm_product_image.dart';
import 'package:drapemind_mobile/paquetes/catalogo_comercializacion/dominio/modelos/catalog_models.dart';
import 'package:drapemind_mobile/core/theme/app_colors.dart';
import 'package:drapemind_mobile/core/theme/app_design_tokens.dart';
import 'package:drapemind_mobile/core/theme/app_svg.dart';

class DmProductCard extends StatelessWidget {
  final Product product;
  final bool isFavorite;
  final VoidCallback onOpen;
  final VoidCallback onFavorite;
  final VoidCallback onQuickAdd;

  const DmProductCard({
    super.key,
    required this.product,
    required this.isFavorite,
    required this.onOpen,
    required this.onFavorite,
    required this.onQuickAdd,
  });

  @override
  Widget build(BuildContext context) {
    final hasStock = product.stockDisponible > 0;

    return Material(
      color: AppColors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.large),
        side: const BorderSide(color: AppColors.line),
      ),
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DmProductImage(
                    imageUrl: product.mainImageUrl,
                    semanticLabel: product.nombre,
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: _RoundAction(
                      tooltip: isFavorite
                          ? 'Quitar de favoritos'
                          : 'Guardar en favoritos',
                      onTap: onFavorite,
                      child: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        size: 17,
                        color: isFavorite ? AppColors.danger : AppColors.ink,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Badge(
                          label: 'Q${product.calidadNivel}',
                          foreground: AppColors.lime,
                          background: AppColors.ink,
                        ),
                        if (product.generoObjetivo.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          _Badge(label: product.generoObjetivo),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (product.marca ?? 'DrapeMind Studio').toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    product.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Bs ${product.precio.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      _StockPill(
                        hasStock: hasStock,
                        count: product.stockDisponible,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 36,
                          child: FilledButton(
                            onPressed: onOpen,
                            child: const Text(
                              'Ver prenda',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _RoundAction(
                        tooltip: hasStock
                            ? 'Añadir al perchero'
                            : 'Prenda agotada',
                        background: AppColors.lime,
                        onTap: hasStock ? onQuickAdd : null,
                        child: AppSvg.raw(
                          AppSvg.bag,
                          size: 15,
                          color: hasStock ? AppColors.ink : AppColors.textMuted,
                        ),
                      ),
                    ],
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

class _RoundAction extends StatelessWidget {
  final String tooltip;
  final Widget child;
  final VoidCallback? onTap;
  final Color background;

  const _RoundAction({
    required this.tooltip,
    required this.child,
    required this.onTap,
    this.background = AppColors.white,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: background.withValues(alpha: onTap == null ? 0.55 : 0.94),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox.square(dimension: 36, child: Center(child: child)),
      ),
    ),
  );
}

class _Badge extends StatelessWidget {
  final String label;
  final Color foreground;
  final Color background;

  const _Badge({
    required this.label,
    this.foreground = AppColors.ink,
    this.background = AppColors.white,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: background.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(AppRadii.pill),
      border: background == AppColors.white
          ? Border.all(color: AppColors.line)
          : null,
    ),
    child: Text(
      label,
      style: TextStyle(
        color: foreground,
        fontSize: 9,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _StockPill extends StatelessWidget {
  final bool hasStock;
  final int count;

  const _StockPill({required this.hasStock, required this.count});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: hasStock ? AppColors.successBg : AppColors.dangerBg,
      borderRadius: BorderRadius.circular(AppRadii.pill),
    ),
    child: Text(
      hasStock ? '$count en stock' : 'Agotado',
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w800,
        color: hasStock ? AppColors.success : AppColors.danger,
      ),
    ),
  );
}
