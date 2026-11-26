import 'dart:async';

import 'package:flutter/material.dart';
import 'package:item_rdc/core/catalog_store.dart';
import 'package:item_rdc/core/update_service.dart';
import 'package:item_rdc/core/user_session.dart';
import 'package:item_rdc/pages/auth_page.dart';
import 'package:item_rdc/pages/home_shell.dart';
import 'package:item_rdc/pages/splash_page.dart';
import 'package:item_rdc/pages/update_page.dart';
import 'package:provider/provider.dart';

/// Racine : écran de démarrage (drapeau Lottie) pendant la vérification de
/// mise à jour, puis soit la mise à jour obligatoire, soit l'application.
/// Clé du Navigator : permet d'afficher la mise à jour par-dessus n'importe
/// quel écran, à tout moment.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> with WidgetsBindingObserver {
  /// Fréquence de vérification du Pastebin pendant que l'application est ouverte.
  static const Duration _pollEvery = Duration(seconds: 10);

  bool _ready = false;
  bool _polling = false;
  bool _updateVisible = false;
  bool _closedByServer = false;
  Route<void>? _updateRoute;
  String? _shownKey;
  // Mises à jour facultatives refusées (« Plus tard »), identifiées par leur
  // CONTENU complet : toute modification du Pastebin les fait réapparaître.
  final Set<String> _dismissed = {};

  static String _contentKey(UpdateInfo i) =>
      '${i.versionCode}|${i.versionName}|${i.apkUrl}|${i.apkUrlAndroid7}|${i.apkUrlAndroid8Plus}|${i.message}';

  static String _stateKey(UpdateInfo i, bool mandatory) => '${_contentKey(i)}|$mandatory';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _boot();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Retour au premier plan : vérification immédiate.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _ready) _poll();
  }

  Future<void> _boot() async {
    // Durée minimale d'affichage du drapeau (la vérification se fait en parallèle).
    final minSplash = Future<void>.delayed(const Duration(milliseconds: 1800));
    final first = _check();
    // La vérification ne retient plus le démarrage au-delà de 1,2 s :
    // si elle est lente, la mise à jour s'affichera dès qu'elle aura répondu.
    // Pendant ce temps, les documents, vidéos et icônes de l'utilisateur se
    // préparent : une fois le drapeau terminé, tout s'affiche instantanément
    // (3,2 s au maximum, pour ne jamais bloquer un réseau lent).
    final warm = CatalogStore.instance.whenReady();
    await Future.wait([
      minSplash,
      first.timeout(const Duration(milliseconds: 1200), onTimeout: () => null),
      warm,
    ]);
    if (!mounted) return;
    setState(() => _ready = true);

    // Surveillance continue du Pastebin : démarrée tout de suite (même si la
    // première vérification est lente).
    _timer = Timer.periodic(_pollEvery, (_) => _poll());

    // Résultat de la première vérification.
    final info = await first;
    if (info != null) _present(info.$1, info.$2);
  }

  /// (info, obligatoire) ou null s'il n'y a pas de mise à jour.
  Future<(UpdateInfo, bool)?> _check() async {
    try {
      final info = await UpdateService.check();
      if (info == null) return null;
      final installed = await NativeUpdater.appInfo();
      return (info, info.isMandatory(installed.versionCode));
    } catch (_) {
      return null;
    }
  }

  Future<void> _poll() async {
    if (_polling || !mounted) return;
    _polling = true;
    try {
      final r = await _check();
      if (!mounted) return;

      if (_updateVisible) {
        // La page de mise à jour est affichée : on la fait suivre le Pastebin.
        if (r == null) {
          // Plus de mise à jour dans le Pastebin (et lecture fiable) => on ferme.
          if (UpdateService.lastOk) _dismissFromServer();
        } else {
          final key = _stateKey(r.$1, r.$2);
          if (key != _shownKey) {
            // Le contenu du Pastebin a changé : on remplace la page.
            _dismissFromServer();
            _present(r.$1, r.$2);
          }
        }
      } else if (r != null) {
        _present(r.$1, r.$2);
      }
    } finally {
      _polling = false;
    }
  }

  /// Ferme la page de mise à jour parce que le Pastebin l'a décidé.
  void _dismissFromServer() {
    final route = _updateRoute;
    if (route == null) return;
    _closedByServer = true;
    _updateRoute = null;
    _updateVisible = false;
    _shownKey = null;
    final nav = appNavigatorKey.currentState;
    if (nav != null && route.isActive) nav.removeRoute(route);
  }

  /// Affiche la page de mise à jour par-dessus l'écran actuel.
  void _present(UpdateInfo info, bool mandatory) {
    if (_updateVisible) return;
    if (!mandatory && _dismissed.contains(_contentKey(info))) return;
    final nav = appNavigatorKey.currentState;
    if (nav == null) return;

    final route = MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => UpdatePage(info: info, mandatory: mandatory),
    );
    _updateRoute = route;
    _updateVisible = true;
    _closedByServer = false;
    _shownKey = _stateKey(info, mandatory);

    nav.push(route).whenComplete(() {
      // Fermée par l'utilisateur (et non par le Pastebin) : on s'en souvient.
      if (!_closedByServer && identical(_updateRoute, route)) {
        _updateVisible = false;
        _updateRoute = null;
        _shownKey = null;
        if (!mandatory) _dismissed.add(_contentKey(info));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: _ready
          ? const AuthGate(key: ValueKey('gate'))
          : const SplashPage(key: ValueKey('splash')),
    );
  }
}

/// Affiche l'écran principal si connecté, sinon l'écran d'authentification.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final signedIn = context.select<UserSession, bool>((s) => s.isSignedIn);

    // Bascule immédiate (sans fondu) : une seule page à dessiner, donc fluide.
    return signedIn
        ? const HomeShell(key: ValueKey('home'))
        : const AuthenticationPage(key: ValueKey('auth'));
  }
}
