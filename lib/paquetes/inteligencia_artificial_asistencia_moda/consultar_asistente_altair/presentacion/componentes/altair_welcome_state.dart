import 'package:flutter/material.dart';
import 'package:drapemind_mobile/core/theme/app_colors.dart';

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
    padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.lime,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(
            Icons.auto_awesome_outlined,
            size: 26,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 25),
        const Text(
          'Un poco de inspiración.\nMucho de tu estilo.',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            height: 1.15,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Soy Altair. Cuéntame qué buscas o para qué ocasión quieres vestirte. Encontraremos algo que vaya contigo.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textMutedStrong,
            height: 1.65,
          ),
        ),
        const SizedBox(height: 28),
        _Suggestion(
          icon: Icons.checkroom_outlined,
          title: 'Un look para una ocasión',
          description: 'Una cena, la oficina o tu próximo plan.',
          onTap: () => onPrompt(
            'Ayúdame a elegir un look para una ocasión. Pregúntame qué plan tengo.',
          ),
        ),
        _Suggestion(
          icon: Icons.manage_search_rounded,
          title: 'Algo que tengo en mente',
          description: 'Busquemos por color, talla y presupuesto.',
          onTap: () => onPrompt(
            'Quiero encontrar una prenda. Ayúdame a precisar el tipo, talla y presupuesto.',
          ),
        ),
        _Suggestion(
          icon: Icons.shopping_bag_outlined,
          title: 'Combinar lo que elegí',
          description: 'Ideas para las prendas de tu carrito.',
          onTap: () => onPrompt(
            'Revisa mi carrito y ayúdame a combinar las prendas que elegí.',
          ),
        ),
      ],
    ),
  );
}

class _Suggestion extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  const _Suggestion({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.line),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(icon, size: 23, color: AppColors.ink),
        trailing: const Icon(Icons.arrow_forward_rounded, size: 18),
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMutedStrong,
            ),
          ),
        ),
      ),
    ),
  );
}
