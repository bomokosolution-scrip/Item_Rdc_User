import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:item_rdc/core/app_theme.dart';
import 'package:item_rdc/core/chat_service.dart';
import 'package:item_rdc/core/supabase_storage.dart';
import 'package:item_rdc/pages/chat_page.dart';
import 'package:item_rdc/widgets/chat_bubble.dart';

/// Ouvre (ou crée) la conversation privée avec l'auteur d'un document.
Future<void> openDmWith(
  BuildContext context, {
  required String otherUid,
  required String otherLabel,
  String aboutTitle = '',
}) async {
  final me = FirebaseAuth.instance.currentUser?.uid;
  final messenger = ScaffoldMessenger.of(context);
  if (me == null) {
    messenger.showSnackBar(const SnackBar(content: Text("Connectez-vous pour écrire à l'auteur.")));
    return;
  }
  if (otherUid.isEmpty || otherUid == me) return;
  try {
    final flags = await ChatService.flags().first;
    if (!flags.dm) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Les messages privés sont fermés pour le moment.")),
      );
      return;
    }
  } catch (_) {}
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => DmThreadPage(
        otherUid: otherUid,
        otherLabel: otherLabel,
        initialText: aboutTitle.isEmpty ? '' : "Bonjour, à propos de « $aboutTitle » : ",
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
//  Liste des conversations
// ---------------------------------------------------------------------------
class DmListTab extends StatelessWidget {
  final String uid;
  final AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot;
  const DmListTab({super.key, required this.uid, required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppColors.accent(context);

    if (snapshot.hasError) {
      return const ChatNotice(
        icon: Icons.error_outline_rounded,
        title: "Chargement impossible",
        message: "Vérifiez votre connexion et réessayez.",
      );
    }
    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

    final docs = snapshot.data!.docs.toList()
      ..sort((a, b) {
        final x = a.data()['lastAt'];
        final y = b.data()['lastAt'];
        if (x is Timestamp && y is Timestamp) return y.compareTo(x);
        if (x is Timestamp) return 1;
        if (y is Timestamp) return -1;
        return 0;
      });

    if (docs.isEmpty) {
      return const ChatNotice(
        icon: Icons.mail_outline_rounded,
        title: "Aucune conversation",
        message:
            "Ouvrez un document puis touchez « Contacter l'auteur » pour écrire à son propriétaire.",
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 90),
      itemCount: docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, i) {
        final d = docs[i].data();
        final members = ((d['members'] as List?) ?? const []).map((e) => '$e').toList();
        final other = members.firstWhere((m) => m != uid, orElse: () => '');
        final names = (d['names'] as Map?) ?? const {};
        final labels = (d['labels'] as Map?) ?? const {};
        final name = '${names[other] ?? labels[other] ?? 'Utilisateur'}';
        final last = '${d['lastMessage'] ?? ''}';
        final lastAt = d['lastAt'];
        final reads = (d['reads'] as Map?)?[uid];
        final unread = d['lastSender'] != uid &&
            lastAt is Timestamp &&
            (reads is! Timestamp || reads.compareTo(lastAt) < 0);

        return Material(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          child: ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            leading: CircleAvatar(
              backgroundColor: accent.withValues(alpha: 0.15),
              child: Text(
                name.isEmpty ? '?' : name[0].toUpperCase(),
                style: TextStyle(color: accent, fontWeight: FontWeight.w800),
              ),
            ),
            title: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: unread ? FontWeight.w900 : FontWeight.w700),
            ),
            subtitle: Text(
              last,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: unread ? FontWeight.w700 : FontWeight.w400),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (lastAt is Timestamp)
                  Text(chatHm(lastAt.toDate()),
                      style: TextStyle(fontSize: 11, color: theme.textTheme.bodyMedium?.color)),
                if (unread)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                  ),
              ],
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DmThreadPage(otherUid: other, otherLabel: name),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
//  Conversation
// ---------------------------------------------------------------------------
class DmThreadPage extends StatelessWidget {
  final String otherUid;
  final String otherLabel;
  final String initialText;

  const DmThreadPage({
    super.key,
    required this.otherUid,
    required this.otherLabel,
    this.initialText = '',
  });

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: Text(otherLabel)),
      body: uid == null
          ? const ChatNotice(
              icon: Icons.lock_rounded,
              title: "Connexion requise",
              message: "Connectez-vous pour écrire.",
            )
          : PseudoGate(
              uid: uid,
              builder: (context, pseudo) => _DmBody(
                uid: uid,
                pseudo: pseudo,
                otherUid: otherUid,
                otherLabel: otherLabel,
                initialText: initialText,
              ),
            ),
    );
  }
}

class _DmBody extends StatefulWidget {
  final String uid;
  final String pseudo;
  final String otherUid;
  final String otherLabel;
  final String initialText;
  const _DmBody({
    required this.uid,
    required this.pseudo,
    required this.otherUid,
    required this.otherLabel,
    required this.initialText,
  });

  @override
  State<_DmBody> createState() => _DmBodyState();
}

class _DmBodyState extends State<_DmBody> {
  static const int _maxFileBytes = 10 * 1024 * 1024;

  late final String _id = ChatService.dmId(widget.uid, widget.otherUid);
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _messages = ChatService.dmMessages(_id);
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _meta = ChatService.dmRef(_id).snapshots();
  late final TextEditingController _input = TextEditingController(text: widget.initialText);

  final List<ChatDoc> _older = [];
  bool _loadingOlder = false;
  bool _noMoreOlder = false;
  bool _busy = false;
  String _busyLabel = '';
  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);
  String _lastMarked = '';

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

  String _err(Object e) {
    if (e is FirebaseException && e.code == 'permission-denied') {
      return "Envoi refusé : conversation bloquée, compte suspendu ou messages privés fermés.";
    }
    if (e is FormatException) return e.message;
    return "Échec : $e";
  }

  bool _cooldown() {
    if (DateTime.now().difference(_lastSent) < const Duration(seconds: 2)) {
      _snack("Doucement : patientez quelques secondes entre deux messages.");
      return true;
    }
    return false;
  }

  Future<void> _sendText() async {
    final text = _input.text.trim();
    if (text.isEmpty || _busy || _cooldown()) return;
    setState(() {
      _busy = true;
      _busyLabel = '';
    });
    try {
      await ChatService.sendDm(
        uid: widget.uid,
        pseudo: widget.pseudo,
        otherUid: widget.otherUid,
        otherLabel: widget.otherLabel,
        text: text,
      );
      _lastSent = DateTime.now();
      _input.clear();
    } catch (e) {
      _snack(_err(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _attachImage() async {
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        maxHeight: 2000,
      );
      if (x == null || _cooldown()) return;
      setState(() {
        _busy = true;
        _busyLabel = "Envoi de l'image…";
      });
      final url = await SupabaseStorage.uploadChatImage(await x.readAsBytes());
      await ChatService.sendDm(
        uid: widget.uid,
        pseudo: widget.pseudo,
        otherUid: widget.otherUid,
        otherLabel: widget.otherLabel,
        type: 'image',
        fileUrl: url,
      );
      _lastSent = DateTime.now();
    } catch (e) {
      _snack(_err(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _attachFile() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: SupabaseStorage.allowedExtensions,
      );
      final f = res?.files.single;
      if (f == null || f.path == null || _cooldown()) return;
      if (f.size > _maxFileBytes) {
        _snack("Ce fichier dépasse 10 Mo.");
        return;
      }
      setState(() {
        _busy = true;
        _busyLabel = "Envoi du fichier…";
      });
      final url = await SupabaseStorage.uploadDocument(File(f.path!), folder: 'chat/${widget.uid}');
      await ChatService.sendDm(
        uid: widget.uid,
        pseudo: widget.pseudo,
        otherUid: widget.otherUid,
        otherLabel: widget.otherLabel,
        type: 'file',
        fileUrl: url,
        fileName: f.name,
      );
      _lastSent = DateTime.now();
    } catch (e) {
      _snack(_err(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _attachMenu() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_rounded),
              title: const Text("Image ou capture d'écran"),
              onTap: () {
                Navigator.pop(ctx);
                _attachImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file_rounded),
              title: const Text("Fichier (PDF, Word, Excel, PowerPoint)"),
              subtitle: const Text("10 Mo maximum"),
              onTap: () {
                Navigator.pop(ctx);
                _attachFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadOlder(List<ChatDoc> all) async {
    if (_loadingOlder || all.isEmpty) return;
    setState(() => _loadingOlder = true);
    try {
      final more = await ChatService.dmOlder(_id, all.last);
      if (!mounted) return;
      setState(() {
        _older.addAll(more);
        if (more.length < ChatService.pageSize) _noMoreOlder = true;
      });
    } catch (_) {
      _snack("Impossible de charger les anciens messages.");
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  void _messageActions(ChatDoc msg) {
    final d = msg.data();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if ('${d['text'] ?? ''}'.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text("Copier le texte"),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: '${d['text']}'));
                  Navigator.pop(ctx);
                },
              ),
            if (d['uid'] != widget.uid)
              ListTile(
                leading: const Icon(Icons.flag_rounded),
                title: const Text("Signaler ce message"),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await ChatService.reportContent(
                      kind: 'dm',
                      reporterUid: widget.uid,
                      reason: "Message privé signalé",
                      text: '${d['text'] ?? ''}'.isEmpty
                          ? '[${d['type'] ?? 'fichier'}] ${d['fileUrl'] ?? ''}'
                          : '${d['text']}',
                      targetUid: '${d['uid'] ?? ''}',
                      targetPseudo: '${d['pseudo'] ?? ''}',
                      messageId: msg.id,
                    );
                    _snack("Merci, le message a été signalé à l'administrateur.");
                  } catch (_) {
                    _snack("Signalement impossible pour le moment.");
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  DateTime? _time(ChatDoc d) {
    final t = d.data()['createdAt'];
    if (t is Timestamp) return t.toDate();
    if (d.metadata.hasPendingWrites) return DateTime.now();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Bandeau « bloquée » + menu
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _meta,
          builder: (context, meta) {
            final blocked = ((meta.data?.data()?['blockedBy'] as List?) ?? const []).isNotEmpty;
            final iBlocked = ((meta.data?.data()?['blockedBy'] as List?) ?? const [])
                .contains(widget.uid);
            if (!meta.hasData || !(meta.data?.exists ?? false)) return const SizedBox.shrink();
            return Container(
              width: double.infinity,
              color: blocked
                  ? theme.colorScheme.error.withValues(alpha: 0.1)
                  : Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: Row(
                children: [
                  if (blocked)
                    Expanded(
                      child: Text(
                        iBlocked
                            ? "Vous avez bloqué cette conversation."
                            : "Cette conversation a été bloquée.",
                        style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w700),
                      ),
                    )
                  else
                    const Spacer(),
                  TextButton(
                    onPressed: () => ChatService.setDmBlocked(_id, widget.uid, !iBlocked)
                        .catchError((_) => _snack("Action impossible.")),
                    child: Text(iBlocked ? "Débloquer" : "Bloquer"),
                  ),
                ],
              ),
            );
          },
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _messages,
            builder: (context, snap) {
              if (snap.hasError) {
                return const ChatNotice(
                  icon: Icons.error_outline_rounded,
                  title: "Chargement impossible",
                  message: "Vérifiez votre connexion et réessayez.",
                );
              }
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final live = snap.data!.docs;
              final seen = live.map((d) => d.id).toSet();
              final all = [...live, ..._older.where((d) => !seen.contains(d.id))];

              // Marque comme lu quand le dernier message vient de l'autre.
              if (live.isNotEmpty) {
                final newest = live.first;
                if (newest.data()['uid'] != widget.uid && newest.id != _lastMarked) {
                  _lastMarked = newest.id;
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => ChatService.markDmRead(_id, widget.uid),
                  );
                }
              }

              if (all.isEmpty) {
                return const ChatNotice(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: "Nouvelle conversation",
                  message: "Écrivez votre premier message ci-dessous.",
                );
              }
              final canLoadMore = !_noMoreOlder && live.length >= ChatService.pageSize;
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                itemCount: all.length + (canLoadMore ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i == all.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Center(
                        child: _loadingOlder
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5),
                              )
                            : TextButton.icon(
                                onPressed: () => _loadOlder(all),
                                icon: const Icon(Icons.history_rounded),
                                label: const Text("Messages précédents"),
                              ),
                      ),
                    );
                  }
                  final m = all[i];
                  final d = m.data();
                  return ChatBubble(
                    mine: d['uid'] == widget.uid,
                    pseudo: '${d['pseudo'] ?? ''}',
                    text: '${d['text'] ?? ''}',
                    time: _time(m),
                    type: '${d['type'] ?? 'text'}',
                    fileUrl: '${d['fileUrl'] ?? ''}',
                    fileName: '${d['fileName'] ?? ''}',
                    onLongPress: () => _messageActions(m),
                  );
                },
              );
            },
          ),
        ),
        if (_busy && _busyLabel.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text(_busyLabel),
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
                  onPressed: _busy ? null : _attachMenu,
                  icon: const Icon(Icons.attach_file_rounded),
                  tooltip: "Joindre",
                ),
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 1000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: "Votre message…",
                      counterText: '',
                      filled: true,
                      fillColor: theme.cardColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                    onPressed: _busy ? null : _sendText,
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: const CircleBorder(),
                    ),
                    child: const Icon(Icons.send_rounded),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
