import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:item_rdc/core/app_theme.dart';
import 'package:item_rdc/core/chat_service.dart';
import 'package:item_rdc/core/supabase_storage.dart';
import 'package:item_rdc/pages/chat_page.dart';
import 'package:item_rdc/widgets/chat_bubble.dart';

String _dateLabel(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(d.year, d.month, d.day);
  final diff = today.difference(that).inDays;
  final day = diff == 0
      ? "Aujourd'hui"
      : diff == 1
          ? "Hier"
          : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  return '$day · ${chatHm(d)}';
}

DateTime? _timeOf(ChatDoc d) {
  final t = d.data()['createdAt'];
  if (t is Timestamp) return t.toDate();
  if (d.metadata.hasPendingWrites) return DateTime.now();
  return null;
}

String _helpError(Object e) {
  if (e is FirebaseException && e.code == 'permission-denied') {
    return "Envoi refusé : compte suspendu ou espace d'entraide fermé.";
  }
  if (e is FormatException) return e.message;
  return "Échec : $e";
}

// ---------------------------------------------------------------------------
//  Liste des demandes d'aide
// ---------------------------------------------------------------------------
class HelpTab extends StatefulWidget {
  final String uid;
  final String pseudo;
  const HelpTab({super.key, required this.uid, required this.pseudo});

  @override
  State<HelpTab> createState() => _HelpTabState();
}

class _HelpTabState extends State<HelpTab> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream = ChatService.helpLatest();
  String _filter = 'all'; // all | open | solved

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppColors.accent(context);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return const ChatNotice(
            icon: Icons.error_outline_rounded,
            title: "Chargement impossible",
            message: "Vérifiez votre connexion et réessayez.",
          );
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final all = snap.data!.docs;
        final docs = all.where((d) {
          final s = '${d.data()['status'] ?? 'open'}';
          return _filter == 'all' || s == _filter;
        }).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
          children: [
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => HelpComposePage(uid: widget.uid, pseudo: widget.pseudo),
                  ),
                ),
                icon: const Icon(Icons.add_a_photo_rounded),
                label: const Text(
                  "Demander de l'aide",
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final f in const [
                    ['all', 'Toutes'],
                    ['open', 'Ouvertes'],
                    ['solved', 'Résolues'],
                  ])
                    ChoiceChip(
                      label: Text(f[1]),
                      selected: _filter == f[0],
                      onSelected: (_) => setState(() => _filter = f[0]),
                    ),
                ],
              ),
            ),
            if (docs.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: ChatNotice(
                  icon: Icons.support_rounded,
                  title: all.isEmpty ? "Aucune demande" : "Rien dans ce filtre",
                  message: "Postez une capture de votre TP ou de votre problème : les autres vous répondront.",
                ),
              ),
            for (final p in docs) _card(context, theme, accent, p),
          ],
        );
      },
    );
  }

  Widget _card(BuildContext context, ThemeData theme, Color accent, ChatDoc p) {
    final d = p.data();
    final mine = d['uid'] == widget.uid;
    final solved = '${d['status'] ?? 'open'}' == 'solved';
    final image = '${d['imageUrl'] ?? ''}';
    final when = _timeOf(p);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => HelpPostPage(postId: p.id, uid: widget.uid, pseudo: widget.pseudo),
          ),
        ),
        onLongPress: mine
            ? null
            : () => _reportSheet(
                  context,
                  postId: p.id,
                  text: '${d['text'] ?? ''}',
                  targetUid: '${d['uid'] ?? ''}',
                  targetPseudo: '${d['pseudo'] ?? ''}',
                ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${d['pseudo'] ?? ''}${mine ? ' (vous)' : ''}',
                      style: TextStyle(fontWeight: FontWeight.w800, color: accent),
                    ),
                  ),
                  if (solved)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E9E5B).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        "Résolu",
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2E9E5B),
                        ),
                      ),
                    ),
                ],
              ),
              if (when != null)
                Text(_dateLabel(when),
                    style: TextStyle(fontSize: 11.5, color: theme.textTheme.bodyMedium?.color)),
              const SizedBox(height: 8),
              Text('${d['text'] ?? ''}', style: const TextStyle(fontSize: 15)),
              if (image.isNotEmpty) ...[
                const SizedBox(height: 10),
                ChatImage(url: image, maxHeight: 260),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.forum_outlined, size: 18, color: accent),
                  const SizedBox(width: 6),
                  Text(
                    "Voir / répondre",
                    style: TextStyle(fontWeight: FontWeight.w700, color: accent),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Feuille de signalement d'une question ou d'une réponse d'entraide.
void _reportSheet(
  BuildContext context, {
  required String postId,
  String replyId = '',
  required String text,
  required String targetUid,
  required String targetPseudo,
}) {
  const reasons = [
    "Insulte ou harcèlement",
    "Spam ou publicité",
    "Contenu inapproprié",
    "Autre",
  ];
  final me = FirebaseAuth.instance.currentUser?.uid;
  if (me == null) return;
  final messenger = ScaffoldMessenger.of(context);
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text("Signaler ce contenu", style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          for (final r in reasons)
            ListTile(
              title: Text(r),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  await ChatService.reportContent(
                    kind: 'help',
                    reporterUid: me,
                    reason: r,
                    text: text,
                    targetUid: targetUid,
                    targetPseudo: targetPseudo,
                    postId: postId,
                    replyId: replyId,
                  );
                  messenger.showSnackBar(
                    const SnackBar(content: Text("Merci, signalé à l'administrateur.")),
                  );
                } catch (_) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text("Signalement impossible pour le moment.")),
                  );
                }
              },
            ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
//  Poser une question (texte + image facultative)
// ---------------------------------------------------------------------------
class HelpComposePage extends StatefulWidget {
  final String uid;
  final String pseudo;
  const HelpComposePage({super.key, required this.uid, required this.pseudo});

  @override
  State<HelpComposePage> createState() => _HelpComposePageState();
}

class _HelpComposePageState extends State<HelpComposePage> {
  final _text = TextEditingController();
  Uint8List? _image;
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _pick() async {
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        maxHeight: 2000,
      );
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (mounted) setState(() => _image = bytes);
    } catch (e) {
      _snack("Sélection impossible : $e");
    }
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty) return _snack("Décrivez votre problème.");
    if (_sending) return;
    setState(() => _sending = true);
    try {
      String url = '';
      if (_image != null) url = await SupabaseStorage.uploadChatImage(_image!);
      await ChatService.postHelp(
        uid: widget.uid,
        pseudo: widget.pseudo,
        text: text,
        imageUrl: url,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack(_helpError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text("Demander de l'aide")),
      body: AbsorbPointer(
        absorbing: _sending,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _text,
              maxLines: 6,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: "Décrivez votre problème",
                alignLabelWithHint: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 12),
            if (_image != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.memory(_image!, height: 220, fit: BoxFit.cover),
                ),
              ),
            OutlinedButton.icon(
              onPressed: _pick,
              icon: const Icon(Icons.add_photo_alternate_rounded),
              label: Text(_image == null ? "Ajouter une image / capture" : "Changer l'image"),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_sending ? "Envoi…" : "Publier ma demande"),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Votre demande est visible par tous les utilisateurs connectés. Ne partagez pas d'informations personnelles.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Une demande et ses réponses
// ---------------------------------------------------------------------------
class HelpPostPage extends StatefulWidget {
  final String postId;
  final String uid;
  final String pseudo;
  const HelpPostPage({super.key, required this.postId, required this.uid, required this.pseudo});

  @override
  State<HelpPostPage> createState() => _HelpPostPageState();
}

class _HelpPostPageState extends State<HelpPostPage> {
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _post =
      ChatService.helpPosts.doc(widget.postId).snapshots();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _replies =
      ChatService.helpReplies(widget.postId);

  final _input = TextEditingController();
  Uint8List? _image;
  bool _sending = false;
  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _pick() async {
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        maxHeight: 2000,
      );
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (mounted) setState(() => _image = bytes);
    } catch (e) {
      _snack("Sélection impossible : $e");
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    if (DateTime.now().difference(_lastSent) < const Duration(seconds: 2)) {
      _snack("Doucement : patientez quelques secondes entre deux messages.");
      return;
    }
    setState(() => _sending = true);
    try {
      String url = '';
      if (_image != null) url = await SupabaseStorage.uploadChatImage(_image!);
      await ChatService.replyHelp(
        postId: widget.postId,
        uid: widget.uid,
        pseudo: widget.pseudo,
        text: text,
        imageUrl: url,
      );
      _lastSent = DateTime.now();
      _input.clear();
      if (mounted) setState(() => _image = null);
    } catch (e) {
      _snack(_helpError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppColors.accent(context);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _post,
      builder: (context, ps) {
        final d = ps.data?.data();
        final mine = d != null && d['uid'] == widget.uid;
        final solved = d != null && '${d['status'] ?? 'open'}' == 'solved';

        return Scaffold(
          appBar: AppBar(
            title: const Text("Entraide"),
            actions: [
              if (mine)
                TextButton.icon(
                  onPressed: () => ChatService.setSolved(widget.postId, !solved)
                      .catchError((_) => _snack("Action impossible.")),
                  icon: Icon(solved ? Icons.undo_rounded : Icons.check_circle_rounded),
                  label: Text(solved ? "Rouvrir" : "Résolu"),
                ),
            ],
          ),
          body: d == null
              ? (ps.hasData
                  ? const ChatNotice(
                      icon: Icons.delete_outline_rounded,
                      title: "Demande supprimée",
                      message: "Cette demande n'existe plus.",
                    )
                  : const Center(child: CircularProgressIndicator()))
              : Column(
                  children: [
                    Expanded(
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _replies,
                        builder: (context, rs) {
                          final replies = rs.data?.docs ?? const <ChatDoc>[];
                          final image = '${d['imageUrl'] ?? ''}';
                          return ListView(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: theme.cardColor,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: accent.withValues(alpha: 0.4)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${d['pseudo'] ?? ''}',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w800, color: accent),
                                          ),
                                        ),
                                        if (solved)
                                          const Icon(Icons.check_circle_rounded,
                                              color: Color(0xFF2E9E5B)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text('${d['text'] ?? ''}', style: const TextStyle(fontSize: 15.5)),
                                    if (image.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      ChatImage(url: image, maxHeight: 320),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                replies.isEmpty
                                    ? "Aucune réponse pour le moment."
                                    : "${replies.length} réponse(s)",
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: theme.textTheme.bodyMedium?.color,
                                ),
                              ),
                              const SizedBox(height: 6),
                              for (final r in replies)
                                Builder(builder: (context) {
                                  final rd = r.data();
                                  final img = '${rd['imageUrl'] ?? ''}';
                                  return ChatBubble(
                                    mine: rd['uid'] == widget.uid,
                                    pseudo: '${rd['pseudo'] ?? ''}',
                                    text: '${rd['text'] ?? ''}',
                                    time: _timeOf(r),
                                    type: img.isEmpty ? 'text' : 'image',
                                    fileUrl: img,
                                    onLongPress: rd['uid'] == widget.uid
                                        ? null
                                        : () => _reportSheet(
                                              context,
                                              postId: widget.postId,
                                              replyId: r.id,
                                              text: '${rd['text'] ?? ''}',
                                              targetUid: '${rd['uid'] ?? ''}',
                                              targetPseudo: '${rd['pseudo'] ?? ''}',
                                            ),
                                  );
                                }),
                            ],
                          );
                        },
                      ),
                    ),
                    if (_image != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(_image!, width: 52, height: 52, fit: BoxFit.cover),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(child: Text("Image jointe")),
                            IconButton(
                              onPressed: () => setState(() => _image = null),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(6, 6, 10, 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            IconButton(
                              onPressed: _sending ? null : _pick,
                              icon: const Icon(Icons.add_photo_alternate_rounded),
                              tooltip: "Joindre une image",
                            ),
                            Expanded(
                              child: TextField(
                                controller: _input,
                                minLines: 1,
                                maxLines: 4,
                                maxLength: 1000,
                                textCapitalization: TextCapitalization.sentences,
                                decoration: InputDecoration(
                                  hintText: "Votre réponse…",
                                  counterText: '',
                                  filled: true,
                                  fillColor: theme.cardColor,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 48,
                              height: 48,
                              child: FilledButton(
                                onPressed: _sending ? null : _send,
                                style: FilledButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  shape: const CircleBorder(),
                                ),
                                child: _sending
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2.2, color: Colors.white),
                                      )
                                    : const Icon(Icons.send_rounded),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
