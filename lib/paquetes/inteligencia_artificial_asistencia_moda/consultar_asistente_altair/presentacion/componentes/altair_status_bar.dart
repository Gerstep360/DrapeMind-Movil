import 'package:flutter/material.dart';

import 'package:drapemind_mobile/core/theme/app_colors.dart';
import 'package:drapemind_mobile/core/theme/app_design_tokens.dart';
import 'package:drapemind_mobile/core/theme/app_svg.dart';
import 'altair_model_selector.dart';

class AltairStatusBar extends StatelessWidget {
  final bool isBusy;
  final bool isReady;
  final String statusLabel;
  final String elapsed;
  final String activeModel;
  final ValueChanged<String> onModelSelected;
  final VoidCallback onOpenPreferences;
  final VoidCallback? onCancel;

  const AltairStatusBar({
    super.key,
    required this.isBusy,
    required this.isReady,
    required this.statusLabel,
    required this.elapsed,
    required this.activeModel,
    required this.onModelSelected,
    required this.onOpenPreferences,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: const BoxDecoration(
      color: AppColors.white,
      border: Border(bottom: BorderSide(color: AppColors.line)),
    ),
    child: Row(
      children: [
        AnimatedContainer(
          duration: AppMotion.normal,
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isBusy
                ? AppColors.lime
                : isReady
                ? AppColors.success
                : AppColors.danger,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            isBusy ? 'Altair responde · $elapsed' : statusLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textMutedStrong,
            ),
          ),
        ),
        _CompactAction(
          onTap: () => showAltairModelSelector(
            context,
            activeModel: activeModel,
            onSelected: onModelSelected,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AltairModelPresentation.icon(activeModel),
              const SizedBox(width: 4),
              Text(
                AltairModelPresentation.shortLabel(activeModel),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Icon(Icons.arrow_drop_down, size: 15),
            ],
          ),
        ),
        const SizedBox(width: 7),
        _CompactAction(
          onTap: onOpenPreferences,
          dark: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppSvg.raw(AppSvg.settings, size: 12, color: AppColors.lime),
              const SizedBox(width: 5),
              const Text(
                'Look',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        if (isBusy && onCancel != null) ...[
          const SizedBox(width: 7),
          _CompactAction(
            onTap: onCancel!,
            dark: true,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.stop_rounded, size: 14, color: AppColors.acid),
                SizedBox(width: 4),
                Text(
                  'Detener',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

class _CompactAction extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool dark;

  const _CompactAction({
    required this.child,
    required this.onTap,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: dark ? AppColors.ink : AppColors.paperLight,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.pill),
      side: BorderSide(color: dark ? AppColors.ink : AppColors.lineStrong),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: child,
      ),
    ),
  );
}
