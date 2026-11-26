import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:item_rdc/core/app_theme.dart';
import 'package:item_rdc/core/catalog_store.dart';
import 'package:item_rdc/core/sorting.dart';
import 'package:item_rdc/core/view_mode.dart';
import 'package:item_rdc/widgets/media_tile.dart';
import 'package:item_rdc/core/icon_cache.dart';
import 'package:item_rdc/core/media_utils.dart';
import 'package:item_rdc/pages/document_viewer_page.dart';
import 'package:item_rdc/pages/video_player_page.dart';
import 'package:item_rdc/widgets/ui.dart';

String _str(Map<String, dynamic> d, String k) => (d[k] ?? '').toString();

DateTime? _created(QueryDocumentSnapshot<Map<String, dynamic>> d) =>
    Sorting.dateOf(d.data()['createdAt'], pending: d.metadata.hasPendingWrites);

/// Onglet "Bibliothèque" : catégories.
class LibraryTab extends StatefulWidget {
  const LibraryTab({super.key});

  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> {
  // Flux partagé, déjà préchargé pendant l'écran de démarrage.
  final Stream<QuerySnapshot<Map<String, dynamic>>> _stream =
      CatalogStore.instance.watch('categories', withIcons: false);
  final _search = TextEditingController();
  String _query = '';
  SortMode _sort = SortMode.newest;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveBody(
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        initialData: CatalogStore.instance.last('categories'),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const EmptyState(
              icon: Icons.error_outline_rounded,
              title: "Erreur de chargement",
            );
          }
          if (!snapshot.hasData) return const SkeletonList();

          final q = _query.toLowerCase();
          final docs = Sorting.apply<QueryDocumentSnapshot<Map<String, dynamic>>>(
            snapshot.data!.docs.where(
              (d) => q.isEmpty || _str(d.data(), 'title').toLowerCase().contains(q),
            ),
            _sort,
            title: (d) => _str(d.data(), 'title'),
            date: _created,
          );

          return ListView(
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              BrandHeader(
                icon: Icons.local_library_rounded,
                title: "Bibliothèque universitaire",
                subtitle: "${docs.length} catégorie(s)",
              ),
              SearchPill(
                controller: _search,
                hint: "Rechercher une catégorie…",
                onChanged: (v) => setState(() => _query = v),
              ),
              SortBar(
                value: _sort,
                allowCount: false,
                onChanged: (m) => setState(() => _sort = m),
                trailing: "${docs.length} catégorie(s)",
              ),
              if (docs.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: EmptyState(
                    icon: Icons.local_library_outlined,
                    title: "Aucun contenu trouvé",
                  ),
                ),
              for (int i = 0; i < docs.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                  child: FadeSlideIn(
                    index: i,
                    child: _NavCard(
                      icon: Icons.category_rounded,
                      title: _str(docs[i].data(), 'title'),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => UniversityPage(
                            categoryId: docs[i].id,
                            categoryTitle: _str(docs[i].data(), 'title'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? leading;
  final VoidCallback onTap;
  const _NavCard({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
        leading: leading ?? IconBadge(icon: icon),
        title: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: theme.listTileTheme.textColor,
          ),
        ),
        subtitle: subtitle == null || subtitle!.isEmpty ? null : Text(subtitle!),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: theme.textTheme.bodyMedium?.color,
        ),
      ),
    );
  }
}

// ----------------------------------------------------------- Universités

class UniversityPage extends StatefulWidget {
  final String categoryId;
  final String categoryTitle;
  const UniversityPage({
    super.key,
    required this.categoryId,
    required this.categoryTitle,
  });

  @override
  State<UniversityPage> createState() => _UniversityPageState();
}

class _UniversityPageState extends State<UniversityPage> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream =
      FirebaseFirestore.instance
          .collection('categories')
          .doc(widget.categoryId)
          .collection('universities')
          .snapshots();
  final _search = TextEditingController();
  String _query = '';
  SortMode _sort = SortMode.newest;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.categoryTitle)),
      body: ResponsiveBody(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const EmptyState(
                icon: Icons.error_outline_rounded,
                title: "Erreur de chargement",
              );
            }
            if (!snapshot.hasData) return const SkeletonList();

            final q = _query.toLowerCase();
            final docs = Sorting.apply<QueryDocumentSnapshot<Map<String, dynamic>>>(
              snapshot.data!.docs.where(
                (d) => q.isEmpty || _str(d.data(), 'name').toLowerCase().contains(q),
              ),
              _sort,
              title: (d) => _str(d.data(), 'name'),
              date: _created,
            );
            // Les logos se préparent dès l'arrivée des données.
            IconCache.prefetch([
              for (final d in docs) _str(d.data(), 'logoUrl'),
            ]);

            return ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                BrandHeader(
                  icon: Icons.school_rounded,
                  title: widget.categoryTitle,
                  subtitle: "${docs.length} université(s)",
                ),
                SearchPill(
                  controller: _search,
                  hint: "Rechercher une université…",
                  onChanged: (v) => setState(() => _query = v),
                ),
                SortBar(
                  value: _sort,
                  allowCount: false,
                  onChanged: (m) => setState(() => _sort = m),
                  trailing: "${docs.length} université(s)",
                ),
                if (docs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: EmptyState(
                      icon: Icons.school_outlined,
                      title: "Aucun contenu trouvé",
                    ),
                  ),
                for (int i = 0; i < docs.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                    child: FadeSlideIn(
                      index: i,
                      child: _NavCard(
                        icon: Icons.school_rounded,
                        title: _str(docs[i].data(), 'name'),
                        leading: _UniLogo(url: _str(docs[i].data(), 'logoUrl')),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => DocumentPage(
                              universityId: docs[i].id,
                              uniName: _str(docs[i].data(), 'name'),
                              categoryId: widget.categoryId,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _UniLogo extends StatelessWidget {
  final String url;
  const _UniLogo({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return const IconBadge(icon: Icons.school_rounded);
    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: Container(
        width: 42,
        height: 42,
        color: Colors.white,
        child: CachedBadgeImage(
          url: url,
          size: 42,
          fallback: const IconBadge(icon: Icons.school_rounded),
          placeholder: ColoredBox(
            color: AppColors.accent(context).withValues(alpha: 0.08),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- Documents

class DocumentPage extends StatefulWidget {
  final String universityId;
  final String uniName;
  final String categoryId;
  const DocumentPage({
    super.key,
    required this.universityId,
    required this.uniName,
    required this.categoryId,
  });

  @override
  State<DocumentPage> createState() => _DocumentPageState();
}

class _DocumentPageState extends State<DocumentPage> {
  static const _filters = ["All", "TFC", "Mémoire", "Stage"];

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream =
      FirebaseFirestore.instance
          .collection('categories')
          .doc(widget.categoryId)
          .collection('universities')
          .doc(widget.universityId)
          .collection('documents')
          .snapshots();

  final _search = TextEditingController();
  String _query = '';
  String _filter = "All";
  SortMode _sort = SortMode.newest;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  IconData _iconFor(String url) {
    if (MediaUtils.isYoutube(url)) return Icons.ondemand_video_rounded;
    if (MediaUtils.looksLikeVideoFile(url)) return Icons.video_library_rounded;
    if (MediaUtils.isDrive(url)) return Icons.cloud_rounded;
    if (MediaUtils.looksLikePdf(url)) return Icons.picture_as_pdf_rounded;
    return Icons.insert_drive_file_rounded;
  }

  void _open(String url, String title, String type) {
    if (url.trim().isEmpty) {
      showToast(context, "Ce document n'a pas de lien.", error: true);
      return;
    }
    final isVideo =
        MediaUtils.isYoutube(url) ||
        MediaUtils.looksLikeVideoFile(url) ||
        (MediaUtils.isDrive(url) && type.toLowerCase().contains('video'));
    final isDoc = MediaUtils.looksLikePdf(url) || MediaUtils.isDrive(url);

    if (isVideo) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => VideoPlayerPage(url: url, title: title)),
      );
    } else if (isDoc) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DocumentViewerPage(url: url, title: title)),
      );
    } else {
      showToast(context, "Type de fichier non pris en charge.", error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(widget.uniName)),
      body: ResponsiveBody(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const EmptyState(
                icon: Icons.error_outline_rounded,
                title: "Erreur de chargement",
              );
            }
            if (!snapshot.hasData) return const SkeletonList();

            final q = _query.toLowerCase();
            var docs = snapshot.data!.docs.where((snap) {
              final d = snap.data();
              final type = normType(d['type']);
              final matchType = _filter == "All" || type == _filter;
              final matchQuery = q.isEmpty || _str(d, 'title').toLowerCase().contains(q);
              return matchType && matchQuery;
            }).toList();

            if (_filter == "All") {
              final seen = <String>{};
              docs = docs.where((snap) => seen.add(_str(snap.data(), 'title'))).toList();
            }

            final sorted = Sorting.apply<QueryDocumentSnapshot<Map<String, dynamic>>>(
              docs,
              _sort,
              title: (d) => _str(d.data(), 'title'),
              date: _created,
            );
            final items = [for (final d in sorted) d.data()];

            return ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                BrandHeader(
                  icon: Icons.description_rounded,
                  title: widget.uniName,
                  subtitle: "${items.length} document(s)",
                ),
                SearchPill(
                  controller: _search,
                  hint: "Rechercher un document…",
                  onChanged: (v) => setState(() => _query = v),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final f in _filters)
                        ChoiceChip(
                          label: Text(f),
                          selected: _filter == f,
                          showCheckmark: false,
                          selectedColor: theme.brightness == Brightness.dark
                              ? AppColors.brandDark
                              : AppColors.brand,
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _filter == f
                                ? Colors.white
                                : theme.textTheme.bodyMedium?.color,
                          ),
                          onSelected: (_) => setState(() => _filter = f),
                        ),
                    ],
                  ),
                ),
                SortBar(
                  showViewMode: true,
                  value: _sort,
                  allowCount: false,
                  onChanged: (m) => setState(() => _sort = m),
                  trailing: "${items.length} document(s)",
                ),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: EmptyState(
                      icon: Icons.description_outlined,
                      title: "Aucun contenu trouvé",
                    ),
                  ),
                for (int i = 0; i < items.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: FadeSlideIn(
                      index: i,
                      child: ValueListenableBuilder<ViewMode>(
                        valueListenable: ViewModeStore.instance,
                        builder: (context, mode, _) {
                          final it = items[i];
                          final label = it['isAll'] == true ? "All" : normType(it['type']);
                          final owner = _str(it, 'owner');
                          void open() => _open(
                            _str(it, 'url'),
                            _str(it, 'title'),
                            _str(it, 'type'),
                          );
                          if (mode == ViewMode.list) {
                            return _NavCard(
                              icon: _iconFor(_str(it, 'url')),
                              title: _str(it, 'title'),
                              subtitle: owner.isEmpty ? label : "$label · $owner",
                              onTap: open,
                            );
                          }
                          return MediaTile(
                            title: _str(it, 'title'),
                            url: _str(it, 'url'),
                            cover: _str(it, 'cover'),
                            owner: owner,
                            details: _str(it, 'details'),
                            date: Sorting.dateOf(it['createdAt']),
                            meta: label,
                            icon: _iconFor(_str(it, 'url')),
                            onTap: open,
                          );
                        },
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
