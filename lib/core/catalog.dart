import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:item_rdc/core/sorting.dart';

class FolderItem {
  final String title;
  final String url;

  /// Sous-dossier : [children] contient ses fichiers (et [url] est vide).
  final bool isFolder;
  final List<FolderItem> children;

  /// Icône d'un sous-dossier (définie dans l'application admin) :
  /// clé prédéfinie et/ou URL d'image. Vides pour un fichier.
  final String? iconKey;
  final String? iconUrl;

  /// Date de création (vidéos "à plat" et sous-dossiers récents).
  final DateTime? createdAt;

  /// Détails d'un fichier : couverture (URL), propriétaire, description.
  final String cover;
  final String owner;
  final String details;
  final String year;
  const FolderItem({
    required this.title,
    required this.url,
    this.isFolder = false,
    this.children = const [],
    this.iconKey,
    this.iconUrl,
    this.createdAt,
    this.cover = '',
    this.owner = '',
    this.details = '',
    this.year = '',
  });

  /// Nombre de fichiers (les sous-dossiers sont comptés par leur contenu).
  int get fileCount =>
      isFolder ? children.fold<int>(0, (s, c) => s + c.fileCount) : 1;

  /// Lit `items` : fichiers `{title,url}` et sous-dossiers `{type:'folder',title,items}`.
  static List<FolderItem> parseList(dynamic raw) {
    if (raw is! List) return const [];
    final out = <FolderItem>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final title = (e['title'] ?? '').toString();
      if (e['type'] == 'folder' || e['items'] is List) {
        out.add(
          FolderItem(
            title: title,
            url: '',
            isFolder: true,
            children: parseList(e['items']),
            iconKey: (e['icon'] ?? '').toString(),
            iconUrl: (e['iconUrl'] ?? '').toString(),
            createdAt: Sorting.dateOf(e['createdAt']),
          ),
        );
      } else {
        out.add(
          FolderItem(
            title: title,
            url: (e['url'] ?? '').toString(),
            cover: (e['cover'] ?? '').toString(),
            owner: (e['owner'] ?? '').toString(),
            details: (e['details'] ?? '').toString(),
            year: (e['academicYear'] ?? '').toString(),
            createdAt: Sorting.dateOf(e['createdAt']),
          ),
        );
      }
    }
    return out;
  }

  /// Garde ce qui correspond à la recherche (un sous-dossier dont le titre
  /// correspond est gardé en entier).
  static List<FolderItem> filter(
    List<FolderItem> items,
    bool Function(String) match,
  ) {
    final out = <FolderItem>[];
    for (final it in items) {
      if (!it.isFolder) {
        if (match(it.title)) out.add(it);
        continue;
      }
      if (match(it.title)) {
        out.add(it);
        continue;
      }
      final kids = filter(it.children, match);
      if (kids.isNotEmpty) {
        out.add(
          FolderItem(
            title: it.title,
            url: '',
            isFolder: true,
            children: kids,
            iconKey: it.iconKey,
            iconUrl: it.iconUrl,
            createdAt: it.createdAt,
          ),
        );
      }
    }
    return out;
  }
}

class ContentFolder {
  final String id;
  final String title;
  final List<FolderItem> items;

  /// Icône définie dans l'application admin : clé prédéfinie et/ou URL d'image.
  final String? iconKey;
  final String? iconUrl;
  final DateTime? createdAt;
  const ContentFolder({
    required this.id,
    required this.title,
    required this.items,
    this.iconKey,
    this.iconUrl,
    this.createdAt,
  });

  /// Nombre total de fichiers, sous-dossiers compris.
  int get fileCount => items.fold<int>(0, (s, i) => s + i.fileCount);
}

/// Contenu d'une collection (PDF ou vidéos) : dossiers + éléments "à plat".
///
/// Compatible avec :
/// - PDF : documents `{title, items:[{title,url}]}`,
/// - Vidéos (nouveau) : documents `{type:'folder', title, items:[...]}`,
/// - Vidéos (ancien format) : documents `{title, url}` => `loose`.
class Catalog {
  final List<ContentFolder> folders;
  final List<FolderItem> loose;
  const Catalog({required this.folders, required this.loose});

  bool get isEmpty => folders.isEmpty && loose.isEmpty;

  /// URLs des icônes de dossiers ET de sous-dossiers (pour le préchargement).
  List<String> get iconUrls {
    final out = <String>[];
    void walk(List<FolderItem> items) {
      for (final it in items) {
        if (!it.isFolder) continue;
        final u = (it.iconUrl ?? '').trim();
        if (u.isNotEmpty) out.add(u);
        walk(it.children);
      }
    }

    for (final f in folders) {
      final u = (f.iconUrl ?? '').trim();
      if (u.isNotEmpty) out.add(u);
      walk(f.items);
    }
    return out;
  }

  int get totalItems =>
      loose.length + folders.fold<int>(0, (sum, f) => sum + f.fileCount);

  static String homeCollection(bool premium) =>
      premium ? 'PREMIUM_HOME' : 'GENERAL_HOME';

  static String videoCollection(bool premium) =>
      premium ? 'PREMIUM_VIDEOS' : 'GENERAL_VIDEOS';

  factory Catalog.fromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot, {
    String query = '',
    bool treatAllAsFolders = false,
  }) {
    final q = query.trim().toLowerCase();
    final folders = <ContentFolder>[];
    final loose = <FolderItem>[];

    bool match(String s) => q.isEmpty || s.toLowerCase().contains(q);

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final title = (data['title'] ?? '').toString();
      final created = Sorting.dateOf(
        data['createdAt'],
        pending: doc.metadata.hasPendingWrites,
      );
      final raw = data['items'];
      final isFolder =
          treatAllAsFolders || data['type'] == 'folder' || raw is List;

      if (isFolder) {
        var items = FolderItem.parseList(raw);

        if (q.isNotEmpty && !match(title)) {
          items = FolderItem.filter(items, match);
          if (items.isEmpty) continue;
        }
        folders.add(
          ContentFolder(
            id: doc.id,
            title: title,
            items: items,
            iconKey: (data['icon'] ?? '').toString(),
            iconUrl: (data['iconUrl'] ?? '').toString(),
            createdAt: created,
          ),
        );
      } else {
        final url = (data['url'] ?? '').toString();
        if (url.isEmpty || !match(title)) continue;
        loose.add(
          FolderItem(
            title: title,
            url: url,
            createdAt: created,
            cover: (data['cover'] ?? '').toString(),
            owner: (data['owner'] ?? '').toString(),
            details: (data['details'] ?? '').toString(),
            year: (data['academicYear'] ?? '').toString(),
          ),
        );
      }
    }
    return Catalog(folders: folders, loose: loose);
  }
}
