import 'package:flutter/material.dart';

import 'package:drapemind_mobile/core/theme/app_colors.dart';
import 'package:drapemind_mobile/core/theme/app_design_tokens.dart';
import 'package:drapemind_mobile/core/theme/app_svg.dart';

class AltairWelcomeState extends StatelessWidget {
  final ValueChanged<String> onPrompt;
  final VoidCallback onOpenPreferences;

  const AltairWelcomeState({
    super.key,
    required this.onPrompt,
    required this.onOpenPreferences,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: AppColors.ink,
            shape: BoxShape.circle,
            boxShadow: AppShadows.surface,
          ),
          child: Center(
            child: AppSvg.raw(AppSvg.sparkle, size: 28, color: AppColors.lime),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const Text(
          '¿Qué armamos hoy?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Consulta prendas reales, combina tu perchero o crea un look completo.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMutedStrong, height: 1.45),
        ),
        const SizedBox(height: AppSpacing.xl),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            _PromptPill(
              icon: AppSvg.sparkle,
              label: 'Armar un outfit',
              onTap: () => onPrompt(
                'Arma un outfit con productos disponibles y pregúntame el presupuesto que necesito.',
              ),
            ),
            _PromptPill(
              icon: AppSvg.tshirt,
              label: 'Mejorar mi perchero',
              onTap: () => onPrompt(
                'Analiza mi perchero y recomiéndame complementos disponibles.',
              ),
            ),
            _PromptPill(
              icon: AppSvg.bag,
              label: 'Buscar por presupuesto',
              onTap: () =>
                  onPrompt('Ayúdame a encontrar prendas según mi presupuesto.'),
            ),
            _PromptPill(
              icon: AppSvg.settings,
              label: 'Configurar preferencias',
              onTap: onOpenPreferences,
            ),
          ],
        ),
      ],
    ),
  );
}

class _PromptPill extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback onTap;

  const _PromptPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final maxWidth = (MediaQuery.sizeOf(context).width - 48)
        .clamp(0.0, 320.0)
        .toDouble();

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Material(
        color: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          side: const BorderSide(color: AppColors.line),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppSvg.raw(icon, size: 14, color: AppColors.ink),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
