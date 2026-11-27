import 'package:flutter/material.dart';
import 'package:item_rdc/core/app_theme.dart';
import 'package:item_rdc/core/media_utils.dart';
import 'package:item_rdc/core/view_mode.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

/// Miniature d'un fichier : couverture fournie > miniature YouTube automatique.
String coverUrlFor(String cover, String url) {
  final c = cover.trim();
  if (c.isNotEmpty) return c;
  final u = url.toLowerCase();
  if (u.contains('youtube.com') || u.contains('youtu.be')) {
    final id = YoutubePlayer.convertUrlToId(url);
    if (id != null) return 'https://img.youtube.com/vi/$id/hqdefault.jpg';
  }
  return '';
}

/// Icône selon le type de fichier (PDF, Word, Excel, PowerPoint).
IconData fileIconFor(String url) {
  switch (MediaUtils.kindLabel(url)) {
    case 'Word':
      return Icons.description_rounded;
    case 'Excel':
      return Icons.table_chart_rounded;
    case 'PowerPoint':
      return Icons.slideshow_rounded;
    default:
      return Icons.picture_as_pdf_rounded;
  }
}

String formatDate(DateTime? d) {
  if (d == null) return '';
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '$dd/$mm/${d.year}';
}

/// Image réseau avec fondu à l'apparition et repli propre en cas d'échec.
class CoverImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final Widget fallback;
  final int cacheWidth;

  const CoverImage({
    super.key,
    required this.url,
    required this.fallback,
    this.width,
    this.height,
    this.cacheWidth = 480,
  });

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) return fallback;
    return Image.network(
      url,
      width: width,
      height: height,
      fit: BoxFit.cover,
      cacheWidth: cacheWidth,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      frameBuilder: (context, child, frame, sync) {
        if (sync) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 180),
          child: child,
        );
      },
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}

/// Un fichier (PDF ou vidéo) affiché selon le mode choisi : liste, détails, grand.
class MediaTile extends StatelessWidget {
  final String title;
  final String url;
  final String cover;
  final String owner;
  final String details;

  /// Petit libellé (type, « PDF », « Vidéo »…).
  final String meta;

  /// Année académique (ex. 2024-2025), facultative.
  final String year;
  final DateTime? date;
  final IconData icon;
  final VoidCallback onTap;

  const MediaTile({
    super.key,
    required this.title,
    required this.url,
    required this.icon,
    required this.onTap,
    this.cover = '',
    this.owner = '',
    this.details = '',
    this.meta = '',
    this.year = '',
    this.date,
  });

  Widget _placeholder(BuildContext context, {double iconSize = 30}) {
    final accent = AppColors.accent(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withValues(alpha: 0.85), accent.withValues(alpha: 0.55)],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: Colors.white, size: iconSize),
    );
  }

  Widget _ownerLine(BuildContext context, {Color? color}) {
    if (owner.trim().isEmpty) return const SizedBox.shrink();
    final c = color ?? Theme.of(context).textTheme.bodyMedium?.color;
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Icon(Icons.person_rounded, size: 14, color: c),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              owner.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: c),
            ),
          ),
        ],
      ),
    );
  }

  String get _metaLine {
    final parts = <String>[
      if (meta.trim().isNotEmpty) meta.trim(),
      if (year.trim().isNotEmpty) year.trim(),
      if (date != null) formatDate(date),
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ViewMode>(
      valueListenable: ViewModeStore.instance,
      builder: (context, mode, _) {
        switch (mode) {
          case ViewMode.list:
            return _list(context);
          case ViewMode.details:
            return _details(context);
          case ViewMode.large:
            return _large(context);
        }
      },
    );
  }

  Widget _list(BuildContext context) {
    final theme = Theme.of(context);
    final cu = coverUrlFor(cover, url);
    return ListTile(
      dense: true,
      onTap: onTap,
      contentPadding: const EdgeInsets.only(left: 22, right: 16),
      leading: cu.isEmpty
          ? Icon(icon, color: AppColors.accent(context))
          : ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 40,
                height: 40,
                child: CoverImage(
                  url: cu,
                  width: 40,
                  height: 40,
                  cacheWidth: 120,
                  fallback: Icon(icon, color: AppColors.accent(context)),
                ),
              ),
            ),
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
      trailing: Icon(Icons.chevron_right_rounded, color: theme.textTheme.bodyMedium?.color),
    );
  }

  Widget _details(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.color;
    final cu = coverUrlFor(cover, url);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 16, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 64,
                height: 82,
                child: CoverImage(
                  url: cu,
                  width: 64,
                  height: 82,
                  cacheWidth: 192,
                  fallback: _placeholder(context),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: theme.listTileTheme.textColor,
                    ),
                  ),
                  _ownerLine(context),
                  if (_metaLine.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        _metaLine,
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                    ),
                  if (details.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        details.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: muted),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 28),
              child: Icon(Icons.chevron_right_rounded, color: muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _large(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.color;
    final cu = coverUrlFor(cover, url);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        elevation: 1.5,
        shadowColor: Colors.black26,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 10,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CoverImage(
                      url: cu,
                      cacheWidth: 720,
                      fallback: _placeholder(context, iconSize: 46),
                    ),
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: theme.listTileTheme.textColor,
                      ),
                    ),
                    _ownerLine(context),
                    if (_metaLine.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(_metaLine, style: TextStyle(fontSize: 12, color: muted)),
                      ),
                    if (details.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          details.trim(),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: muted),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
