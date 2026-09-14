import 'package:flutter/material.dart';

import 'package:drapemind_mobile/core/theme/app_colors.dart';
import 'package:drapemind_mobile/core/theme/app_design_tokens.dart';

class DmEmptyState extends StatelessWidget {
  final String title;
  final String message;
  final Widget? icon;
  final Widget? action;
  final bool compact;

  const DmEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon,
    this.action,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: compact ? AppSpacing.sm : AppSpacing.xl,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          DecoratedBox(
            decoration: const BoxDecoration(
              color: AppColors.paperDark,
              shape: BoxShape.circle,
            ),
            child: SizedBox.square(
              dimension: compact ? 48 : 72,
              child: Center(child: icon),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.25,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted, height: 1.45),
        ),
        if (action != null) ...[const SizedBox(height: AppSpacing.md), action!],
      ],
    ),
  );
}

class DmEmptyCopy extends StatelessWidget {
  final String text;

  const DmEmptyCopy({super.key, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    child: Text(
      text,
      style: const TextStyle(color: AppColors.textMuted, height: 1.4),
    ),
  );
}
