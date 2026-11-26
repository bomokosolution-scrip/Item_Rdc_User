import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Cache persistant des petites images (icônes de dossiers, logos).
///
/// - mémoire : affichage instantané pendant toute la session ;
/// - disque : affichage instantané dès l'ouverture suivante de l'application
///   (plus d'attente réseau, plus de clignotement lors du changement d'onglet) ;
/// - les images sont réduites (192 px) : léger et rapide à décoder.
class IconCache {
  IconCache._();

  static final Map<String, Uint8List> _mem = {};
  static final Map<String, Future<Uint8List?>> _pending = {};

  /// Images déjà décodées : affichage SYNCHRONE (aucun délai, aucun clignotement).
  static final Map<String, ui.Image> _images = {};
  static final Map<String, Future<ui.Image?>> _decoding = {};

  /// Adresses définitivement introuvables (après 3 essais) : on ne fait pas
  /// attendre l'écran pour elles.
  static final Set<String> _settled = {};
  static Directory? _dir;

  static Directory get _cacheDir => _dir ??= Directory(
    '${Directory.systemTemp.path}${Platform.pathSeparator}item_rdc_icons',
  );

  static int _fnv(String s, int seed) {
    var h = seed;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }

  static File _fileFor(String url) {
    final name =
        '${_fnv(url, 0x811c9dc5).toRadixString(16)}'
        '${_fnv(url, 0x9747b28c).toRadixString(16)}'
        '${url.length}.png';
    return File('${_cacheDir.path}${Platform.pathSeparator}$name');
  }

  /// Image déjà disponible (mémoire ou disque), sans attente.
  static Uint8List? peek(String url) {
    final m = _mem[url];
    if (m != null) return m;
    try {
      final f = _fileFor(url);
      if (f.existsSync()) {
        final b = f.readAsBytesSync();
        if (b.isNotEmpty) {
          _mem[url] = b;
          return b;
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<Uint8List?> load(String url) {
    final hit = peek(url);
    if (hit != null) return Future.value(hit);
    _settled.remove(url);
    return _pending[url] ??= _download(url).whenComplete(() {
      // Bloc { } obligatoire : renvoyer le Future retiré ferait attendre
      // la tâche sur elle-même (blocage : l'icône n'apparaîtrait qu'au redémarrage).
      _pending.remove(url);
    });
  }

  /// Image décodée, si elle est déjà prête (lecture synchrone).
  static ui.Image? peekImage(String url) => _images[url];

  /// Garantit que l'image est décodée en mémoire (téléchargement si besoin).
  static Future<ui.Image?> ensureImage(String url) {
    final ready = _images[url];
    if (ready != null) return Future.value(ready);
    return _decoding[url] ??= _ensureImage(url).whenComplete(() {
      _decoding.remove(url);
    });
  }

  static Future<ui.Image?> _ensureImage(String url) async {
    final bytes = await load(url);
    if (bytes == null) {
      _settled.add(url);
      return null;
    }
    final known = _images[url];
    if (known != null) return known;
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      _images[url] = frame.image;
      return frame.image;
    } catch (_) {
      _settled.add(url);
      return null;
    }
  }

  /// Vrai quand chaque icône est affichable immédiatement (ou définitivement
  /// introuvable).
  static bool allReady(Iterable<String> urls) => urls.every((u) {
    final url = u.trim();
    return url.isEmpty || _images.containsKey(url) || _settled.contains(url);
  });

  /// Attend que toutes les icônes soient disponibles (ou le délai écoulé).
  static Future<void> prepare(
    Iterable<String> urls, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final list = urls.map((u) => u.trim()).where((u) => u.isNotEmpty).toSet();
    if (allReady(list)) return;
    try {
      await Future.wait(list.map(ensureImage)).timeout(
        timeout,
        onTimeout: () => <ui.Image?>[],
      );
    } catch (_) {}
  }

  /// Prépare à l'avance (appelé dès que le catalogue arrive).
  static void prefetch(Iterable<String> urls) {
    for (final u in urls) {
      final url = u.trim();
      if (url.isEmpty || _images.containsKey(url) || _settled.contains(url)) {
        continue;
      }
      ensureImage(url);
    }
  }

  /// 3 tentatives : un réseau lent ou un serveur capricieux ne doit pas
  /// laisser une icône par défaut jusqu'au prochain démarrage.
  static Future<Uint8List?> _download(String url) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      final b = await _downloadOnce(url);
      if (b != null) return b;
      if (attempt < 2) {
        await Future<void>.delayed(Duration(milliseconds: 600 * (attempt + 1)));
      }
    }
    return null;
  }

  static Future<Uint8List?> _downloadOnce(String url) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.getUrl(Uri.parse(url));
      req.headers.set(
        HttpHeaders.userAgentHeader,
        'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36',
      );
      req.headers.set(HttpHeaders.acceptHeader, 'image/*,*/*;q=0.8');
      final resp = await req.close().timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) return null;
      final raw = await consolidateHttpClientResponseBytes(resp);

      final codec = await ui.instantiateImageCodec(raw, targetWidth: 192);
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      codec.dispose();
      if (data == null) {
        frame.image.dispose();
        return null;
      }
      // L'image décodée est conservée : prête à être peinte sans attente.
      _images[url] ??= frame.image;

      final bytes = data.buffer.asUint8List();
      _mem[url] = bytes;
      try {
        final d = _cacheDir;
        if (!d.existsSync()) d.createSync(recursive: true);
        _fileFor(url).writeAsBytesSync(bytes, flush: true);
      } catch (_) {}
      return bytes;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}

/// Image réseau mise en cache : s'affiche immédiatement si déjà connue.
/// Pendant le chargement on montre [placeholder] (neutre, sans fausse icône) ;
/// [fallback] n'apparaît que si l'image est vraiment introuvable.
class CachedBadgeImage extends StatefulWidget {
  final String url;
  final double size;
  final Widget fallback;
  final Widget? placeholder;

  const CachedBadgeImage({
    super.key,
    required this.url,
    required this.size,
    required this.fallback,
    this.placeholder,
  });

  @override
  State<CachedBadgeImage> createState() => _CachedBadgeImageState();
}

class _CachedBadgeImageState extends State<CachedBadgeImage> {
  ui.Image? _image;
  bool _failed = false;
  int _round = 0;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant CachedBadgeImage old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _round = 0;
      _failed = false;
      _resolve();
    }
  }

  void _resolve() {
    final url = widget.url;
    // Déjà décodée : affichage dès la première image, sans aucune attente.
    _image = IconCache.peekImage(url);
    if (_image != null) return;
    IconCache.ensureImage(url).then((img) async {
      if (!mounted || widget.url != url) return;
      if (img != null) {
        setState(() {
          _image = img;
          _failed = false;
        });
        return;
      }
      // Échec : on réessaie deux fois (3 s puis 8 s) avant d'afficher l'icône par défaut.
      if (_round < 2) {
        final wait = _round == 0 ? 3 : 8;
        _round++;
        await Future<void>.delayed(Duration(seconds: wait));
        if (mounted && widget.url == url) _resolve();
      } else {
        setState(() => _failed = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final img = _image;
    if (img == null) {
      if (_failed || widget.placeholder == null) return widget.fallback;
      return widget.placeholder!;
    }
    return RawImage(
      image: img,
      width: widget.size,
      height: widget.size,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
    );
  }
}

/// Retient très brièvement l'affichage d'une liste le temps que ses icônes
/// soient prêtes : si elles sont déjà en mémoire (préchargement au démarrage),
/// la liste s'affiche immédiatement. Sinon, 1 s au maximum.
class IconsGate extends StatefulWidget {
  final List<String> urls;
  final Widget child;
  final Widget placeholder;
  final Duration timeout;

  const IconsGate({
    super.key,
    required this.urls,
    required this.child,
    required this.placeholder,
    this.timeout = const Duration(milliseconds: 1000),
  });

  @override
  State<IconsGate> createState() => _IconsGateState();
}

class _IconsGateState extends State<IconsGate> {
  bool _released = false;

  @override
  void initState() {
    super.initState();
    if (IconCache.allReady(widget.urls)) {
      _released = true;
    } else {
      IconCache.prepare(widget.urls, timeout: widget.timeout).then((_) {
        if (mounted) setState(() => _released = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) => _released ? widget.child : widget.placeholder;
}
