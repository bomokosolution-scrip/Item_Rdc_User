import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Configuration Supabase (mêmes valeurs que l'application admin).
/// Renseignez-les ici OU à la compilation :
///   --dart-define=SUPABASE_URL=...  --dart-define=SUPABASE_ANON_KEY=...
/// Utilisez la clé « publishable » / « anon » — JAMAIS la clé « secret ».
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://eovmshzuovdagxvanpcl.supabase.co',
  );
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_dbO4dWACu1H0Qd0_RJ5EoQ_tJTD0kjI',
  );

  /// Couvertures (images) et ouvrages (PDF).
  static const String imageBucket = 'media';
  static const String pdfBucket = 'publications';

  static bool get isConfigured =>
      !url.contains('VOTRE') && !anonKey.contains('VOTRE');
}

class SupabaseStorage {
  SupabaseStorage._();

  static const int maxPdfBytes = 25 * 1024 * 1024;
  static final Random _rnd = Random();

  static String _name(String ext) =>
      '${DateTime.now().millisecondsSinceEpoch}_${_rnd.nextInt(1 << 30).toRadixString(36)}.$ext';

  static void _headers(HttpClientRequest req, String contentType) {
    req.headers.set('apikey', SupabaseConfig.anonKey);
    if (!SupabaseConfig.anonKey.startsWith('sb_')) {
      req.headers.set('Authorization', 'Bearer ${SupabaseConfig.anonKey}');
    }
    req.headers
      ..set('Content-Type', contentType)
      ..set('Cache-Control', 'max-age=31536000')
      ..set('x-upsert', 'false');
  }

  static String _publicUrl(String bucket, String path) =>
      '${SupabaseConfig.url}/storage/v1/object/public/$bucket/$path';

  static Future<void> _check(HttpClientResponse res) async {
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw HttpException("Envoi refusé (${res.statusCode}). $body");
    }
  }

  static void _ensureConfigured() {
    if (!SupabaseConfig.isConfigured) {
      throw StateError(
        "Supabase n'est pas configuré : renseignez l'URL et la clé dans lib/core/supabase_storage.dart.",
      );
    }
  }

  /// Réduit l'image (plus grand côté = [maxSide]) et la ré-encode en PNG.
  static Future<Uint8List> prepareImage(Uint8List raw, {int maxSide = 512}) async {
    final probe = await ui.instantiateImageCodec(raw);
    final first = (await probe.getNextFrame()).image;
    final w = first.width;
    final h = first.height;
    first.dispose();
    probe.dispose();

    ui.Codec codec;
    if (max(w, h) > maxSide) {
      codec = w >= h
          ? await ui.instantiateImageCodec(raw, targetWidth: maxSide)
          : await ui.instantiateImageCodec(raw, targetHeight: maxSide);
    } else {
      codec = await ui.instantiateImageCodec(raw);
    }
    final img = (await codec.getNextFrame()).image;
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    codec.dispose();
    if (data == null) throw const FormatException("Image illisible.");
    return data.buffer.asUint8List();
  }

  static Future<String> uploadCover(Uint8List raw) async {
    _ensureConfigured();
    final png = await prepareImage(raw, maxSide: 512);
    final path = 'covers/${_name('png')}';
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.postUrl(
        Uri.parse('${SupabaseConfig.url}/storage/v1/object/${SupabaseConfig.imageBucket}/$path'),
      );
      _headers(req, 'image/png');
      req.contentLength = png.length;
      req.add(png);
      await _check(await req.close().timeout(const Duration(seconds: 40)));
      return _publicUrl(SupabaseConfig.imageBucket, path);
    } finally {
      client.close(force: true);
    }
  }

  /// Envoie un PDF (flux, avec progression 0..1) et renvoie son URL.
  static Future<String> uploadPdf(
    File file, {
    required String folder,
    void Function(double progress)? onProgress,
  }) async {
    _ensureConfigured();
    final len = await file.length();
    if (len > maxPdfBytes) {
      throw const FormatException("Le PDF dépasse 25 Mo.");
    }
    final path = '$folder/${_name('pdf')}';
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.postUrl(
        Uri.parse('${SupabaseConfig.url}/storage/v1/object/${SupabaseConfig.pdfBucket}/$path'),
      );
      _headers(req, 'application/pdf');
      req.contentLength = len;
      var sent = 0;
      await req.addStream(
        file.openRead().map((chunk) {
          sent += chunk.length;
          onProgress?.call(sent / len);
          return chunk;
        }),
      );
      await _check(await req.close().timeout(const Duration(minutes: 5)));
      return _publicUrl(SupabaseConfig.pdfBucket, path);
    } finally {
      client.close(force: true);
    }
  }
}
