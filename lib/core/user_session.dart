import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:item_rdc/core/push_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Source unique de vérité pour l'utilisateur connecté.
///
/// - un seul abonnement Firestore sur le document `users/{uid}` (avant : 3-4),
/// - bascule automatique Premium -> gratuit à la seconde près à l'expiration,
/// - photo de profil locale mémorisée par compte.
class UserSession extends ChangeNotifier with WidgetsBindingObserver {
  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _docSub;
  Timer? _expiryTimer;
  Timer? _heartbeat;

  /// Intervalle d'envoi de « je suis en ligne » (l'admin considère l'utilisateur
  /// hors ligne s'il n'a rien reçu depuis ~2 minutes : appli tuée, plus de réseau…).
  static const Duration _heartbeatEvery = Duration(seconds: 45);

  User? _user;
  Map<String, dynamic>? _data;
  bool _docLoaded = false;
  Uint8List? _localImage;
  bool _docExisted = false; // le document a déjà été vu (détecte la suppression par l'admin)
  bool _photoSynced = false;
  String _remoteSrc = '';
  Uint8List? _remoteBytes;

  UserSession() {
    WidgetsBinding.instance.addObserver(this);
    _bind(FirebaseAuth.instance.currentUser);
    _authSub = FirebaseAuth.instance.authStateChanges().listen((u) {
      if (u?.uid != _user?.uid) _bind(u);
    });
  }

  // ----------------------------------------------------------- Getters

  bool get isSignedIn => _user != null;
  String get uid => _user?.uid ?? '';
  bool get docLoaded => _docLoaded;

  String get firstName => (_data?['firstName'] ?? '').toString();
  String get lastName => (_data?['lastName'] ?? '').toString();
  String get phone => (_data?['phone'] ?? '').toString();
  String get email => (_data?['email'] ?? _user?.email ?? '').toString();
  String get _rawProfileImage => (_data?['profileImage'] ?? '').toString();

  /// URL http(s) éventuelle (anciens comptes / Storage).
  String get profileImageUrl =>
      _rawProfileImage.startsWith('http') ? _rawProfileImage : '';

  /// Photo : copie locale, sinon photo envoyée sur Firestore (base64).
  Uint8List? get localImage => _localImage ?? _remoteImage;

  Uint8List? get _remoteImage {
    final s = _rawProfileImage;
    if (s.isEmpty || s.startsWith('http')) return null;
    if (s != _remoteSrc) {
      _remoteSrc = s;
      try {
        _remoteBytes = base64Decode(s);
      } catch (_) {
        _remoteBytes = null;
      }
    }
    return _remoteBytes;
  }

  String get fullName {
    final n = '$firstName $lastName'.trim();
    if (n.isNotEmpty) return n;
    return _user?.displayName ?? '';
  }

  DateTime? get premiumExpiry {
    // Champ principal écrit par l'application admin : premiumExpiryTime.
    final v = _data?['premiumExpiryTime'] ??
        _data?['premiumExpiry'] ??
        _data?['expiry'];
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  DateTime? get premiumBoughtAt {
    final v = _data?['premiumBoughtTime'];
    return v is Timestamp ? v.toDate() : null;
  }

  bool get isPremium {
    final e = premiumExpiry;
    return e != null && e.isAfter(DateTime.now());
  }

  /// Vrai si le Premium a existé puis expiré.
  bool get wasPremium => premiumExpiry != null && !isPremium;

  // ----------------------------------------------------------- Liaison

  void _bind(User? user) {
    final previousUid = _user?.uid;
    if (previousUid != null && previousUid != user?.uid) {
      _writePresence(previousUid, false);
    }
    _stopHeartbeat();
    _docSub?.cancel();
    _expiryTimer?.cancel();
    _user = user;
    _data = null;
    _docLoaded = false;
    _docExisted = false;
    _photoSynced = false;
    _localImage = null;
    _remoteSrc = '';
    _remoteBytes = null;

    if (user != null) {
      _docSub = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((snap) {
            if (snap.exists) {
              _docExisted = true;
            } else if (_docExisted && !snap.metadata.isFromCache) {
              // Compte supprimé par l'administrateur : on déconnecte.
              _stopHeartbeat();
              FirebaseAuth.instance.signOut();
              return;
            }
            _data = snap.data();
            _docLoaded = true;
            _scheduleExpiryCheck();
            _syncLocalPhotoOnce();
            notifyListeners();
          }, onError: (_) {
            _docLoaded = true;
            notifyListeners();
          });
      _loadLocalImage(user.uid);
      _startHeartbeat();
      PushService.start(user.uid);
      // Hors ligne au premier lancement : on ne bloque pas l'affichage indéfiniment.
      Timer(const Duration(seconds: 5), () {
        if (!_docLoaded && identical(_user, user)) {
          _docLoaded = true;
          notifyListeners();
        }
      });
    }
    notifyListeners();
  }

  // ------------------------------------------------------ Présence

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _writePresence(uid, true);
    _heartbeat = Timer.periodic(_heartbeatEvery, (_) => _writePresence(uid, true));
  }

  void _stopHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = null;
  }

  /// `update` (et non `set`) : ne recrée jamais un compte supprimé par l'admin.
  Future<void> _writePresence(String uid, bool online) async {
    if (uid.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'isOnline': online,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Mise hors ligne explicite (appelée avant la déconnexion).
  Future<void> goOffline() async {
    _stopHeartbeat();
    await _writePresence(uid, false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_user == null) return;
    if (state == AppLifecycleState.resumed) {
      _startHeartbeat();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopHeartbeat();
      _writePresence(uid, false);
    }
  }

  /// Programme une notification au moment exact de l'expiration.
  void _scheduleExpiryCheck() {
    _expiryTimer?.cancel();
    final e = premiumExpiry;
    if (e == null) return;
    final remaining = e.difference(DateTime.now());
    if (remaining.isNegative) return;

    const maxStep = Duration(hours: 12);
    final wait = remaining > maxStep
        ? maxStep
        : remaining + const Duration(milliseconds: 80);
    _expiryTimer = Timer(wait, () {
      _scheduleExpiryCheck();
      notifyListeners();
    });
  }

  // ------------------------------------------------------ Photo locale

  String _imageKey(String uid) => 'profileImage_$uid';

  Future<void> _loadLocalImage(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString(_imageKey(uid));
      if (s != null && uid == _user?.uid) {
        _localImage = base64Decode(s);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setLocalImage(Uint8List bytes) async {
    _localImage = bytes;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_imageKey(uid), base64Encode(bytes));
    } catch (_) {}
    await _uploadPhoto(bytes);
  }

  /// Envoie la photo dans `users/{uid}.profileImage` (base64) pour que
  /// l'application admin puisse l'afficher.
  Future<void> _uploadPhoto(Uint8List bytes) async {
    if (uid.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'profileImage': base64Encode(bytes)});
      _photoSynced = true;
    } catch (_) {}
  }

  /// Anciens comptes : la photo n'existait que sur le téléphone, on l'envoie une fois.
  void _syncLocalPhotoOnce() {
    if (_photoSynced || _localImage == null) return;
    if (_rawProfileImage.isNotEmpty) {
      _photoSynced = true;
      return;
    }
    _photoSynced = true;
    _uploadPhoto(_localImage!);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeat?.cancel();
    _authSub?.cancel();
    _docSub?.cancel();
    _expiryTimer?.cancel();
    super.dispose();
  }
}
