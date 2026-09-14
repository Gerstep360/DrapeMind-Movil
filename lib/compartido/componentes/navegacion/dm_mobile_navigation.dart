import 'package:flutter/material.dart';

import 'package:drapemind_mobile/core/theme/app_colors.dart';
import 'package:drapemind_mobile/core/theme/app_design_tokens.dart';
import 'package:drapemind_mobile/core/theme/app_svg.dart';

class DmMobileNavigation extends StatelessWidget {
  final int selectedIndex;
  final int cartCount;
  final ValueChanged<int> onSelected;

  const DmMobileNavigation({
    super.key,
    required this.selectedIndex,
    required this.cartCount,
    required this.onSelected,
  });

  static const _labels = [
    'Showroom',
    'Altair',
    'Perchero',
    'Compras',
    'Perfil',
  ];
  static const _icons = [
    AppSvg.grid,
    AppSvg.sparkle,
    AppSvg.bag,
    AppSvg.package,
    AppSvg.user,
  ];

  @override
  Widget build(BuildContext context) => SafeArea(
    minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(AppRadii.large),
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.floating,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        child: Row(
          children: List.generate(_labels.length, (index) {
            final selected = index == selectedIndex;
            final isAltair = index == 1;
            final icon = AppSvg.raw(
              _icons[index],
              size: isAltair ? 21 : 19,
              color: selected || isAltair ? AppColors.ink : AppColors.textMuted,
            );
            return Expanded(
              child: Semantics(
                button: true,
                selected: selected,
                label: _labels[index],
                child: InkWell(
                  onTap: () => onSelected(index),
                  borderRadius: BorderRadius.circular(AppRadii.medium),
                  child: AnimatedContainer(
                    duration: AppMotion.normal,
                    curve: AppMotion.expressive,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isAltair
                          ? AppColors.lime
                          : selected
                          ? AppColors.ink
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadii.medium),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Badge(
                          isLabelVisible: index == 2 && cartCount > 0,
                          label: Text('$cartCount'),
                          backgroundColor: AppColors.lime,
                          textColor: AppColors.ink,
                          child: icon,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _labels[index],
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                          style: TextStyle(
                            color: selected && !isAltair
                                ? AppColors.white
                                : AppColors.ink,
                            fontSize: 9.5,
                            fontWeight: selected || isAltair
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    ),
  );
}
