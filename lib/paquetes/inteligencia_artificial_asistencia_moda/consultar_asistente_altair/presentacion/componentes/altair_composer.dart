import 'package:flutter/material.dart';

import 'package:drapemind_mobile/core/theme/app_colors.dart';
import 'package:drapemind_mobile/core/theme/app_design_tokens.dart';
import 'package:drapemind_mobile/core/theme/app_svg.dart';
import 'altair_model_selector.dart';

class AltairComposer extends StatelessWidget {
  final TextEditingController controller;
  final bool isBusy;
  final String activeModel;
  final VoidCallback onSend;
  final VoidCallback? onCancel;
  final VoidCallback onQuestionnaire;
  final ValueChanged<String> onModelSelected;

  const AltairComposer({
    super.key,
    required this.controller,
    required this.isBusy,
    required this.activeModel,
    required this.onSend,
    this.onCancel,
    required this.onQuestionnaire,
    required this.onModelSelected,
  });

  void _selectModel(BuildContext context) => showAltairModelSelector(
    context,
    activeModel: activeModel,
    onSelected: onModelSelected,
  );

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 7, 12, 10),
    decoration: const BoxDecoration(
      color: AppColors.paper,
      border: Border(top: BorderSide(color: AppColors.line)),
    ),
    child: SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _ModelButton(
                model: activeModel,
                onTap: () => _selectModel(context),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onQuestionnaire,
                icon: AppSvg.raw(
                  AppSvg.settings,
                  size: 14,
                  color: AppColors.ink,
                ),
                label: const Text('Preferencias del look'),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  maxLines: 4,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Pregunta por prendas, tallas o un outfit…',
                  ),
                  onSubmitted: (_) {
                    if (!isBusy) onSend();
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Semantics(
                button: true,
                label: isBusy ? 'Detener respuesta de Altair' : 'Enviar mensaje',
                child: Material(
                  color: isBusy ? AppColors.ink : AppColors.lime,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: isBusy ? onCancel : onSend,
                    child: SizedBox.square(
                      dimension: 48,
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: AppMotion.fast,
                          child: isBusy
                              ? const Icon(
                                  Icons.stop_rounded,
                                  key: ValueKey('stop'),
                                  size: 22,
                                  color: AppColors.white,
                                )
                              : KeyedSubtree(
                                  key: const ValueKey('send'),
                                  child: AppSvg.raw(
                                    AppSvg.send,
                                    size: 18,
                                    color: AppColors.ink,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _ModelButton extends StatelessWidget {
  final String model;
  final VoidCallback onTap;

  const _ModelButton({required this.model, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.pill),
      side: const BorderSide(color: AppColors.lineStrong),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AltairModelPresentation.icon(model),
            const SizedBox(width: 6),
            Text(
              AltairModelPresentation.fullLabel(model),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 3),
            const Icon(Icons.keyboard_arrow_down, size: 15),
          ],
        ),
      ),
    ),
  );
}
