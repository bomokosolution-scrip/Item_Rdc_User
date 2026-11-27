import 'package:cloud_firestore/cloud_firestore.dart';

typedef ChatDoc = QueryDocumentSnapshot<Map<String, dynamic>>;

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

  static Future<void> report({
    required ChatDoc message,
    required String reporterUid,
    required String reason,
  }) {
    final d = message.data();
    return _db.collection('chat_reports').add({
      'messageId': message.id,
      'messageText': '${d['text'] ?? ''}',
      'messageUid': '${d['uid'] ?? ''}',
      'messagePseudo': '${d['pseudo'] ?? ''}',
      'reason': reason,
      'reporterUid': reporterUid,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
