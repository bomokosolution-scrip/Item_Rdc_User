import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:item_rdc/core/app_theme.dart';
import 'package:item_rdc/core/catalog_store.dart';
import 'package:item_rdc/core/publishing.dart';
import 'package:item_rdc/core/supabase_storage.dart';

/// Formulaire « Publier un ouvrage » (TFC, Mémoire, Stage).
/// L'ouvrage reste « en attente » jusqu'à la validation de l'administrateur.
class PublishPage extends StatefulWidget {
  const PublishPage({super.key});

  @override
  State<PublishPage> createState() => _PublishPageState();
}

class _PublishPageState extends State<PublishPage> {
  static const List<String> _types = ['TFC', 'Mémoire', 'Stage'];

  String _type = 'TFC';
  String? _catId;
  String _catTitle = '';
  String? _uniId;
  String _uniName = '';
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _unis = [];
  bool _loadingUnis = false;

  final _title = TextEditingController();
  final _owner = TextEditingController();
  final _details = TextEditingController();

  String? _pdfPath;
  String _pdfName = '';
  int _pdfSize = 0;
  Uint8List? _cover;

  bool _sending = false;
  double _progress = 0;
  String _stage = '';

  @override
  void dispose() {
    _title.dispose();
    _owner.dispose();
    _details.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _loadUniversities(String catId) async {
    setState(() {
      _loadingUnis = true;
      _unis = [];
      _uniId = null;
      _uniName = '';
    });
    try {
      final snap = await FirebaseFirestore.instance
          .collection('categories')
          .doc(catId)
          .collection('universities')
          .get();
      if (!mounted || _catId != catId) return;
      final list = snap.docs.toList()
        ..sort(
          (a, b) => '${a.data()['name'] ?? ''}'.toLowerCase().compareTo(
            '${b.data()['name'] ?? ''}'.toLowerCase(),
          ),
        );
      setState(() => _unis = list);
    } catch (_) {
      if (mounted) _snack("Impossible de charger les universités.");
    } finally {
      if (mounted) setState(() => _loadingUnis = false);
    }
  }

  Future<void> _pickPdf() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
      final f = res?.files.single;
      if (f == null || f.path == null) return;
      if (f.size > SupabaseStorage.maxPdfBytes) {
        _snack("Ce PDF dépasse 25 Mo.");
        return;
      }
      setState(() {
        _pdfPath = f.path;
        _pdfName = f.name;
        _pdfSize = f.size;
      });
    } catch (e) {
      _snack("Sélection impossible : $e");
    }
  }

  Future<void> _pickCover() async {
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (mounted) setState(() => _cover = bytes);
    } catch (e) {
      _snack("Sélection impossible : $e");
    }
  }

  String _size(int bytes) => bytes >= 1024 * 1024
      ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo'
      : '${(bytes / 1024).round()} Ko';

  Future<void> _submit() async {
    if (_sending) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return _snack("Connectez-vous pour publier.");
    if (_catId == null || _uniId == null) {
      return _snack("Choisissez la catégorie et l'université.");
    }
    if (_title.text.trim().isEmpty) return _snack("Saisissez le titre de l'ouvrage.");
    if (_owner.text.trim().isEmpty) return _snack("Saisissez votre nom (propriétaire).");
    if (_pdfPath == null) return _snack("Choisissez le fichier PDF.");

    setState(() {
      _sending = true;
      _progress = 0;
      _stage = 'Vérification…';
    });
    try {
      final mine = await Publishing.collection.where('uid', isEqualTo: uid).get();
      final pending = mine.docs.where((d) => d.data()['status'] == 'pending').length;
      if (pending >= Publishing.maxPending) {
        throw StateError(
          "Vous avez déjà ${Publishing.maxPending} ouvrages en attente de validation. Patientez avant d'en envoyer un autre.",
        );
      }

      String coverUrl = '';
      if (_cover != null) {
        if (mounted) setState(() => _stage = 'Envoi de la couverture…');
        coverUrl = await SupabaseStorage.uploadCover(_cover!);
      }

      if (mounted) setState(() => _stage = 'Envoi du PDF…');
      final fileUrl = await SupabaseStorage.uploadPdf(
        File(_pdfPath!),
        folder: uid,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );

      if (mounted) setState(() => _stage = 'Finalisation…');
      await Publishing.collection.add({
        'uid': uid,
        'ownerName': _owner.text.trim(),
        'title': _title.text.trim(),
        'type': _type,
        'categoryId': _catId,
        'categoryTitle': _catTitle,
        'universityId': _uniId,
        'universityName': _uniName,
        'details': _details.text.trim(),
        'fileUrl': fileUrl,
        'coverUrl': coverUrl,
        'status': 'pending',
        'reason': '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Ouvrage envoyé"),
          content: const Text(
            "Merci ! Votre ouvrage est en attente de validation par l'administrateur. "
            "Vous pouvez suivre son statut dans « Mes publications ».",
          ),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK")),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        final msg = e is StateError ? e.message : "Échec de l'envoi : $e";
        _snack(msg);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
  );

  Widget _section(String title, Widget child) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accent(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Publier un ouvrage")),
      body: StreamBuilder<bool>(
        stream: Publishing.enabledStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.data != true) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_clock_rounded, size: 56, color: accent),
                    const SizedBox(height: 14),
                    const Text(
                      "Les publications sont fermées pour le moment",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "L'administrateur les rouvrira bientôt. Revenez plus tard.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                    ),
                  ],
                ),
              ),
            );
          }

          return AbsorbPointer(
            absorbing: _sending,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              children: [
                _section(
                  "Type d'ouvrage",
                  Wrap(
                    spacing: 10,
                    children: [
                      for (final t in _types)
                        ChoiceChip(
                          label: Text(t),
                          selected: _type == t,
                          onSelected: (_) => setState(() => _type = t),
                        ),
                    ],
                  ),
                ),
                _section(
                  "Où publier ?",
                  Column(
                    children: [
                      StreamBuilder<CatalogSnapshot>(
                        stream: CatalogStore.instance.watch('categories', withIcons: false),
                        initialData: CatalogStore.instance.last('categories'),
                        builder: (context, cs) {
                          final docs = cs.data?.docs.toList() ?? [];
                          docs.sort(
                            (a, b) => '${a.data()['title'] ?? ''}'.toLowerCase().compareTo(
                              '${b.data()['title'] ?? ''}'.toLowerCase(),
                            ),
                          );
                          return DropdownButtonFormField<String>(
                            // ignore: deprecated_member_use
                            value: docs.any((d) => d.id == _catId) ? _catId : null,
                            isExpanded: true,
                            decoration: _dec("Catégorie", Icons.category_rounded),
                            items: [
                              for (final d in docs)
                                DropdownMenuItem(
                                  value: d.id,
                                  child: Text(
                                    '${d.data()['title'] ?? ''}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (id) {
                              if (id == null) return;
                              final d = docs.firstWhere((x) => x.id == id);
                              setState(() {
                                _catId = id;
                                _catTitle = '${d.data()['title'] ?? ''}';
                              });
                              _loadUniversities(id);
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey('uni_$_catId${_unis.length}'),
                        // ignore: deprecated_member_use
                        value: _unis.any((d) => d.id == _uniId) ? _uniId : null,
                        isExpanded: true,
                        decoration: _dec(
                          _loadingUnis ? "Chargement…" : "Université",
                          Icons.school_rounded,
                        ),
                        items: [
                          for (final d in _unis)
                            DropdownMenuItem(
                              value: d.id,
                              child: Text(
                                '${d.data()['name'] ?? ''}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: _catId == null
                            ? null
                            : (id) {
                                if (id == null) return;
                                final d = _unis.firstWhere((x) => x.id == id);
                                setState(() {
                                  _uniId = id;
                                  _uniName = '${d.data()['name'] ?? ''}';
                                });
                              },
                      ),
                    ],
                  ),
                ),
                _section(
                  "Informations",
                  Column(
                    children: [
                      TextField(
                        controller: _title,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: _dec("Titre de l'ouvrage", Icons.title_rounded),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _owner,
                        textCapitalization: TextCapitalization.words,
                        decoration: _dec("Nom du propriétaire (auteur)", Icons.person_rounded),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _details,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: _dec("Détails (facultatif)", Icons.notes_rounded),
                      ),
                    ],
                  ),
                ),
                _section(
                  "Fichier PDF (25 Mo max)",
                  OutlinedButton.icon(
                    onPressed: _pickPdf,
                    icon: const Icon(Icons.picture_as_pdf_rounded),
                    label: Text(
                      _pdfPath == null
                          ? "Choisir le PDF"
                          : "$_pdfName · ${_size(_pdfSize)}",
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                _section(
                  "Couverture (facultatif)",
                  Row(
                    children: [
                      if (_cover != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(_cover!, width: 64, height: 82, fit: BoxFit.cover),
                          ),
                        ),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickCover,
                          icon: const Icon(Icons.add_photo_alternate_rounded),
                          label: Text(_cover == null ? "Choisir une image" : "Changer l'image"),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_sending) ...[
                  Text(_stage, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _stage == 'Envoi du PDF…' ? _progress : null,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  const SizedBox(height: 18),
                ],
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _sending ? null : _submit,
                    icon: const Icon(Icons.send_rounded),
                    label: const Text(
                      "Envoyer pour validation",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Votre ouvrage ne sera visible qu'après validation par l'administrateur.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
