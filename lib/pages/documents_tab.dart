import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:item_rdc/core/catalog.dart';
import 'package:item_rdc/core/catalog_store.dart';
import 'package:item_rdc/core/media_utils.dart';
import 'package:item_rdc/core/sorting.dart';
import 'package:item_rdc/widgets/media_tile.dart';
import 'package:item_rdc/core/icon_cache.dart';
import 'package:item_rdc/core/user_session.dart';
import 'package:item_rdc/pages/document_viewer_page.dart';
import 'package:item_rdc/pages/home_shell.dart';
import 'package:item_rdc/widgets/ui.dart';
import 'package:provider/provider.dart';

/// Onglet "Documents" : dossiers de PDF (général ou premium).
class DocumentsTab extends StatefulWidget {
  const DocumentsTab({super.key});

  @override
  State<DocumentsTab> createState() => _DocumentsTabState();
}

class _DocumentsTabState extends State<DocumentsTab> {
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

  /// Fichiers et sous-dossiers d'un dossier (récursif).
  List<Widget> _itemTiles(List<FolderItem> items, String keyPrefix) {
    return [
      for (final item in items)
        if (item.isFolder)
          SubFolderTile(
            storageKey: '${keyPrefix}_${item.title}',
            title: item.title,
            subtitle: "${item.fileCount} document(s)",
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
            meta: MediaUtils.kindLabel(item.url),
            year: item.year,
            icon: fileIconFor(item.url),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DocumentViewerPage(url: item.url, title: item.title),
              ),
            ),
          ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final premium = context.select<UserSession, bool>((s) => s.isPremium);
    final profileReady = context.select<UserSession, bool>((s) => s.docLoaded);

    // On attend le profil : sinon un compte Premium chargerait d'abord le
    // catalogue général puis changerait (double chargement visible).
    if (!profileReady) return const ResponsiveBody(child: SkeletonList());

    // Le flux n'est recréé que si le type de compte change.
    if (_stream == null || _premium != premium) {
      _premium = premium;
      // Flux partagé et déjà préchargé pendant l'écran de démarrage.
      _stream = CatalogStore.instance.watch(
        Catalog.homeCollection(premium),
        home: true,
      );
    }

    return ResponsiveBody(
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        initialData: CatalogStore.instance.last(Catalog.homeCollection(premium)),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const EmptyState(
              icon: Icons.error_outline_rounded,
              title: "Erreur de chargement",
              message: "Vérifiez votre connexion internet.",
            );
          }
          if (!snapshot.hasData) return const SkeletonList();

          final catalog = Catalog.fromSnapshot(
            snapshot.data!,
            query: _query,
            treatAllAsFolders: true,
          );
          IconCache.prefetch(catalog.iconUrls);
          final folders = Sorting.apply<ContentFolder>(
            catalog.folders,
            _sort,
            title: (f) => f.title,
            date: (f) => f.createdAt,
            count: (f) => f.fileCount,
          );

          return IconsGate(
            urls: catalog.iconUrls,
            placeholder: const SkeletonList(),
            child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 120),
            itemCount: folders.length + 3,
            itemBuilder: (context, i) {
              if (i == 0) {
                return BrandHeader(
                  icon: premium
                      ? Icons.workspace_premium_rounded
                      : Icons.folder_copy_rounded,
                  title: premium ? "Documents Premium" : "Documents généraux",
                  subtitle: "${catalog.folders.length} dossier(s) · ${catalog.totalItems} document(s)",
                );
              }
              if (i == 1) {
                return Column(
                  children: [
                    SearchPill(
                      controller: _search,
                      hint: "Rechercher un dossier ou un document…",
                      onChanged: (v) => setState(() => _query = v),
                    ),
                    if (!premium && _query.isEmpty) const _PremiumBanner(),
                    SortBar(
                      showViewMode: true,
                      value: _sort,
                      onChanged: (m) => setState(() => _sort = m),
                      trailing: "${folders.length} dossier(s)",
                    ),
                  ],
                );
              }
              if (folders.isEmpty) {
                return i == 2
                    ? Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: EmptyState(
                          icon: Icons.folder_off_rounded,
                          title: _query.isEmpty
                              ? "Aucun dossier pour le moment"
                              : "Aucun résultat",
                          message: _query.isEmpty
                              ? "Les nouveaux documents apparaîtront ici."
                              : "Essayez un autre mot-clé.",
                        ),
                      )
                    : const SizedBox.shrink();
              }
              if (i - 2 >= folders.length) return const SizedBox.shrink();

              final folder = folders[i - 2];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                child: FadeSlideIn(
                  index: i - 2,
                  child: FolderCard(
                    storageKey: 'doc_${folder.id}',
                    iconKey: folder.iconKey,
                    iconUrl: folder.iconUrl,
                    title: folder.title,
                    subtitle: "${folder.fileCount} document(s)",
                    initiallyExpanded: _query.isNotEmpty,
                    children: [
                      if (folder.items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text("Ce dossier est vide"),
                        ),
                      ..._itemTiles(folder.items, 'doc_${folder.id}'),
                    ],
                  ),
                ),
              );
            },
            ),
          );
        },
      ),
    );
  }
}

class _PremiumBanner extends StatelessWidget {
  const _PremiumBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () =>
              context.findAncestorStateOfType<HomeShellState>()?.goTo(3),
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                colors: [
                  Colors.amber.shade700.withValues(alpha: 0.9),
                  Colors.orange.shade800.withValues(alpha: 0.9),
                ],
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 30),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Passez Premium pour débloquer tous les cours et vidéos.",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
