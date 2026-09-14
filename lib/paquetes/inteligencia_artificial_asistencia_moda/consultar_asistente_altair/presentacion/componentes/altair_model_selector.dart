import 'package:flutter/material.dart';

import 'package:drapemind_mobile/core/theme/app_colors.dart';
import 'package:drapemind_mobile/core/theme/app_design_tokens.dart';
import 'package:drapemind_mobile/core/theme/app_svg.dart';

abstract final class AltairModelPresentation {
  static Widget icon(String model, {double size = 14}) => switch (model) {
    'mini' => Icon(Icons.bolt_rounded, size: size, color: AppColors.warning),
    'gemma' => Icon(
      Icons.psychology_outlined,
      size: size,
      color: AppColors.ink,
    ),
    _ => AppSvg.raw(AppSvg.sparkle, size: size, color: AppColors.ink),
  };

  static String shortLabel(String model) => switch (model) {
    'mini' => 'Mini',
    'gemma' => 'Gemma',
    _ => 'Dinámico',
  };

  static String fullLabel(String model) => switch (model) {
    'mini' => 'Altair Mini',
    'gemma' => 'Altair · Gemma',
    _ => 'Altair Dinámico',
  };
}

Future<void> showAltairModelSelector(
  BuildContext context, {
  required String activeModel,
  required ValueChanged<String> onSelected,
}) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (sheetContext) => _ModelSheet(
    activeModel: activeModel,
    onSelected: (model) {
      onSelected(model);
      Navigator.pop(sheetContext);
    },
  ),
);

class _ModelSheet extends StatelessWidget {
  final String activeModel;
  final ValueChanged<String> onSelected;

  const _ModelSheet({required this.activeModel, required this.onSelected});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
    decoration: const BoxDecoration(
      color: AppColors.paper,
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(child: _SheetHandle()),
        const SizedBox(height: AppSpacing.lg),
        const Text(
          'Elige cómo responde Altair',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Puedes priorizar velocidad o análisis; Dinámico decide según la consulta.',
          style: TextStyle(color: AppColors.textMuted, height: 1.4),
        ),
        const SizedBox(height: AppSpacing.lg),
        _ModelOption(
          model: 'mini',
          title: 'Altair Mini',
          badge: 'Menor latencia',
          description:
              'Scout redacta la respuesta y usa tools cuando hacen falta.',
          active: activeModel == 'mini',
          onTap: onSelected,
        ),
        const SizedBox(height: AppSpacing.sm),
        _ModelOption(
          model: 'dynamic',
          title: 'Altair Dinámico',
          badge: 'Recomendado',
          description: 'Mini resuelve lo simple y delega a Gemma lo complejo.',
          active: activeModel == 'dynamic',
          onTap: onSelected,
        ),
        const SizedBox(height: AppSpacing.sm),
        _ModelOption(
          model: 'gemma',
          title: 'Altair · solo Gemma',
          badge: 'Más profundidad',
          description: 'Usa el modelo principal en todo el turno.',
          active: activeModel == 'gemma',
          onTap: onSelected,
        ),
      ],
    ),
  );
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 4,
    decoration: BoxDecoration(
      color: AppColors.lineStrong,
      borderRadius: BorderRadius.circular(AppRadii.pill),
    ),
  );
}

class _ModelOption extends StatelessWidget {
  final String model;
  final String title;
  final String badge;
  final String description;
  final bool active;
  final ValueChanged<String> onTap;

  const _ModelOption({
    required this.model,
    required this.title,
    required this.badge,
    required this.description,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: active ? AppColors.white : AppColors.paperLight,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.medium),
      side: BorderSide(
        color: active ? AppColors.ink : AppColors.line,
        width: active ? 1.5 : 1,
      ),
    ),
    child: InkWell(
      onTap: () => onTap(model),
      borderRadius: BorderRadius.circular(AppRadii.medium),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: model == 'dynamic'
                    ? AppColors.lime
                    : AppColors.paperDark,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: AltairModelPresentation.icon(model, size: 20),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: model == 'dynamic'
                              ? AppColors.limeSoft
                              : AppColors.paperDark,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            if (active)
              const Icon(Icons.check_circle, color: AppColors.success),
          ],
        ),
      ),
    ),
  );
}
