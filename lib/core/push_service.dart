import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:item_rdc/pages/app_root.dart' show appNavigatorKey;

/// Notifications push (Firebase Cloud Messaging, gratuit).
///
/// - app fermée ou en arrière-plan : Android affiche la notification tout seul ;
/// - app ouverte : on affiche un bandeau dans l'application ;
/// - chaque téléphone s'abonne au sujet « all » (envoi à tous) et enregistre
///   son jeton dans `users/{uid}.fcmToken` (envoi à une seule personne).
class PushService {
  PushService._();

  static const String topicAll = 'all';
  static String? _uid;
  static StreamSubscription<String>? _tokenSub;
  static StreamSubscription<RemoteMessage>? _fgSub;

  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// À appeler quand un utilisateur est connecté (ne bloque jamais l'app).
  static Future<void> start(String uid) async {
    if (!_supported || uid.isEmpty || _uid == uid) return;
    _uid = uid;
    // On laisse l'accueil s'afficher d'abord.
    await Future<void>.delayed(const Duration(seconds: 2));
    if (_uid != uid) return;
    try {
      final fm = FirebaseMessaging.instance;
      await fm.requestPermission();
      await fm.subscribeToTopic(topicAll);
      final token = await fm.getToken();
      if (token != null) await _saveToken(uid, token);

      _tokenSub?.cancel();
      _tokenSub = fm.onTokenRefresh.listen((t) => _saveToken(uid, t));
      _fgSub?.cancel();
      _fgSub = FirebaseMessaging.onMessage.listen(_showInApp);
    } catch (e) {
      debugPrint('Push init error: $e');
    }
  }

  /// À appeler AVANT la déconnexion : ce téléphone ne reçoit plus les messages
  /// de l'ancien compte.
  static Future<void> stop(String uid) async {
    if (!_supported) return;
    _uid = null;
    _tokenSub?.cancel();
    _tokenSub = null;
    _fgSub?.cancel();
    _fgSub = null;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'fcmToken': FieldValue.delete()})
          .timeout(const Duration(seconds: 3));
    } catch (_) {}
    FirebaseMessaging.instance.deleteToken().catchError((_) {});
  }

  /// `update` (et non `set`) : ne recrée jamais un compte supprimé par l'admin.
  static Future<void> _saveToken(String uid, String token) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'fcmToken': token,
          'fcmUpdatedAt': FieldValue.serverTimestamp(),
        });
        return;
      } catch (_) {
        // Le profil d'un compte tout neuf peut ne pas encore exister.
        await Future<void>.delayed(const Duration(seconds: 5));
      }
    }
  }

  static void _showInApp(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;
    final ctx = appNavigatorKey.currentContext;
    if (ctx == null) return;
    final messenger = ScaffoldMessenger.maybeOf(ctx);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          behavior: SnackBarBehavior.floating,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((n.title ?? '').isNotEmpty)
                Text(n.title!, style: const TextStyle(fontWeight: FontWeight.w800)),
              if ((n.body ?? '').isNotEmpty) Text(n.body!),
            ],
          ),
          action: SnackBarAction(label: 'OK', onPressed: () {}),
        ),
      );
  }
}
