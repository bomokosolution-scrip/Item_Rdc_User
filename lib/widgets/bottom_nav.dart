import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:item_rdc/core/app_theme.dart';

class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const NavItem(this.icon, this.activeIcon, this.label);
}

/// Barre de navigation flottante : l'onglet actif s'élargit en douceur.
class AnimatedBottomNav extends StatelessWidget {
  final int currentIndex;
  final List<NavItem> items;
  final ValueChanged<int> onTap;

  const AnimatedBottomNav({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = AppColors.isDark(context);
    final selectedColor = dark ? AppColors.brandDark : AppColors.brand;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Container(
              height: 66,
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: dark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: dark ? 0.5 : 0.16),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, c) {
                  final n = items.length;
                  final selectedW = (c.maxWidth * 0.34).clamp(104.0, 170.0);
                  final otherW = (c.maxWidth - selectedW - 13) / (n - 1);

                  return Padding(
                    padding: const EdgeInsets.all(6),
                    child: Row(
                      children: [
                        for (int i = 0; i < n; i++)
                          _NavButton(
                            item: items[i],
                            selected: i == currentIndex,
                            width: i == currentIndex ? selectedW : otherW,
                            selectedColor: selectedColor,
                            onTap: () {
                              if (i != currentIndex) {
                                HapticFeedback.selectionClick();
                                onTap(i);
                              }
                            },
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final NavItem item;
  final bool selected;
  final double width;
  final Color selectedColor;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.selected,
    required this.width,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final inactive = Theme.of(context).textTheme.bodyMedium?.color;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          width: width,
          height: double.infinity,
          decoration: BoxDecoration(
            color: selected ? selectedColor : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  selected ? item.activeIcon : item.icon,
                  key: ValueKey(selected),
                  size: 24,
                  color: selected ? Colors.white : inactive,
                ),
              ),
              if (selected)
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6, right: 4),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        item.label,
                        maxLines: 1,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
