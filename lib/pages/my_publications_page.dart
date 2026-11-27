import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:item_rdc/core/app_theme.dart';
import 'package:item_rdc/core/publishing.dart';
import 'package:item_rdc/core/sorting.dart';
import 'package:item_rdc/pages/document_viewer_page.dart';
import 'package:item_rdc/pages/home_shell.dart';
import 'package:item_rdc/pages/library_page.dart';
import 'package:item_rdc/widgets/media_tile.dart';

/// « Mes publications » : statut de chaque ouvrage envoyé.
class MyPublicationsPage extends StatelessWidget {
  const MyPublicationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Mes publications")),
      body: uid == null
          ? const Center(child: Text("Connectez-vous pour voir vos publications."))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: Publishing.collection.where('uid', isEqualTo: uid).snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Center(child: Text("Erreur de chargement."));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = Sorting.apply<QueryDocumentSnapshot<Map<String, dynamic>>>(
                  snap.data!.docs,
                  SortMode.newest,
                  title: (d) => '${d.data()['title'] ?? ''}',
                  date: (d) => Sorting.dateOf(
                    d.data()['createdAt'],
                    pending: d.metadata.hasPendingWrites,
                  ),
                );
                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 54,
                            color: AppColors.accent(context),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            "Aucune publication",
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Vos ouvrages envoyés apparaîtront ici avec leur statut.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _card(context, docs[i].data()),
                );
              },
            ),
    );
  }

  /// « TFC · 2025-2026 · Catégorie › Université » ou « Document · Dossier › Sous-dossier ».
  String _where(Map<String, dynamic> d) {
    final year = '${d['academicYear'] ?? ''}'.trim();
    final head = [
      '${d['type'] ?? ''}',
      if (year.isNotEmpty) year,
    ].join(' · ');
    if ('${d['kind'] ?? 'work'}' == 'document') {
      final sub = '${d['subFolderTitle'] ?? ''}'.trim();
      final folder = '${d['folderTitle'] ?? ''}';
      return '$head · $folder${sub.isEmpty ? '' : ' › $sub'}';
    }
    return '$head · ${d['categoryTitle'] ?? ''} › ${d['universityName'] ?? ''}';
  }

  Widget _card(BuildContext context, Map<String, dynamic> d) {
    final theme = Theme.of(context);
    final status = '${d['status'] ?? 'pending'}';
    late final String label;
    late final Color color;
    late final IconData icon;
    switch (status) {
      case 'approved':
        label = 'Publié';
        color = const Color(0xFF2E9E5B);
        icon = Icons.check_circle_rounded;
        break;
      case 'refused':
        label = 'Refusé';
        color = const Color(0xFFC62828);
        icon = Icons.cancel_rounded;
        break;
      default:
        label = 'En attente de validation';
        color = const Color(0xFFE08A00);
        icon = Icons.hourglass_top_rounded;
    }
    final reason = '${d['reason'] ?? ''}'.trim();
    final cover = '${d['coverUrl'] ?? ''}';

    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(18),
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context, d),
        child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 56,
                height: 72,
                child: CoverImage(
                  url: cover,
                  width: 56,
                  height: 72,
                  cacheWidth: 168,
                  fallback: Container(
                    color: AppColors.accent(context).withValues(alpha: 0.15),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.picture_as_pdf_rounded,
                      color: AppColors.accent(context),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${d['title'] ?? ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _where(d),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 15, color: color),
                        const SizedBox(width: 5),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (status == 'refused' && reason.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        "Motif : $reason",
                        style: TextStyle(fontSize: 12.5, color: theme.textTheme.bodyMedium?.color),
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

  /// Toucher une publication : ouvrir le fichier, ou aller là où il est publié.
  void _open(BuildContext context, Map<String, dynamic> d) {
    final url = '${d['fileUrl'] ?? ''}';
    final title = '${d['title'] ?? ''}';
    final approved = '${d['status'] ?? 'pending'}' == 'approved';
    final isDoc = '${d['kind'] ?? 'work'}' == 'document';

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.visibility_rounded),
              title: const Text("Ouvrir le fichier"),
              onTap: () {
                Navigator.pop(ctx);
                if (url.isEmpty) return;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DocumentViewerPage(url: url, title: title),
                  ),
                );
              },
            ),
            if (approved && !isDoc && '${d['universityId'] ?? ''}'.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.school_rounded),
                title: Text("Voir dans ${d['universityName'] ?? "l'université"}"),
                subtitle: Text('${d['categoryTitle'] ?? ''}'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DocumentPage(
                        universityId: '${d['universityId']}',
                        uniName: '${d['universityName'] ?? ''}',
                        categoryId: '${d['categoryId'] ?? ''}',
                      ),
                    ),
                  );
                },
              ),
            if (approved && isDoc)
              ListTile(
                leading: const Icon(Icons.folder_open_rounded),
                title: Text("Voir dans le dossier « ${d['folderTitle'] ?? ''} »"),
                subtitle: '${d['subFolderTitle'] ?? ''}'.isEmpty
                    ? null
                    : Text('Sous-dossier : ${d['subFolderTitle']}'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).popUntil((r) => r.isFirst);
                  HomeShellState.current?.goTo(0);
                },
              ),
            if (!approved)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(
                  "Le dossier sera accessible après validation par l'administrateur.",
                  style: TextStyle(fontSize: 12.5),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
