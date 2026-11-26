import 'package:flutter/material.dart';
import 'package:item_rdc/core/app_theme.dart';
import 'package:provider/provider.dart';

/// Bouton « mode clair / mode sombre » : affiche l'icône du mode vers lequel
/// on bascule (soleil en mode sombre, lune en mode clair).
class ThemeToggleButton extends StatelessWidget {
  /// Couleur forcée (ex. sur un fond toujours sombre) ; sinon celle du thème.
  final Color? color;
  final double size;
  const ThemeToggleButton({super.key, this.color, this.size = 24});

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark(context);
    return IconButton(
      tooltip: dark ? "Mode clair" : "Mode sombre",
      visualDensity: VisualDensity.compact,
      iconSize: size,
      color: color,
      onPressed: () => context.read<ThemeManager>().toggleTheme(!dark),
      icon: Icon(dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
    );
  }
}
