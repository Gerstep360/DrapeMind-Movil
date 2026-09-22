import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
    final trimmed = imageUrl.trim();
    if (trimmed.isEmpty) {
      return _EditorialFallback(label: semanticLabel);
    }

    // Soporte para data URIs base64
    if (trimmed.startsWith('data:image')) {
      try {
        final commaIdx = trimmed.indexOf(',');
        if (commaIdx != -1) {
          final b64 = trimmed.substring(commaIdx + 1);
          final bytes = base64Decode(b64);
          return Image.memory(
            bytes,
            fit: fit,
            semanticLabel: semanticLabel,
            errorBuilder: (_, __, ___) => _EditorialFallback(label: semanticLabel),
          );
        }
      } catch (_) {
        return _EditorialFallback(label: semanticLabel);
      }
    }

    // Soporte para archivos vectoriales SVG
    if (trimmed.toLowerCase().endsWith('.svg') || trimmed.toLowerCase().contains('.svg?')) {
      return SvgPicture.network(
        trimmed,
        fit: fit,
        placeholderBuilder: (_) => const _ProductSkeleton(),
      );
    }

    return Image.network(
      trimmed,
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
