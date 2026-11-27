import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:item_rdc/core/app_theme.dart';
import 'package:item_rdc/core/chat_service.dart';

/// Onglet « Discussion » : groupe général, ouvert à tous les comptes connectés.
class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const _Notice(
        icon: Icons.lock_rounded,
        title: "Connexion requise",
        message: "Connectez-vous pour participer à la discussion.",
      );
    }
    return StreamBuilder<bool>(
      stream: ChatService.generalEnabled(),
      builder: (context, enabled) {
        if (!enabled.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (enabled.data != true) {
          return const _Notice(
            icon: Icons.forum_outlined,
            title: "Discussion fermée",
            message: "L'administrateur ouvrira bientôt la discussion générale.",
          );
        }
        return StreamBuilder<String?>(
          stream: ChatService.pseudoStream(uid),
          builder: (context, pseudo) {
            if (pseudo.connectionState == ConnectionState.waiting && !pseudo.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final p = pseudo.data;
            if (p == null || p.isEmpty) return _PseudoSetup(uid: uid);
            return _ChatRoom(uid: uid, pseudo: p);
          },
        );
      },
    );
  }
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const _Notice({required this.icon, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.accent(context)),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Choix du pseudo + règles de la discussion
// ---------------------------------------------------------------------------
class _PseudoSetup extends StatefulWidget {
  final String uid;
  const _PseudoSetup({required this.uid});

  @override
  State<_PseudoSetup> createState() => _PseudoSetupState();
}

class _PseudoSetupState extends State<_PseudoSetup> {
  final _controller = TextEditingController();
  bool _accepted = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _validate() async {
    if (_busy) return;
    if (!_accepted) {
      setState(() => _error = "Acceptez les règles pour continuer.");
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await ChatService.claimPseudo(widget.uid, _controller.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppColors.accent(context);
    const rules = [
      "Restez respectueux : pas d'insultes, de harcèlement ni de propos haineux.",
      "Pas de publicité, de spam ni de liens douteux.",
      "Ne partagez pas d'informations personnelles (téléphone, mot de passe…).",
      "Vos messages sont visibles par tous les utilisateurs connectés.",
      "L'administrateur peut supprimer un message ou suspendre un compte.",
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
      children: [
        Icon(Icons.forum_rounded, size: 52, color: accent),
        const SizedBox(height: 12),
        const Text(
          "Rejoindre la discussion",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          "Choisissez un pseudo : c'est le nom que les autres verront. Il ne pourra pas être modifié.",
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.textTheme.bodyMedium?.color),
        ),
        const SizedBox(height: 22),
        TextField(
          controller: _controller,
          maxLength: 20,
          autocorrect: false,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_.-]'))],
          decoration: InputDecoration(
            labelText: "Pseudo",
            helperText: "3 à 20 caractères : lettres, chiffres, _ . -",
            prefixIcon: const Icon(Icons.alternate_email_rounded),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Règles", style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              for (final r in rules)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle_outline_rounded, size: 16, color: accent),
                      const SizedBox(width: 8),
                      Expanded(child: Text(r, style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                ),
            ],
          ),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _accepted,
          onChanged: (v) => setState(() => _accepted = v ?? false),
          title: const Text("J'ai lu et j'accepte les règles"),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        SizedBox(
          height: 50,
          child: FilledButton(
            onPressed: _busy ? null : _validate,
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : const Text("Valider", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
//  Salon
// ---------------------------------------------------------------------------
class _ChatRoom extends StatefulWidget {
  final String uid;
  final String pseudo;
  const _ChatRoom({required this.uid, required this.pseudo});

  @override
  State<_ChatRoom> createState() => _ChatRoomState();
}

class _ChatRoomState extends State<_ChatRoom> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _latest = ChatService.latest();
  late final Stream<Map<String, dynamic>?> _ban = ChatService.banStream(widget.uid);

  /// Messages plus anciens chargés à la demande.
  final List<ChatDoc> _older = [];
  bool _loadingOlder = false;
  bool _noMoreOlder = false;

  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
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
      await ChatService.send(uid: widget.uid, pseudo: widget.pseudo, text: text);
      _lastSent = DateTime.now();
      _input.clear();
    } on FirebaseException catch (e) {
      _snack(e.code == 'permission-denied'
          ? "Envoi refusé : vous êtes peut-être suspendu ou la discussion est fermée."
          : "Échec de l'envoi : ${e.message ?? e.code}");
    } catch (e) {
      _snack("Échec de l'envoi : $e");
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _loadOlder(List<ChatDoc> all) async {
    if (_loadingOlder || all.isEmpty) return;
    setState(() => _loadingOlder = true);
    try {
      final more = await ChatService.older(all.last);
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
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text("Copier le texte"),
              onTap: () {
                Clipboard.setData(ClipboardData(text: '${msg.data()['text'] ?? ''}'));
                Navigator.pop(ctx);
              },
            ),
            if (msg.data()['uid'] != widget.uid)
              ListTile(
                leading: const Icon(Icons.flag_rounded),
                title: const Text("Signaler ce message"),
                onTap: () {
                  Navigator.pop(ctx);
                  _reportDialog(msg);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _reportDialog(ChatDoc msg) {
    const reasons = [
      "Insulte ou harcèlement",
      "Spam ou publicité",
      "Contenu inapproprié",
      "Autre",
    ];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text("Pourquoi signalez-vous ce message ?",
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            for (final r in reasons)
              ListTile(
                title: Text(r),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await ChatService.report(
                      message: msg,
                      reporterUid: widget.uid,
                      reason: r,
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

  static String _hm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  static String _day(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return "Aujourd'hui";
    if (diff == 1) return "Hier";
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Color _nameColor(String name) {
    const palette = [
      Color(0xFF1E88E5), Color(0xFF8E24AA), Color(0xFF00897B), Color(0xFFF4511E),
      Color(0xFF6D4C41), Color(0xFF3949AB), Color(0xFFD81B60), Color(0xFF43A047),
    ];
    final h = name.codeUnits.fold<int>(0, (a, b) => (a * 31 + b) & 0x7fffffff);
    return palette[h % palette.length];
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
    final accent = AppColors.accent(context);

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _latest,
            builder: (context, snap) {
              if (snap.hasError) {
                return const _Notice(
                  icon: Icons.error_outline_rounded,
                  title: "Chargement impossible",
                  message: "Vérifiez votre connexion et réessayez.",
                );
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final live = snap.data!.docs;
              final seen = live.map((d) => d.id).toSet();
              final all = [...live, ..._older.where((d) => !seen.contains(d.id))];

              if (all.isEmpty) {
                return const _Notice(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: "Aucun message",
                  message: "Soyez le premier à écrire dans la discussion !",
                );
              }
              final canLoadMore = !_noMoreOlder && live.length >= ChatService.pageSize;

              return ListView.builder(
                controller: _scroll,
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
                  final msg = all[i];
                  final d = msg.data();
                  final mine = d['uid'] == widget.uid;
                  final when = _time(msg);
                  final olderMsg = i + 1 < all.length ? all[i + 1] : null;
                  final olderWhen = olderMsg == null ? null : _time(olderMsg);
                  final showDay = when != null &&
                      (olderWhen == null ||
                          olderWhen.year != when.year ||
                          olderWhen.month != when.month ||
                          olderWhen.day != when.day);
                  final pseudo = '${d['pseudo'] ?? ''}';

                  return Column(
                    children: [
                      if (showDay)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.dividerColor.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(_day(when),
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: theme.textTheme.bodyMedium?.color)),
                          ),
                        ),
                      Align(
                        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: GestureDetector(
                          onLongPress: () => _messageActions(msg),
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.78,
                            ),
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                            decoration: BoxDecoration(
                              color: mine ? accent : theme.cardColor,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: Radius.circular(mine ? 16 : 4),
                                bottomRight: Radius.circular(mine ? 4 : 16),
                              ),
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 1)),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!mine)
                                  Text(
                                    pseudo,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: _nameColor(pseudo),
                                    ),
                                  ),
                                Text(
                                  '${d['text'] ?? ''}',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: mine ? Colors.white : theme.textTheme.bodyLarge?.color,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    when == null ? '…' : _hm(when),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: mine
                                          ? Colors.white70
                                          : theme.textTheme.bodyMedium?.color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
        StreamBuilder<Map<String, dynamic>?>(
          stream: _ban,
          builder: (context, ban) {
            final b = ban.data;
            if (b != null) {
              final until = b['until'] as DateTime?;
              final reason = '${b['reason'] ?? ''}'.trim();
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                color: theme.colorScheme.error.withValues(alpha: 0.12),
                child: Text(
                  until == null
                      ? "Vous êtes suspendu de la discussion.${reason.isEmpty ? '' : ' Motif : $reason'}"
                      : "Vous êtes suspendu jusqu'au ${until.day.toString().padLeft(2, '0')}/${until.month.toString().padLeft(2, '0')} à ${_hm(until)}.${reason.isEmpty ? '' : ' Motif : $reason'}",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w700),
                ),
              );
            }
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: ChatService.maxLength,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: "Écrire en tant que ${widget.pseudo}…",
                          counterText: '',
                          filled: true,
                          fillColor: theme.cardColor,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
            );
          },
        ),
        // Laisse de la place à la barre de navigation flottante (extendBody).
        const SizedBox(height: 70),
      ],
    );
  }
}
