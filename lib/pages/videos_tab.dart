import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:item_rdc/core/catalog.dart';
import 'package:item_rdc/core/catalog_store.dart';
import 'package:item_rdc/core/sorting.dart';
import 'package:item_rdc/widgets/media_tile.dart';
import 'package:item_rdc/core/icon_cache.dart';
import 'package:item_rdc/core/user_session.dart';
import 'package:item_rdc/pages/video_player_page.dart';
import 'package:item_rdc/widgets/ui.dart';
import 'package:provider/provider.dart';

/// Onglet "Vidéos" : dossiers de vidéos + vidéos sans dossier.
class VideosTab extends StatefulWidget {
  const VideosTab({super.key});

  @override
  State<VideosTab> createState() => _VideosTabState();
}

class _VideosTabState extends State<VideosTab> {
  bool? _premium;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _stream;
  String _query = '';
  SortMode _sort = SortMode.newest;
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(FolderItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoPlayerPage(url: item.url, title: item.title),
      ),
    );
  }

  /// Vidéos et sous-dossiers d'un dossier (récursif).
  List<Widget> _itemTiles(List<FolderItem> items, String keyPrefix) {
    return [
      for (final item in items)
        if (item.isFolder)
          SubFolderTile(
            storageKey: '${keyPrefix}_${item.title}',
            title: item.title,
            subtitle: "${item.fileCount} vidéo(s)",
            iconKey: item.iconKey,
            iconUrl: item.iconUrl,
            initiallyExpanded: _query.isNotEmpty,
            children: _itemTiles(item.children, '${keyPrefix}_${item.title}'),
          )
        else
          MediaTile(
            title: item.title,
            url: item.url,
            cover: item.cover,
            owner: item.owner,
            details: item.details,
            date: item.createdAt,
            meta: 'Vidéo',
            icon: Icons.play_circle_fill_rounded,
            onTap: () => _open(item),
          ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final premium = context.select<UserSession, bool>((s) => s.isPremium);
    final profileReady = context.select<UserSession, bool>((s) => s.docLoaded);
    if (!profileReady) return const ResponsiveBody(child: SkeletonList());

    if (_stream == null || _premium != premium) {
      _premium = premium;
      // Flux partagé et déjà préchargé. Pas de orderBy : il masquait les anciens
      // éléments sans `createdAt` ; le tri se fait ici (voir `_sort`).
      _stream = CatalogStore.instance.watch(Catalog.videoCollection(premium));
    }

    return ResponsiveBody(
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        initialData: CatalogStore.instance.last(Catalog.videoCollection(premium)),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const EmptyState(
              icon: Icons.error_outline_rounded,
              title: "Erreur de chargement",
              message: "Vérifiez votre connexion internet.",
            );
          }
          if (!snapshot.hasData) return const SkeletonList();

          final catalog = Catalog.fromSnapshot(snapshot.data!, query: _query);
          IconCache.prefetch(catalog.iconUrls);
          final folders = Sorting.apply<ContentFolder>(
            catalog.folders,
            _sort,
            title: (f) => f.title,
            date: (f) => f.createdAt,
            count: (f) => f.fileCount,
          );
          final loose = Sorting.apply<FolderItem>(
            catalog.loose,
            _sort,
            title: (v) => v.title,
            date: (v) => v.createdAt,
          );

          final rows = <Widget>[
            BrandHeader(
              icon: premium
                  ? Icons.workspace_premium_rounded
                  : Icons.play_circle_fill_rounded,
              title: premium ? "Leçons Premium" : "Leçons générales",
              subtitle: "${catalog.folders.length} dossier(s) · ${catalog.totalItems} vidéo(s)",
            ),
            SearchPill(
              controller: _search,
              hint: "Rechercher une vidéo ou un dossier…",
              onChanged: (v) => setState(() => _query = v),
            ),
            SortBar(
              showViewMode: true,
              value: _sort,
              allowCount: folders.isNotEmpty,
              onChanged: (m) => setState(() => _sort = m),
              trailing: "${catalog.totalItems} vidéo(s)",
            ),
          ];

          if (catalog.isEmpty) {
            rows.add(
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: EmptyState(
                  icon: Icons.video_library_rounded,
                  title: _query.isEmpty
                      ? "Aucune vidéo pour le moment"
                      : "Aucune vidéo trouvée",
                  message: _query.isEmpty
                      ? "Les nouvelles leçons apparaîtront ici."
                      : "Essayez un autre mot-clé.",
                ),
              ),
            );
          }

          if (folders.isNotEmpty) {
            rows.add(
              SectionTitle("Dossiers", count: folders.length, icon: Icons.folder_rounded),
            );
            for (int i = 0; i < folders.length; i++) {
              final folder = folders[i];
              rows.add(
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                  child: FadeSlideIn(
                    index: i,
                    child: FolderCard(
                      storageKey: 'vid_${folder.id}',
                      iconKey: folder.iconKey,
                      iconUrl: folder.iconUrl,
                      title: folder.title,
                      subtitle: "${folder.fileCount} vidéo(s)",
                      initiallyExpanded: _query.isNotEmpty,
                      children: [
                        if (folder.items.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text("Ce dossier est vide"),
                          ),
                        ..._itemTiles(folder.items, 'vid_${folder.id}'),
                      ],
                    ),
                  ),
                ),
              );
            }
          }

          if (loose.isNotEmpty) {
            rows.add(
              SectionTitle(
                folders.isEmpty ? "Vidéos" : "Autres vidéos",
                count: loose.length,
                icon: Icons.video_collection_outlined,
              ),
            );
            for (int i = 0; i < loose.length; i++) {
              final item = loose[i];
              rows.add(
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: FadeSlideIn(
                    index: i,
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        onTap: () => _open(item),
                        contentPadding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
                        leading: const IconBadge(icon: Icons.play_arrow_rounded),
                        title: Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).listTileTheme.textColor,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }
          }

          return IconsGate(
            urls: catalog.iconUrls,
            placeholder: const SkeletonList(),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 120),
              children: rows,
            ),
          );
        },
      ),
    );
  }
}
