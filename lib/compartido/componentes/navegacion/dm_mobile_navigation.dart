import 'package:flutter/material.dart';
import 'package:drapemind_mobile/core/theme/app_colors.dart';
import 'package:drapemind_mobile/core/theme/app_svg.dart';

class DmMobileNavigation extends StatelessWidget {
  final int selectedIndex;
  final int cartCount;
  final ValueChanged<int> onSelected;
  final bool business;
  const DmMobileNavigation({
    super.key,
    required this.selectedIndex,
    required this.cartCount,
    required this.onSelected,
    this.business = false,
  });

  static const _labels = ['Tienda', 'Altair', 'Carrito', 'Pedidos', 'Cuenta'];
  static const _icons = [
    AppSvg.grid,
    AppSvg.sparkle,
    AppSvg.bag,
    AppSvg.package,
    AppSvg.user,
  ];

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.white,
    child: SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: List.generate(_labels.length, (index) {
            final selected = index == selectedIndex;
            return Expanded(
              child: Semantics(
                button: true,
                selected: selected,
                label: business && index == 4 ? 'Negocio' : _labels[index],
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onSelected(index),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.lime
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Badge(
                            isLabelVisible: index == 2 && cartCount > 0,
                            label: Text(cartCount > 99 ? '99+' : '$cartCount'),
                            backgroundColor: AppColors.ink,
                            textColor: Colors.white,
                            child: AppSvg.raw(
                              business && index == 4
                                  ? AppSvg.store
                                  : _icons[index],
                              size: 21,
                              color: selected
                                  ? AppColors.ink
                                  : AppColors.textMutedStrong,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          business && index == 4 ? 'Negocio' : _labels[index],
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.ink,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
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
