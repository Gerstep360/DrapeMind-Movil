import 'package:flutter/material.dart';

import 'package:drapemind_mobile/core/theme/app_colors.dart';
import 'package:drapemind_mobile/core/theme/app_svg.dart';

class DmProductImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final String semanticLabel;

  const DmProductImage({
    super.key,
    required this.imageUrl,
    required this.semanticLabel,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.trim().isEmpty) {
      return _EditorialFallback(label: semanticLabel);
    }
    return Image.network(
      imageUrl,
      fit: fit,
      semanticLabel: semanticLabel,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return const _ProductSkeleton();
      },
      errorBuilder: (_, __, ___) => _EditorialFallback(label: semanticLabel),
    );
  }
}

class _ProductSkeleton extends StatelessWidget {
  const _ProductSkeleton();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: AppColors.paperDark,
    child: Center(
      child: SizedBox.square(
        dimension: 22,
        child: CircularProgressIndicator(
          strokeWidth: 1.8,
          color: AppColors.ink,
        ),
      ),
    ),
  );
}

class _EditorialFallback extends StatelessWidget {
  final String label;

  const _EditorialFallback({required this.label});

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'Fotografía de $label en preparación',
    child: ColoredBox(
      color: AppColors.forestLight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: -30,
            right: -22,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.lime.withValues(alpha: 0.16),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.lime, width: 1.5),
                ),
                child: Center(
                  child: AppSvg.raw(
                    AppSvg.tshirt,
                    size: 32,
                    color: AppColors.white,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'DrapeMind',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const Text(
                'ATELIER',
                style: TextStyle(
                  color: AppColors.lime,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.5,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
