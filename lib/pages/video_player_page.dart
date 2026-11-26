import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:item_rdc/core/app_theme.dart';
import 'package:item_rdc/core/media_utils.dart';
import 'package:item_rdc/core/update_service.dart';
import 'package:item_rdc/pages/document_viewer_page.dart' show kLockdownScript, allowMainFrameNavigation;
import 'package:item_rdc/widgets/app_drawer.dart' show openExternalLink;
import 'package:item_rdc/widgets/ui.dart';
import 'package:item_rdc/widgets/windows_web_pane.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

/// Domaines YouTube autorisés dans le lecteur de secours (page de lecture).
bool _ytHost(String url) {
  final h = Uri.tryParse(url)?.host.toLowerCase() ?? '';
  return h.endsWith('youtube.com') ||
      h.endsWith('youtube-nocookie.com') ||
      h.endsWith('youtu.be') ||
      h.endsWith('ytimg.com') ||
      h.endsWith('googlevideo.com');
}

enum _Mode { loading, youtube, web, native, external, winweb, error }

/// Lecture IMMÉDIATE en streaming (aucun téléchargement préalable) :
/// - YouTube : lecteur YouTube,
/// - Google Drive : page `/preview` (lecture dès les premières secondes),
/// - fichier direct (mp4...) : ExoPlayer en streaming, repli sur le
///   lecteur web si le format n'est pas supporté.
class VideoPlayerPage extends StatefulWidget {
  final String url;
  final String title;
  const VideoPlayerPage({super.key, required this.url, required this.title});

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  _Mode _mode = _Mode.loading;

  VideoPlayerController? _video;
  ChewieController? _chewie;
  YoutubePlayerController? _youtube;
  WebViewController? _web;

  bool get _isWin =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
  String? _winUrl;
  String? _winHtml;

  int _webProgress = 0;
  bool _fullscreen = false;

  @override
  void initState() {
    super.initState();
    NativeUpdater.setSecure(true); // pas de capture / enregistrement d'écran
    _start();
  }


  String? _ytId;
  bool _ytFallback = false;

  /// Erreurs 150 / 101 / 152 / 153… : le propriétaire interdit (ou YouTube
  /// refuse) la lecture « intégrée ». On bascule alors, sans rien télécharger,
  /// sur la page de lecture YouTube affichée dans l'application.
  void _onYoutubeChange() {
    final code = _youtube?.value.errorCode ?? 0;
    if (code == 0 || _ytFallback || !mounted) return;
    _ytFallback = true;
    _youtube?.removeListener(_onYoutubeChange);
    final id = _ytId;
    if (id == null) {
      setState(() => _mode = _Mode.error);
      return;
    }
    _startWeb('https://m.youtube.com/watch?v=$id', youtube: true);
  }

  void _start() {
    final url = MediaUtils.clean(widget.url);

    // Windows : tout passe par WebView2 (YouTube, Drive, fichiers vidéo).
    if (_isWin) {
      final id = MediaUtils.isYoutube(url) ? YoutubePlayer.convertUrlToId(url) : null;
      final driveId = MediaUtils.driveId(url);
      if (id != null) {
        _winUrl = 'https://www.youtube.com/embed/$id?autoplay=1&rel=0&modestbranding=1';
      } else if (driveId != null) {
        _winUrl = MediaUtils.drivePreviewUrl(driveId);
      } else if (MediaUtils.looksLikeVideoFile(url)) {
        final safe = url.replaceAll('"', '%22');
        _winHtml =
            '<html><body style="margin:0;background:#000;overflow:hidden">'
            '<video src="$safe" autoplay controls controlsList="nodownload noplaybackrate" '
            'disablePictureInPicture oncontextmenu="return false" '
            'style="width:100vw;height:100vh;background:#000"></video></body></html>';
      } else {
        _winUrl = url;
      }
      _mode = _Mode.winweb;
      return;
    }

    if (kIsWeb && (MediaUtils.isYoutube(url) || MediaUtils.isDrive(url))) {
      _mode = _Mode.external;
      return;
    }

    if (MediaUtils.isYoutube(url)) {
      final id = YoutubePlayer.convertUrlToId(url);
      if (id != null) {
        _ytId = id;
        _youtube = YoutubePlayerController(
          initialVideoId: id,
          flags: const YoutubePlayerFlags(autoPlay: true, mute: false),
        )..addListener(_onYoutubeChange);
        _mode = _Mode.youtube;
        return;
      }
    }

    final driveId = MediaUtils.driveId(url);
    if (driveId != null) {
      _startWeb(MediaUtils.drivePreviewUrl(driveId));
      return;
    }

    _startNative(url);
  }

  Future<void> _startNative(String url) async {
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      _video = controller;
      await controller.initialize();
      if (!mounted) return;
      _chewie = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: false,
        allowedScreenSleep: false,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.brandSoft,
          handleColor: AppColors.brandSoft,
          bufferedColor: Colors.white38,
          backgroundColor: Colors.white24,
        ),
      );
      setState(() => _mode = _Mode.native);
    } catch (_) {
      // Format non supporté par le lecteur natif : lecteur web en secours.
      _video?.dispose();
      _video = null;
      if (mounted) {
        if (kIsWeb) {
          setState(() => _mode = _Mode.external);
        } else {
          _startWeb(url);
        }
      }
    }
  }

  void _startWeb(String url, {bool youtube = false}) {
    final originHost = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..enableZoom(true)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _webProgress = p);
            if (p >= 30) _web?.runJavaScript(kLockdownScript);
          },
          onPageFinished: (_) => _web?.runJavaScript(kLockdownScript),
          onWebResourceError: (e) {
            if (e.isForMainFrame != false && mounted) {
              setState(() => _mode = _Mode.error);
            }
          },
          onNavigationRequest: (r) {
            if (!r.isMainFrame) return NavigationDecision.navigate;
            if (r.url == url) return NavigationDecision.navigate;
            if (youtube && _ytHost(r.url)) return NavigationDecision.navigate;
            // Jamais de téléchargement ni de sortie de l'application.
            return allowMainFrameNavigation(r.url, originHost: originHost)
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(Uri.parse(url));
    _web = controller;
    if (mounted) setState(() => _mode = _Mode.web);
  }

  Future<void> _setFullscreen(bool value) async {
    if (_fullscreen == value) return;
    setState(() => _fullscreen = value);
    if (value) {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      await _restoreSystemUi();
    }
  }

  Future<void> _restoreSystemUi() async {
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    NativeUpdater.setSecure(false);
    if (_fullscreen) _restoreSystemUi();
    _chewie?.dispose();
    _video?.dispose();
    _youtube?.removeListener(_onYoutubeChange);
    _youtube?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_fullscreen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _setFullscreen(false);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: _fullscreen
            ? null
            : AppBar(
                title: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                actions: [
                  if (_mode == _Mode.web)
                    IconButton(
                      tooltip: "Plein écran",
                      icon: const Icon(Icons.fullscreen_rounded),
                      onPressed: () => _setFullscreen(true),
                    ),
                ],
              ),
        body: SafeArea(
          top: !_fullscreen,
          bottom: false,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_mode) {
      case _Mode.loading:
        return const Center(
          child: CircularProgressIndicator(color: AppColors.brandSoft),
        );

      case _Mode.youtube:
        return Center(
          child: YoutubePlayer(
            controller: _youtube!,
            progressColors: const ProgressBarColors(
              playedColor: AppColors.brandSoft,
              handleColor: AppColors.brandSoft,
            ),
          ),
        );

      case _Mode.native:
        return Center(child: Chewie(controller: _chewie!));

      case _Mode.web:
        return Stack(
          children: [
            Positioned.fill(child: WebViewWidget(controller: _web!)),
            // Barrière invisible : neutralise « ouvrir / télécharger ».
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
            if (_webProgress < 100)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  minHeight: 3,
                  color: AppColors.brandSoft,
                  backgroundColor: Colors.transparent,
                ),
              ),
            if (_fullscreen)
              Positioned(
                top: 12,
                left: 12,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(Icons.fullscreen_exit_rounded, color: Colors.white),
                    onPressed: () => _setFullscreen(false),
                  ),
                ),
              ),
          ],
        );

      case _Mode.winweb:
        return WindowsWebPane(
          url: _winHtml == null ? _winUrl : null,
          html: _winHtml,
          lockdownScript: _winHtml == null ? kLockdownScript : null,
          allowNavigation: (u) {
            final l = u.toLowerCase();
            if (l.startsWith('about:') || l.startsWith('data:') || l.startsWith('blob:')) return true;
            if (_winUrl != null && u == _winUrl) return true;
            // Jamais la page « watch » de YouTube, ni téléchargement.
            if (l.contains('youtube.com/watch') || l.contains('youtu.be/')) return false;
            return allowMainFrameNavigation(u, originHost: Uri.tryParse(_winUrl ?? '')?.host);
          },
          background: Colors.black,
        );

      case _Mode.external:
        return EmptyState(
          icon: Icons.open_in_new_rounded,
          title: "Ouvrir la vidéo",
          message: "Le lecteur intégré n'est pas disponible dans le navigateur.",
          action: FilledButton.icon(
            onPressed: () => openExternalLink(
              context,
              MediaUtils.driveId(widget.url) != null
                  ? MediaUtils.drivePreviewUrl(MediaUtils.driveId(widget.url)!)
                  : MediaUtils.clean(widget.url),
            ),
            icon: const Icon(Icons.open_in_browser_rounded),
            label: const Text("Ouvrir dans un nouvel onglet"),
          ),
        );

      case _Mode.error:
        return EmptyState(
          icon: Icons.cloud_off_rounded,
          title: "Impossible de lire la vidéo",
          message: "Vérifiez votre connexion ou le lien de la vidéo.",
          action: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
            onPressed: () {
              setState(() => _mode = _Mode.loading);
              _start();
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text("Réessayer"),
          ),
        );
    }
  }
}
