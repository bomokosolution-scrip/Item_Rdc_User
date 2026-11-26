import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';

/// Panneau web pour Windows (Microsoft WebView2).
///
/// Sert à afficher les PDF (aperçu Google Drive / visionneuse en ligne) et à
/// lire les vidéos dans l'application, comme sur Android.
class WindowsWebPane extends StatefulWidget {
  /// Page à charger (ou [html] pour un contenu HTML local).
  final String? url;
  final String? html;

  /// Script injecté à chaque page (zoom, masquage des boutons de téléchargement…).
  final String? lockdownScript;

  /// Retourne `false` pour refuser une navigation (retour à la page d'origine).
  final bool Function(String url)? allowNavigation;

  final Color background;

  const WindowsWebPane({
    super.key,
    this.url,
    this.html,
    this.lockdownScript,
    this.allowNavigation,
    this.background = Colors.black,
  }) : assert(url != null || html != null);

  @override
  State<WindowsWebPane> createState() => WindowsWebPaneState();
}

class WindowsWebPaneState extends State<WindowsWebPane> {
  final WebviewController _c = WebviewController();
  final List<StreamSubscription<dynamic>> _subs = [];

  bool _ready = false;
  bool _loading = true;
  String? _error;
  double _zoom = 1.0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _c.initialize();

      _subs.add(
        _c.loadingState.listen((s) {
          if (!mounted) return;
          setState(() => _loading = s == LoadingState.loading);
          if (s == LoadingState.navigationCompleted && widget.lockdownScript != null) {
            _c.executeScript(widget.lockdownScript!);
          }
        }),
      );

      _subs.add(
        _c.url.listen((u) {
          final allow = widget.allowNavigation;
          if (allow == null || u.isEmpty) return;
          if (!allow(u)) {
            // Navigation refusée : retour à la page d'origine.
            if (widget.url != null) {
              _c.loadUrl(widget.url!);
            } else {
              _c.goBack();
            }
          }
        }),
      );

      await _c.setBackgroundColor(widget.background);
      await _c.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
      if (widget.lockdownScript != null) {
        await _c.addScriptToExecuteOnDocumentCreated(widget.lockdownScript!);
      }

      if (widget.html != null) {
        await _c.loadStringContent(widget.html!);
      } else {
        await _c.loadUrl(widget.url!);
      }
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> reload() async {
    try {
      await _c.reload();
    } catch (_) {}
  }

  Future<void> zoomBy(double delta) async {
    _zoom = (_zoom + delta).clamp(0.5, 3.0);
    try {
      await _c.setZoomFactor(_zoom);
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 52, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 14),
              const Text(
                "Le composant Microsoft WebView2 est introuvable.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                "Installez « Microsoft Edge WebView2 Runtime » (gratuit, depuis le site de Microsoft), puis relancez l'application.",
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    if (!_ready) return const Center(child: CircularProgressIndicator());

    return Stack(
      children: [
        Positioned.fill(child: Webview(_c)),
        if (_loading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 3),
          ),
      ],
    );
  }
}
