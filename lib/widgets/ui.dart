import 'package:flutter/material.dart';
import 'package:item_rdc/core/app_theme.dart';
import 'package:item_rdc/core/folder_icons.dart';
import 'package:item_rdc/core/icon_cache.dart';
import 'package:item_rdc/core/sorting.dart';
import 'package:item_rdc/core/view_mode.dart';

/// Centre le contenu et limite sa largeur (tablettes / grands écrans).
class ResponsiveBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const ResponsiveBody({super.key, required this.child, this.maxWidth = 720});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Apparition douce (fondu + glissement) : légère et sans contrôleur.
/// Seuls les premiers éléments s'animent (affichage immédiat, défilement fluide).
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final int index;
  const FadeSlideIn({super.key, required this.child, this.index = 0});

  @override
  Widget build(BuildContext context) {
    if (index > 5) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 140 + index * 20),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 12), child: child),
      ),
      child: child,
    );
  }
}

/// Image de fond décorative (traits bordeaux des assets), décodée à la
/// taille de l'écran pour rester rapide et légère en mémoire.
class BackdropImage extends StatelessWidget {
  final String asset;
  final Alignment alignment;
  final double opacity;
  const BackdropImage({
    super.key,
    required this.asset,
    this.alignment = Alignment.center,
    this.opacity = 1,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final w = (mq.size.width * mq.devicePixelRatio).round();
    final dark = AppColors.isDark(context);
    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: dark ? opacity * 0.55 : opacity,
          child: Image.asset(
            asset,
            fit: BoxFit.cover,
            alignment: alignment,
            cacheWidth: w > 0 ? w : null,
            filterQuality: FilterQuality.medium,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

/// Bandeau d'en-tête dégradé.
class BrandHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const BrandHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.headerGradient(context),
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Pastille d'icône teintée.
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double size;
  const IconBadge({super.key, required this.icon, this.color, this.size = 42});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.accent(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, color: c, size: size * 0.52),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final int? count;
  final IconData? icon;
  const SectionTitle(this.text, {super.key, this.count, this.icon});

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accent(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: accent),
            const SizedBox(width: 8),
          ],
          Text(
            text.toUpperCase(),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            InfoPill('$count'),
          ],
        ],
      ),
    );
  }
}

class InfoPill extends StatelessWidget {
  final String text;
  final Color? color;
  final IconData? icon;
  const InfoPill(this.text, {super.key, this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.accent(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: c), const SizedBox(width: 4)],
          Text(
            text,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconBadge(icon: icon, size: 72),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

/// Squelettes de chargement (pulsation douce, sans dépendance).
class SkeletonList extends StatefulWidget {
  final int count;
  final double itemHeight;
  const SkeletonList({super.key, this.count = 6, this.itemHeight = 72});

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Teinte visible sur fond clair comme sombre (une carte blanche sur fond blanc
    // donnait l'impression d'un écran vide).
    final base = Color.alphaBlend(
      theme.colorScheme.onSurface.withValues(alpha: 0.08),
      theme.cardTheme.color ?? theme.colorScheme.surface,
    );
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(_c),
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        itemCount: widget.count,
        itemBuilder: (_, _) => Container(
          height: widget.itemHeight,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}

/// Champ de recherche arrondi. Le contrôleur appartient à l'écran parent
/// (le texte survit au défilement de la liste).
class SearchPill extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  const SearchPill({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accent(context);
    final outline = Theme.of(context).dividerTheme.color ?? Colors.black12;

    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: color, width: width),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  ),
            border: border(Colors.transparent),
            enabledBorder: border(outline),
            focusedBorder: border(accent, 1.6),
          ),
        ),
      ),
    );
  }
}

/// Message court (succès / erreur).
void showToast(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: error ? const Color(0xFFB3261E) : null,
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}

/// Carte "dossier" dépliable commune aux documents, vidéos et bibliothèque.
class FolderCard extends StatelessWidget {
  final String storageKey;
  final String title;
  final String subtitle;
  final IconData leadingIcon;
  final String? iconKey;
  final String? iconUrl;
  final bool initiallyExpanded;
  final List<Widget> children;

  const FolderCard({
    super.key,
    required this.storageKey,
    required this.title,
    required this.subtitle,
    required this.children,
    this.leadingIcon = Icons.folder_rounded,
    this.iconKey,
    this.iconUrl,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey(storageKey),
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          iconColor: AppColors.accent(context),
          collapsedIconColor: theme.listTileTheme.iconColor,
          shape: const Border(),
          collapsedShape: const Border(),
          leading: FolderIconBadge(
            iconKey: iconKey,
            iconUrl: iconUrl,
            fallback: leadingIcon,
          ),
          title: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: theme.listTileTheme.textColor,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(color: theme.textTheme.bodyMedium?.color),
          ),
          children: children,
        ),
      ),
    );
  }
}

/// Sous-dossier à l'intérieur d'un dossier (déroulable).
class SubFolderTile extends StatelessWidget {
  final String storageKey;
  final String title;
  final String subtitle;
  final String? iconKey;
  final String? iconUrl;
  final bool initiallyExpanded;
  final List<Widget> children;

  const SubFolderTile({
    super.key,
    required this.storageKey,
    required this.title,
    required this.subtitle,
    required this.children,
    this.iconKey,
    this.iconUrl,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: PageStorageKey(storageKey),
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.only(left: 22, right: 16),
        childrenPadding: const EdgeInsets.only(left: 14),
        iconColor: AppColors.accent(context),
        collapsedIconColor: theme.listTileTheme.iconColor,
        shape: const Border(),
        collapsedShape: const Border(),
        leading: FolderIconBadge(
          iconKey: iconKey,
          iconUrl: iconUrl,
          size: 36,
          fallback: Icons.folder_open_rounded,
        ),
        title: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: theme.listTileTheme.textColor,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontSize: 12),
        ),
        children: children,
      ),
    );
  }
}

/// Ligne d'un contenu (PDF / vidéo) dans un dossier.
class ContentTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  const ContentTile({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      onTap: onTap,
      contentPadding: const EdgeInsets.only(left: 22, right: 16),
      leading: Icon(icon, color: AppColors.accent(context)),
      title: Text(
        title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: theme.listTileTheme.textColor,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: theme.textTheme.bodyMedium?.color,
      ),
    );
  }
}

/// Icône d'un dossier : image (URL) > icône prédéfinie > icône par défaut.
/// Les icônes sont définies depuis l'application administrateur.
class FolderIconBadge extends StatelessWidget {
  final String? iconKey;
  final String? iconUrl;
  final double size;
  final IconData fallback;

  const FolderIconBadge({
    super.key,
    this.iconKey,
    this.iconUrl,
    this.size = 42,
    this.fallback = Icons.folder_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final url = (iconUrl ?? '').trim();
    final badge = IconBadge(icon: FolderIcons.byKey(iconKey) ?? fallback, size: size);
    if (url.isEmpty) return badge;

    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.3),
      child: Container(
        width: size,
        height: size,
        color: Colors.white,
        child: CachedBadgeImage(
          url: url,
          size: size,
          fallback: badge,
          placeholder: ColoredBox(color: AppColors.accent(context).withValues(alpha: 0.08)),
        ),
      ),
    );
  }
}


/// Barre de tri : un bouton « pilule » qui ouvre le menu des modes de tri
/// (récents, anciens, A → Z, Z → A, plus de contenu) + un compteur optionnel.
class SortBar extends StatelessWidget {
  final SortMode value;
  final ValueChanged<SortMode> onChanged;
  final String? trailing;
  final bool allowCount;

  /// Affiche aussi le choix du mode d'affichage (liste / détails / grand).
  final bool showViewMode;
  final EdgeInsetsGeometry padding;

  const SortBar({
    super.key,
    required this.value,
    required this.onChanged,
    this.trailing,
    this.allowCount = true,
    this.showViewMode = false,
    this.padding = const EdgeInsets.fromLTRB(16, 6, 16, 2),
  });

  static String labelOf(SortMode m) {
    switch (m) {
      case SortMode.newest:
        return 'Plus récents';
      case SortMode.oldest:
        return 'Plus anciens';
      case SortMode.az:
        return 'A → Z';
      case SortMode.za:
        return 'Z → A';
      case SortMode.most:
        return 'Plus de contenu';
    }
  }

  static IconData iconOf(SortMode m) {
    switch (m) {
      case SortMode.newest:
        return Icons.schedule_rounded;
      case SortMode.oldest:
        return Icons.history_rounded;
      case SortMode.az:
        return Icons.sort_by_alpha_rounded;
      case SortMode.za:
        return Icons.sort_by_alpha_rounded;
      case SortMode.most:
        return Icons.folder_copy_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppColors.accent(context);
    final modes = [
      SortMode.newest,
      SortMode.oldest,
      SortMode.az,
      SortMode.za,
      if (allowCount) SortMode.most,
    ];
    final current = modes.contains(value) ? value : SortMode.newest;

    return Padding(
      padding: padding,
      child: Row(
        children: [
          PopupMenuButton<SortMode>(
            tooltip: 'Trier',
            initialValue: current,
            onSelected: onChanged,
            position: PopupMenuPosition.under,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            itemBuilder: (ctx) => [
              for (final m in modes)
                PopupMenuItem<SortMode>(
                  value: m,
                  child: Row(
                    children: [
                      Icon(
                        iconOf(m),
                        size: 20,
                        color: m == current ? accent : theme.textTheme.bodyMedium?.color,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          labelOf(m),
                          style: TextStyle(
                            fontWeight: m == current ? FontWeight.w800 : FontWeight.w500,
                            color: m == current ? accent : theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                      ),
                      if (m == current) Icon(Icons.check_rounded, size: 18, color: accent),
                    ],
                  ),
                ),
            ],
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.swap_vert_rounded, size: 18, color: accent),
                  const SizedBox(width: 6),
                  Text(
                    labelOf(current),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_drop_down_rounded, size: 20, color: accent),
                ],
              ),
            ),
          ),
          const Spacer(),
          if (trailing != null)
            Text(
              trailing!,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
          if (showViewMode) ...[
            const SizedBox(width: 6),
            const ViewModeButton(),
          ],
        ],
      ),
    );
  }
}


/// Choix du mode d'affichage des fichiers : Liste, Détails, Grand.
class ViewModeButton extends StatelessWidget {
  const ViewModeButton({super.key});

  static IconData iconOf(ViewMode m) {
    switch (m) {
      case ViewMode.list:
        return Icons.view_list_rounded;
      case ViewMode.details:
        return Icons.view_agenda_rounded;
      case ViewMode.large:
        return Icons.grid_view_rounded;
    }
  }

  static String labelOf(ViewMode m) {
    switch (m) {
      case ViewMode.list:
        return 'Liste';
      case ViewMode.details:
        return 'Détails';
      case ViewMode.large:
        return 'Grand';
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accent(context);
    return ValueListenableBuilder<ViewMode>(
      valueListenable: ViewModeStore.instance,
      builder: (context, current, _) => PopupMenuButton<ViewMode>(
        tooltip: 'Affichage',
        initialValue: current,
        onSelected: ViewModeStore.instance.choose,
        position: PopupMenuPosition.under,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        itemBuilder: (ctx) => [
          for (final m in ViewMode.values)
            PopupMenuItem<ViewMode>(
              value: m,
              child: Row(
                children: [
                  Icon(iconOf(m), size: 20, color: m == current ? accent : null),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      labelOf(m),
                      style: TextStyle(
                        fontWeight: m == current ? FontWeight.w800 : FontWeight.w500,
                        color: m == current ? accent : null,
                      ),
                    ),
                  ),
                  if (m == current) Icon(Icons.check_rounded, size: 18, color: accent),
                ],
              ),
            ),
        ],
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Icon(iconOf(current), size: 20, color: accent),
        ),
      ),
    );
  }
}
