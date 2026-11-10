import 'package:provider/provider.dart';
import 'package:drapemind_mobile/segundo_parcial/cu13_catalogo_offline/cu13_offline_service.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:drapemind_mobile/core/theme/app_colors.dart';

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
            errorBuilder: (_, __, ___) =>
                _EditorialFallback(label: semanticLabel),
          );
        }
      } catch (_) {
        return _EditorialFallback(label: semanticLabel);
      }
    }

    final vector =
        trimmed.toLowerCase().endsWith('.svg') ||
        trimmed.toLowerCase().contains('.svg?');
    // Soporte para archivos vectoriales SVG
    if (vector && context.read<OfflineService?>()?.online != false) {
      return SvgPicture.network(
        trimmed,
        fit: fit,
        placeholderBuilder: (_) => const _ProductSkeleton(),
      );
    }

    final local = context.watch<OfflineService?>();
    if (local != null && local.usable && !local.online) {
      return FutureBuilder(
        future: local.photo(trimmed),
        builder: (context, snapshot) {
          if (snapshot.data != null) {
            if (vector) {
              return SvgPicture.memory(
                snapshot.data!,
                fit: fit,
                semanticsLabel: semanticLabel,
              );
            }
            return Image.memory(
              snapshot.data!,
              fit: fit,
              semanticLabel: semanticLabel,
              errorBuilder: (_, __, ___) =>
                  _EditorialFallback(label: semanticLabel),
            );
          }
          return _EditorialFallback(label: semanticLabel);
        },
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
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxHeight < 130 || constraints.maxWidth < 100;
        return Container(
          color: AppColors.paperDark,
          alignment: Alignment.center,
          padding: EdgeInsets.all(compact ? 4 : 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'DM',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: compact ? 16 : 38,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              if (!compact) ...[
                const SizedBox(height: 8),
                const Text(
                  'FOTO EN PREPARACIÓN',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
}
