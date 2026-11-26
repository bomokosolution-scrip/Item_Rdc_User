import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:internet_file/internet_file.dart';
import 'package:item_rdc/core/app_theme.dart';
import 'package:item_rdc/core/media_utils.dart';
import 'package:item_rdc/core/update_service.dart';
import 'package:item_rdc/widgets/app_drawer.dart' show openExternalLink;
import 'package:item_rdc/widgets/ui.dart';
import 'package:item_rdc/widgets/windows_web_pane.dart';
import 'package:pdfx/pdfx.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Script injecté dans la page : zoom au doigt autorisé, et suppression des
/// boutons Télécharger / Imprimer / Ouvrir dans une nouvelle fenêtre.
const String kLockdownScript = r'''
(function () {
  function run() {
    try {
      var m = document.querySelector('meta[name=viewport]');
      if (!m) { m = document.createElement('meta'); m.name = 'viewport'; document.head.appendChild(m); }
      m.setAttribute('content', 'width=device-width, initial-scale=1.0, minimum-scale=0.5, maximum-scale=8.0, user-scalable=yes');
      var st = document.getElementById('rdc_lock');
      if (!st) {
        st = document.createElement('style'); st.id = 'rdc_lock';
        var sel = ['ownload','élécharg','rint','mprimer','pop-out','popout','new window','nouvelle fen','open in','ouvrir dans'];
        var rules = [];
        sel.forEach(function (w) {
          rules.push('[aria-label*="' + w + '" i]');
          rules.push('[data-tooltip*="' + w + '" i]');
          rules.push('[title*="' + w + '" i]');
        });
        st.textContent = '*{-webkit-touch-callout:none !important;}' + rules.join(',') + '{display:none !important;visibility:hidden !important;}';
        document.head.appendChild(st);
        document.addEventListener('contextmenu', function (e) { e.preventDefault(); }, true);
      }
    } catch (e) {}
  }
  if (document.head) { run(); } else { document.addEventListener('DOMContentLoaded', run); }
  if (!window.__rdcTimer) { window.__rdcTimer = setInterval(run, 1500); }
})();
''';

/// Décide si une navigation du cadre principal est autorisée : jamais de
/// téléchargement, de page « view/edit » ni de site extérieur.
bool allowMainFrameNavigation(String url, {String? originHost}) {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  if (uri.scheme == 'about' || uri.scheme == 'data' || uri.scheme == 'blob') return true;
  if (uri.scheme != 'http' && uri.scheme != 'https') return false;

  final lower = url.toLowerCase();
  if (lower.contains('export=download') ||
      lower.contains('/download') ||
      lower.contains('&dl=1') ||
      lower.contains('/uc?')) {
    return false;
  }
  final path = uri.path.toLowerCase();
  if (path.endsWith('/view') || path.endsWith('/edit') || path.endsWith('/open')) {
    return false;
  }
  final host = uri.host.toLowerCase();
  final trusted = host.endsWith('google.com') ||
      host.endsWith('googleusercontent.com') ||
      host.endsWith('gstatic.com') ||
      host.endsWith('googleapis.com') ||
      (originHost != null && originHost.isNotEmpty && host == originHost.toLowerCase());
  return trusted;
}

/// Visionneuse de documents : aperçu IMMÉDIAT, dans l'application uniquement,
/// sans téléchargement ni ouverture externe, avec zoom au doigt.
class DocumentViewerPage extends StatefulWidget {
  final String url;
  final String title;
  const DocumentViewerPage({super.key, required this.url, required this.title});

  @override
  State<DocumentViewerPage> createState() => _DocumentViewerPageState();
}

class _DocumentViewerPageState extends State<DocumentViewerPage> {
  WebViewController? _web;
  final GlobalKey<WindowsWebPaneState> _paneKey = GlobalKey<WindowsWebPaneState>();
  late final String _viewUrl;
  late final String _originHost;

  int _progress = 0;
  bool _error = false;
  bool _native = false;
  PdfControllerPinch? _pdf;

  bool get _isWin =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  @override
  void initState() {
    super.initState();
    NativeUpdater.setSecure(true); // pas de capture d'écran du contenu
    _viewUrl = MediaUtils.documentViewUrl(widget.url);
    _originHost = Uri.tryParse(MediaUtils.clean(widget.url))?.host ?? '';

    // Web (Chrome) : pas de WebView. Windows : WebView2 (WindowsWebPane).
    if (kIsWeb || _isWin) return;

    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..enableZoom(true)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
            if (p >= 30) _web?.runJavaScript(kLockdownScript);
          },
          onPageFinished: (_) {
            _web?.runJavaScript(kLockdownScript);
            if (mounted) setState(() => _progress = 100);
          },
          onWebResourceError: (e) {
            if (e.isForMainFrame != false && mounted) {
              setState(() => _error = true);
            }
          },
          onNavigationRequest: (request) {
            if (!request.isMainFrame) return NavigationDecision.navigate;
            if (request.url == _viewUrl) return NavigationDecision.navigate;
            return allowMainFrameNavigation(request.url, originHost: _originHost)
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(Uri.parse(_viewUrl));
  }

  void _reload() {
    setState(() {
      _error = false;
      _progress = 0;
      _native = false;
    });
    _web?.loadRequest(Uri.parse(_viewUrl));
    _paneKey.currentState?.reload();
  }

  /// Lecteur natif : zoom au doigt fluide. Le fichier est lu en mémoire
  /// uniquement (jamais enregistré sur le téléphone).
  void _openNative() {
    _pdf?.dispose();
    setState(() {
      _native = true;
      _pdf = PdfControllerPinch(
        document: PdfDocument.openData(
          InternetFile.get(MediaUtils.directUrl(widget.url)),
        ),
      );
    });
  }

  @override
  void dispose() {
    NativeUpdater.setSecure(false);
    _pdf?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loading = !kIsWeb && !_isWin && !_native && !_error && _progress < 100;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (_isWin && !_native) ...[
            IconButton(
              tooltip: "Zoom -",
              icon: const Icon(Icons.zoom_out_rounded),
              onPressed: () => _paneKey.currentState?.zoomBy(-0.25),
            ),
            IconButton(
              tooltip: "Zoom +",
              icon: const Icon(Icons.zoom_in_rounded),
              onPressed: () => _paneKey.currentState?.zoomBy(0.25),
            ),
          ],
          if (!kIsWeb)
            IconButton(
              tooltip: _native ? "Mode rapide" : "Zoom (lecteur PDF)",
              icon: Icon(_native ? Icons.bolt_rounded : Icons.zoom_in_rounded),
              onPressed: _native ? _reload : _openNative,
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (v) {
              if (v == 'reload') _reload();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'reload',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.refresh_rounded),
                  title: Text("Recharger"),
                ),
              ),
            ],
          ),
        ],
        bottom: loading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  value: _progress == 0 ? null : _progress / 100,
                  minHeight: 3,
                  color: AppColors.brandSoft,
                  backgroundColor: Colors.transparent,
                ),
              )
            : null,
      ),
      body: _native ? _buildNative() : _buildWeb(loading),
    );
  }

  Widget _buildWeb(bool loading) {
    if (kIsWeb) {
      return EmptyState(
        icon: Icons.open_in_new_rounded,
        title: "Ouvrir le document",
        message: "L'aperçu intégré n'est pas disponible dans le navigateur.",
        action: FilledButton.icon(
          onPressed: () => openExternalLink(context, _viewUrl),
          icon: const Icon(Icons.open_in_browser_rounded),
          label: const Text("Ouvrir dans un nouvel onglet"),
        ),
      );
    }
    if (_isWin) {
      return WindowsWebPane(
        key: _paneKey,
        url: _viewUrl,
        lockdownScript: kLockdownScript,
        allowNavigation: (u) =>
            u == _viewUrl || allowMainFrameNavigation(u, originHost: _originHost),
        background: Theme.of(context).scaffoldBackgroundColor,
      );
    }
    if (_error) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: "Impossible d'afficher le document",
        message: "Vérifiez votre connexion internet puis réessayez.",
        action: FilledButton.icon(
          onPressed: _reload,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text("Réessayer"),
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(child: WebViewWidget(controller: _web!)),
        // Barrière invisible sur le coin supérieur droit : neutralise les
        // boutons « ouvrir / télécharger » de la visionneuse.
        Positioned(
          top: 0,
          right: 0,
          width: 84,
          height: 64,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: const SizedBox.expand(),
          ),
        ),
        if (loading)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _progress < 100 ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const IconBadge(icon: Icons.description_rounded, size: 72),
                      const SizedBox(height: 16),
                      Text(
                        "Ouverture du document…",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNative() {
    return PdfViewPinch(
      controller: _pdf!,
      builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
        options: const DefaultBuilderOptions(),
        documentLoaderBuilder: (_) =>
            const Center(child: CircularProgressIndicator()),
        pageLoaderBuilder: (_) =>
            const Center(child: CircularProgressIndicator()),
        errorBuilder: (_, error) => EmptyState(
          icon: Icons.error_outline_rounded,
          title: "Lecture impossible",
          message: "Ce fichier ne peut pas être affiché avec le lecteur PDF.\nUtilisez le « Mode rapide ».",
          action: FilledButton.icon(
            onPressed: _reload,
            icon: const Icon(Icons.bolt_rounded),
            label: const Text("Mode rapide"),
          ),
        ),
      ),
    );
  }
}
