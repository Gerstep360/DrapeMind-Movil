import 'package:flutter/material.dart';
import 'package:drapemind_mobile/core/theme/app_colors.dart';

class AltairComposer extends StatelessWidget {
  final TextEditingController controller;
  final bool isBusy;
  final VoidCallback onSend;
  final VoidCallback? onCancel;
  final VoidCallback onQuestionnaire;
  const AltairComposer({
    super.key,
    required this.controller,
    required this.isBusy,
    required this.onSend,
    this.onCancel,
    required this.onQuestionnaire,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.white,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) {
                  if (!isBusy) onSend();
                },
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '¿Qué te gustaría encontrar?',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  filled: true,
                  fillColor: AppColors.paper,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: AppColors.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: AppColors.line),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filled(
              tooltip: isBusy ? 'Detener respuesta' : 'Enviar mensaje',
              onPressed: isBusy ? onCancel : onSend,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: AppColors.white,
                minimumSize: const Size(48, 48),
              ),
              icon: Icon(
                isBusy ? Icons.stop_rounded : Icons.arrow_upward_rounded,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
