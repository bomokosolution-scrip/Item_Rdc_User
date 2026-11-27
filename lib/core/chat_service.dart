import 'package:cloud_firestore/cloud_firestore.dart';

typedef ChatDoc = QueryDocumentSnapshot<Map<String, dynamic>>;

class ChatFlags {
  final bool general;
  final bool help;
  final bool dm;
  const ChatFlags({this.general = false, this.help = false, this.dm = false});
  bool get any => general || help || dm;
}

/// Chat de groupe (gratuit : Firestore uniquement).
/// Économie de lectures : on ne charge que les derniers messages, puis les
/// anciens à la demande.
class ChatService {
  ChatService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const int pageSize = 40;
  static const int maxLength = 500;
  static final RegExp pseudoRe = RegExp(r'^[A-Za-z0-9_.-]{3,20}$');

  static DocumentReference<Map<String, dynamic>> get _settings =>
      _db.collection('settings').doc('chat');

  static CollectionReference<Map<String, dynamic>> get messages =>
      _db.collection('chat_rooms').doc('general').collection('messages');

  /// Vrai quand l'administrateur a ouvert le groupe général.
  static Stream<bool> generalEnabled() =>
      _settings.snapshots().map((s) => s.data()?['generalEnabled'] == true);

  /// Interrupteurs de l'administrateur : groupe, entraide, messages privés.
  static Stream<ChatFlags> flags() => _settings.snapshots().map((s) {
    final d = s.data();
    return ChatFlags(
      general: d?['generalEnabled'] == true,
      help: d?['helpEnabled'] == true,
      dm: d?['dmEnabled'] == true,
    );
  });

  /// Pseudo choisi par l'utilisateur (null tant qu'il n'en a pas).
  static Stream<String?> pseudoStream(String uid) => _db
      .collection('chat_profiles')
      .doc(uid)
      .snapshots()
      .map((s) => s.data()?['pseudo'] as String?);

  /// Réserve un pseudo unique. Renvoie un message d'erreur, ou null si réussi.
  static Future<String?> claimPseudo(String uid, String pseudo) async {
    final p = pseudo.trim();
    if (!pseudoRe.hasMatch(p)) {
      return "Pseudo invalide : 3 à 20 caractères (lettres, chiffres, _ . -).";
    }
    final lower = p.toLowerCase();
    try {
      final taken = await _db.collection('chat_pseudos').doc(lower).get();
      if (taken.exists) return "Ce pseudo est déjà pris.";
      final batch = _db.batch();
      batch.set(_db.collection('chat_profiles').doc(uid), {
        'pseudo': p,
        'pseudoLower': lower,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.set(_db.collection('chat_pseudos').doc(lower), {
        'uid': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      return null;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return "Pseudo refusé (déjà pris ou non autorisé).";
      }
      return "Erreur : ${e.message ?? e.code}";
    } catch (e) {
      return "Erreur : $e";
    }
  }

  /// Suspension éventuelle de l'utilisateur : null = non suspendu ;
  /// sinon `{until: DateTime?, reason: String}` (until null = définitive).
  static Stream<Map<String, dynamic>?> banStream(String uid) =>
      _db.collection('chat_bans').doc(uid).snapshots().map((s) {
        final d = s.data();
        if (d == null) return null;
        final until = d['until'];
        if (until is Timestamp && !until.toDate().isAfter(DateTime.now())) {
          return null; // suspension terminée
        }
        return {
          'until': until is Timestamp ? until.toDate() : null,
          'reason': '${d['reason'] ?? ''}',
        };
      });

  static Stream<QuerySnapshot<Map<String, dynamic>>> latest() => messages
      .orderBy('createdAt', descending: true)
      .limit(pageSize)
      .snapshots();

  static Future<List<ChatDoc>> older(ChatDoc last) async {
    final snap = await messages
        .orderBy('createdAt', descending: true)
        .startAfterDocument(last)
        .limit(pageSize)
        .get();
    return snap.docs;
  }

  static Future<void> send({
    required String uid,
    required String pseudo,
    required String text,
  }) {
    return messages.add({
      'uid': uid,
      'pseudo': pseudo,
      'text': text,
      'type': 'text',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Signalement générique (groupe, entraide, message privé).
  static Future<void> reportContent({
    required String kind, // 'chat' | 'help' | 'dm'
    required String reporterUid,
    required String reason,
    required String text,
    required String targetUid,
    required String targetPseudo,
    String messageId = '',
    String postId = '',
    String replyId = '',
  }) {
    return _db.collection('chat_reports').add({
      'kind': kind,
      'messageId': messageId,
      'postId': postId,
      'replyId': replyId,
      'messageText': text.length > 500 ? text.substring(0, 500) : text,
      'messageUid': targetUid,
      'messagePseudo': targetPseudo,
      'reason': reason,
      'reporterUid': reporterUid,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> report({
    required ChatDoc message,
    required String reporterUid,
    required String reason,
  }) {
    final d = message.data();
    return reportContent(
      kind: 'chat',
      reporterUid: reporterUid,
      reason: reason,
      text: '${d['text'] ?? ''}',
      targetUid: '${d['uid'] ?? ''}',
      targetPseudo: '${d['pseudo'] ?? ''}',
      messageId: message.id,
    );
  }

  // ------------------------------------------------------------------
  //  Messages privés
  // ------------------------------------------------------------------
  static String dmId(String a, String b) {
    final l = [a, b]..sort();
    return '${l[0]}_${l[1]}';
  }

  static DocumentReference<Map<String, dynamic>> dmRef(String id) =>
      _db.collection('chat_dms').doc(id);

  /// Mes conversations (tri côté appareil : pas d'index nécessaire).
  static Stream<QuerySnapshot<Map<String, dynamic>>> myDms(String uid) =>
      _db.collection('chat_dms').where('members', arrayContains: uid).snapshots();

  static Stream<QuerySnapshot<Map<String, dynamic>>> dmMessages(String id) => dmRef(id)
      .collection('messages')
      .orderBy('createdAt', descending: true)
      .limit(pageSize)
      .snapshots();

  static Future<List<ChatDoc>> dmOlder(String id, ChatDoc last) async {
    final snap = await dmRef(id)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .startAfterDocument(last)
        .limit(pageSize)
        .get();
    return snap.docs;
  }

  /// Envoie un message privé (crée la conversation au premier message).
  static Future<void> sendDm({
    required String uid,
    required String pseudo,
    required String otherUid,
    required String otherLabel,
    String text = '',
    String type = 'text', // text | file | image
    String fileUrl = '',
    String fileName = '',
  }) async {
    final id = dmId(uid, otherUid);
    final ref = dmRef(id);
    final preview = type == 'image'
        ? '📷 Image'
        : type == 'file'
            ? '📎 ${fileName.isEmpty ? 'Fichier' : fileName}'
            : text;
    final last = preview.length > 120 ? preview.substring(0, 120) : preview;

    final exists = (await ref.get()).exists;
    final batch = _db.batch();
    if (!exists) {
      final members = [uid, otherUid]..sort();
      batch.set(ref, {
        'members': members,
        'names': {uid: pseudo},
        'labels': {otherUid: otherLabel},
        'lastMessage': last,
        'lastAt': FieldValue.serverTimestamp(),
        'lastSender': uid,
        'reads': {uid: FieldValue.serverTimestamp()},
        'blockedBy': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      batch.update(ref, {
        'lastMessage': last,
        'lastAt': FieldValue.serverTimestamp(),
        'lastSender': uid,
        'names.$uid': pseudo,
        'reads.$uid': FieldValue.serverTimestamp(),
      });
    }
    batch.set(ref.collection('messages').doc(), {
      'uid': uid,
      'pseudo': pseudo,
      'text': text,
      'type': type,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  static Future<void> markDmRead(String id, String uid) async {
    try {
      await dmRef(id).update({'reads.$uid': FieldValue.serverTimestamp()});
    } catch (_) {}
  }

  static Future<void> setDmBlocked(String id, String uid, bool blocked) {
    return dmRef(id).update({
      'blockedBy': blocked ? FieldValue.arrayUnion([uid]) : FieldValue.arrayRemove([uid]),
    });
  }

  // ------------------------------------------------------------------
  //  Entraide (publications avec image + réponses)
  // ------------------------------------------------------------------
  static CollectionReference<Map<String, dynamic>> get helpPosts =>
      _db.collection('help_posts');

  static Stream<QuerySnapshot<Map<String, dynamic>>> helpLatest() => helpPosts
      .orderBy('createdAt', descending: true)
      .limit(30)
      .snapshots();

  static Future<void> postHelp({
    required String uid,
    required String pseudo,
    required String text,
    String imageUrl = '',
  }) {
    return helpPosts.add({
      'uid': uid,
      'pseudo': pseudo,
      'text': text,
      'imageUrl': imageUrl,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> helpReplies(String postId) =>
      helpPosts
          .doc(postId)
          .collection('replies')
          .orderBy('createdAt')
          .limit(100)
          .snapshots();

  static Future<void> replyHelp({
    required String postId,
    required String uid,
    required String pseudo,
    required String text,
    String imageUrl = '',
  }) {
    return helpPosts.doc(postId).collection('replies').add({
      'uid': uid,
      'pseudo': pseudo,
      'text': text,
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> setSolved(String postId, bool solved) =>
      helpPosts.doc(postId).update({'status': solved ? 'solved' : 'open'});
}
