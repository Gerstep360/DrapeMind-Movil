import 'package:flutter/material.dart';
import 'package:drapemind_mobile/compartido/componentes/productos/dm_product_image.dart';
import 'package:drapemind_mobile/paquetes/catalogo_comercializacion/dominio/modelos/catalog_models.dart';
import 'package:drapemind_mobile/core/theme/app_colors.dart';

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
    final available = product.stockDisponible > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Material(
                  color: AppColors.paperDark,
                  child: InkWell(
                    onTap: onOpen,
                    child: DmProductImage(
                      imageUrl: product.mainImageUrl,
                      semanticLabel: product.nombre,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 5,
                right: 5,
                child: _Action(
                  label: isFavorite
                      ? 'Quitar de favoritos'
                      : 'Guardar en favoritos',
                  onTap: onFavorite,
                  icon: isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isFavorite ? AppColors.danger : AppColors.ink,
                ),
              ),
              if (!available || product.stockDisponible <= 3)
                Positioned(
                  left: 8,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      available ? 'Últimas unidades' : 'Agotado',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              if (available)
                Positioned(
                  bottom: 7,
                  right: 5,
                  child: _Action(
                    label: 'Elegir talla y agregar al carrito',
                    onTap: onQuickAdd,
                    icon: Icons.add_rounded,
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 10, 2, 3),
          child: InkWell(
            onTap: onOpen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (product.marca?.isNotEmpty == true) ...[
                  Text(
                    product.marca!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      letterSpacing: 0.6,
                      color: AppColors.textMutedStrong,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  product.nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Bs ${product.precio.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final IconData icon;
  final Color color;
  const _Action({
    required this.label,
    required this.onTap,
    required this.icon,
    this.color = AppColors.ink,
  });
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: label,
    onPressed: onTap,
    style: IconButton.styleFrom(
      backgroundColor: AppColors.white,
      foregroundColor: color,
      minimumSize: const Size(44, 44),
      maximumSize: const Size(44, 44),
    ),
    icon: Icon(icon, size: 21),
  );
}
