import 'package:flutter/material.dart';

import 'package:drapemind_mobile/core/theme/app_colors.dart';
import 'package:drapemind_mobile/core/theme/app_design_tokens.dart';

class DmSection extends StatelessWidget {
  final String eyebrow;
  final String title;
  final Widget child;
  final Widget? trailing;

  const DmSection({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.white,
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(AppRadii.large),
      boxShadow: AppShadows.surface,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: AppColors.textMutedStrong,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            if (trailing case final action?) action,
          ],
        ),
        const Divider(height: AppSpacing.lg),
        child,
      ],
    ),
  );
}
