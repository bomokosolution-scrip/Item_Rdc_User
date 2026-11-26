import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:item_rdc/core/catalog.dart';
import 'package:item_rdc/core/icon_cache.dart';
import 'package:item_rdc/core/user_session.dart';

typedef CatalogSnapshot = QuerySnapshot<Map<String, dynamic>>;

/// Flux Firestore partagé et mis en mémoire.
///
/// Dès que le profil est connu (démarrage de l'application ou connexion), les
/// collections de l'utilisateur sont écoutées et leurs icônes préparées, PENDANT
/// l'écran de démarrage (Lottie). Les onglets reçoivent alors immédiatement la
/// dernière version connue : plus d'écran de chargement ni d'icônes qui
/// apparaissent après coup.
class _Feed {
  final String collection;
  final bool treatAllAsFolders;
  final bool withIcons;

  CatalogSnapshot? last;
  Object? error;
  final Completer<void> firstEvent = Completer<void>();
  final StreamController<CatalogSnapshot> _out =
      StreamController<CatalogSnapshot>.broadcast();
  StreamSubscription<CatalogSnapshot>? _sub;

  _Feed(this.collection, {this.treatAllAsFolders = false, this.withIcons = true}) {
    _sub = FirebaseFirestore.instance.collection(collection).snapshots().listen(
      (snap) {
        last = snap;
        error = null;
        if (withIcons) IconCache.prefetch(iconUrls(snap));
        if (!firstEvent.isCompleted) firstEvent.complete();
        _out.add(snap);
      },
      onError: (Object e) {
        error = e;
        if (!firstEvent.isCompleted) firstEvent.complete();
        _out.addError(e);
      },
    );
  }

  List<String> iconUrls(CatalogSnapshot snap) => Catalog.fromSnapshot(
    snap,
    treatAllAsFolders: treatAllAsFolders,
  ).iconUrls;

  /// Dernière version connue, puis les mises à jour.
  Stream<CatalogSnapshot> get stream => Stream<CatalogSnapshot>.multi((ctrl) {
    final l = last;
    final e = error;
    if (l != null) {
      ctrl.add(l);
    } else if (e != null) {
      ctrl.addError(e);
    }
    final sub = _out.stream.listen(ctrl.add, onError: ctrl.addError);
    ctrl.onCancel = sub.cancel;
  });

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _out.close();
  }
}

class CatalogStore {
  CatalogStore._();
  static final CatalogStore instance = CatalogStore._();

  final Map<String, _Feed> _feeds = {};
  UserSession? _session;
  String _wantedKey = '';

  /// Branche le préchargement sur la session : démarre à l'ouverture de
  /// l'application (utilisateur déjà connecté) et à chaque connexion.
  void bind(UserSession session) {
    if (identical(_session, session)) return;
    _session?.removeListener(_onSession);
    _session = session;
    session.addListener(_onSession);
    _onSession();
  }

  static const String _categories = 'categories';

  bool get _signedIn => _session?.isSignedIn ?? false;

  String _homeCol(bool premium) => Catalog.homeCollection(premium);
  String _videoCol(bool premium) => Catalog.videoCollection(premium);

  void _onSession() {
    final s = _session;
    if (s == null) return;
    if (!s.isSignedIn) {
      _clear();
      return;
    }
    // On attend le profil : on saura ainsi tout de suite si le compte est Premium.
    if (!s.docLoaded) return;

    final premium = s.isPremium;
    final key = '${s.uid}|$premium';
    if (key == _wantedKey) return;
    _wantedKey = key;

    final keep = <String>{_homeCol(premium), _videoCol(premium), _categories};
    // Les flux devenus inutiles (changement Premium <-> gratuit) sont arrêtés.
    for (final c in _feeds.keys.toList()) {
      if (!keep.contains(c)) _feeds.remove(c)?.dispose();
    }
    _feed(_homeCol(premium), home: true);
    _feed(_videoCol(premium));
    _feed(_categories, withIcons: false);
  }

  void _clear() {
    _wantedKey = '';
    for (final f in _feeds.values) {
      f.dispose();
    }
    _feeds.clear();
  }

  _Feed _feed(String collection, {bool home = false, bool withIcons = true}) {
    return _feeds[collection] ??= _Feed(
      collection,
      treatAllAsFolders: home,
      withIcons: withIcons,
    );
  }

  /// Flux d'une collection (créé à la demande si le préchargement n'a pas encore eu lieu).
  Stream<CatalogSnapshot> watch(
    String collection, {
    bool home = false,
    bool withIcons = true,
  }) => _feed(collection, home: home, withIcons: withIcons).stream;

  /// Dernière version connue (null tant que rien n'est arrivé).
  CatalogSnapshot? last(String collection) => _feeds[collection]?.last;

  Future<void> _until(bool Function() cond) {
    final s = _session;
    if (s == null || cond()) return Future<void>.value();
    final c = Completer<void>();
    void l() {
      if (cond() && !c.isCompleted) c.complete();
    }

    s.addListener(l);
    return c.future.whenComplete(() => s.removeListener(l));
  }

  /// Attend (au plus [timeout]) que le profil, les documents, les vidéos et
  /// leurs icônes soient prêts. Sert à garder l'écran Lottie le temps
  /// nécessaire pour que tout s'affiche instantanément ensuite.
  Future<void> whenReady({Duration timeout = const Duration(milliseconds: 3200)}) async {
    if (!_signedIn) return;
    try {
      await _prepare().timeout(timeout);
    } catch (_) {}
  }

  Future<void> _prepare() async {
    final s = _session;
    if (s == null) return;
    await _until(() => s.docLoaded || !s.isSignedIn);
    if (!s.isSignedIn) return;
    _onSession();

    final premium = s.isPremium;
    final home = _feed(_homeCol(premium), home: true);
    final video = _feed(_videoCol(premium));
    await Future.wait([home.firstEvent.future, video.firstEvent.future]);

    final urls = <String>[
      if (home.last != null) ...home.iconUrls(home.last!),
      if (video.last != null) ...video.iconUrls(video.last!),
    ];
    await IconCache.prepare(urls, timeout: const Duration(milliseconds: 1500));
  }
}
