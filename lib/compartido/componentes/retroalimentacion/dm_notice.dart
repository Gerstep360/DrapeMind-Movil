import 'package:flutter/material.dart';

import 'package:drapemind_mobile/core/theme/app_colors.dart';
import 'package:drapemind_mobile/core/theme/app_design_tokens.dart';

enum DmNoticeTone { info, warning, danger, success }

class DmNotice extends StatelessWidget {
  final String message;
  final DmNoticeTone tone;
  final IconData? icon;

  const DmNotice({
    super.key,
    required this.message,
    this.tone = DmNoticeTone.warning,
    this.icon,
  });

  (Color, Color, IconData) get _appearance => switch (tone) {
    DmNoticeTone.info => (
      AppColors.cyanSoft,
      AppColors.cyan,
      Icons.info_outline,
    ),
    DmNoticeTone.warning => (
      AppColors.warningBg,
      AppColors.warning,
      Icons.warning_amber_rounded,
    ),
    DmNoticeTone.danger => (
      AppColors.dangerBg,
      AppColors.danger,
      Icons.error_outline,
    ),
    DmNoticeTone.success => (
      AppColors.successBg,
      AppColors.success,
      Icons.check_circle_outline,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final (background, border, fallbackIcon) = _appearance;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(AppRadii.small),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? fallbackIcon, size: 18, color: AppColors.ink),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.textMutedStrong,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
