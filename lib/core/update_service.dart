import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:item_rdc/core/app_config.dart';

/// Informations de version publiées dans Pastebin (JSON brut).
///
/// Exemple :
/// {
///   "version_code": 2,
///   "version_name": "1.0.1",
///   "force": true,
///   "min_version_code": 0,
///   "apk_url": "https://exemple.com/item_rdc_1.0.1.apk",
///   "apk_url_android7": "https://exemple.com/item_rdc_1.0.1_android7.apk",
///   "apk_url_android8plus": "https://exemple.com/item_rdc_1.0.1_android8plus.apk",
///   "message": "Nouveautés : ..."
/// }
///
/// - `apk_url` : lien par défaut (obligatoire s'il n'y a pas les deux liens ci-dessous).
/// - `apk_url_android7` : APK pour Android 7.1 et moins (API <= 25).
/// - `apk_url_android8plus` : APK pour Android 8 et plus (API >= 26).
/// Si les deux liens spécifiques sont fournis, l'application choisit
/// automatiquement le bon selon le téléphone et laisse l'utilisateur changer.
class UpdateInfo {
  final int versionCode;
  final String versionName;
  final bool force;
  final int minVersionCode;
  final String apkUrl;
  final String apkUrlAndroid7;
  final String apkUrlAndroid8Plus;
  final String message;

  const UpdateInfo({
    required this.versionCode,
    required this.versionName,
    required this.force,
    required this.minVersionCode,
    required this.apkUrl,
    this.apkUrlAndroid7 = '',
    this.apkUrlAndroid8Plus = '',
    required this.message,
  });

  /// Android 7.1 (API 25) et moins = version « Android 7 ».
  static const int legacyMaxSdk = 25;

  static bool isLegacySdk(int sdkInt) => sdkInt > 0 && sdkInt <= legacyMaxSdk;

  /// Lien à utiliser pour la famille d'Android choisie (repli : `apk_url`).
  String urlFor({required bool legacy}) {
    final specific = legacy ? apkUrlAndroid7 : apkUrlAndroid8Plus;
    return specific.isNotEmpty ? specific : apkUrl;
  }

  /// Vrai si deux APK différents sont proposés (Android 7 / Android 8+).
  bool get hasChoice =>
      urlFor(legacy: true).isNotEmpty &&
      urlFor(legacy: false).isNotEmpty &&
      urlFor(legacy: true) != urlFor(legacy: false);

  bool get hasAnyUrl =>
      apkUrl.isNotEmpty || apkUrlAndroid7.isNotEmpty || apkUrlAndroid8Plus.isNotEmpty;

  /// Obligatoire si `force` est vrai, ou si la version installée est
  /// plus ancienne que `min_version_code`.
  bool isMandatory(int installedCode) =>
      force || UpdateService.norm(installedCode) < UpdateService.norm(minVersionCode);
}

class InstalledApp {
  final int versionCode;
  final String versionName;

  /// Version d'Android du téléphone (API) et son nom (ex. « 7.1.2 »).
  final int sdkInt;
  final String release;
  const InstalledApp(this.versionCode, this.versionName, {this.sdkInt = 0, this.release = ''});
}

/// Pont vers le code natif Android (MainActivity.kt).
class NativeUpdater {
  static const MethodChannel _ch = MethodChannel('com.vault.itemrdc/updater');

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<InstalledApp> appInfo() async {
    if (!supported) return const InstalledApp(1, AppConfig.fallbackVersionName);
    try {
      final m = await _ch.invokeMapMethod<String, dynamic>('appInfo');
      final code = (m?['versionCode'] as num?)?.toInt() ?? 1;
      final name = (m?['versionName'] as String?) ?? AppConfig.fallbackVersionName;
      return InstalledApp(
        code,
        name.isEmpty ? AppConfig.fallbackVersionName : name,
        sdkInt: (m?['sdkInt'] as num?)?.toInt() ?? 0,
        release: (m?['release'] as String?) ?? '',
      );
    } catch (_) {
      return const InstalledApp(1, AppConfig.fallbackVersionName);
    }
  }

  static Future<bool> canInstall() async =>
      (await _ch.invokeMethod<bool>('canInstall')) ?? false;

  static Future<void> openInstallSettings() =>
      _ch.invokeMethod<void>('openInstallSettings');

  static Future<void> installApk(String path) =>
      _ch.invokeMethod<void>('installApk', {'path': path});

  static Future<String> saveToDownloads(String path, String name) async =>
      (await _ch.invokeMethod<String>('saveToDownloads', {
        'path': path,
        'name': name,
      })) ??
      'Téléchargements/$name';

  static Future<void> uninstall() => _ch.invokeMethod<void>('uninstall');

  /// Empêche captures d'écran / enregistrement d'écran (FLAG_SECURE).
  static Future<void> setSecure(bool secure) async {
    if (!supported) return;
    try {
      await _ch.invokeMethod<void>('setSecure', {'secure': secure});
    } catch (_) {}
  }

  static Future<void> openDownloads() => _ch.invokeMethod<void>('openDownloads');
}

class UpdateService {
  UpdateService._();

  static bool get isConfigured =>
      AppConfig.updateUrl.isNotEmpty && !AppConfig.updateUrl.contains('REPLACE_ME');

  /// Résultat de la dernière vérification (affiché dans « À propos » pour
  /// comprendre rapidement pourquoi une mise à jour n'apparaît pas).
  static String status = "Pas encore vérifié";
  static DateTime? lastCheck;

  /// Vrai si le dernier contrôle a bien pu lire le Pastebin (réponse valide).
  /// Permet de distinguer « pas de mise à jour » d'une simple panne réseau.
  static bool lastOk = false;

  /// `flutter build --split-per-abi` ajoute au code de version un décalage de
  /// 1000 (armeabi-v7a), 2000 (arm64-v8a) ou 4000 (x86_64) : 2003 devient 4003
  /// sur un téléphone récent. On compare donc uniquement les 3 derniers
  /// chiffres (2003 -> 3 et 4003 -> 3) : identique quel que soit l'APK installé.
  static int norm(int code) => code % 1000;

  static const String _userAgent =
      'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36';

  /// `https://pastebin.com/AbCd1234` -> `https://pastebin.com/raw/AbCd1234`
  static String rawUrl() {
    final uri = Uri.tryParse(AppConfig.updateUrl.trim());
    if (uri == null) return AppConfig.updateUrl.trim();
    final seg = uri.pathSegments.where((e) => e.isNotEmpty).toList();
    if (uri.host.contains('pastebin.com') && seg.length == 1 && seg.first != 'raw') {
      return 'https://pastebin.com/raw/${seg.first}';
    }
    return '${uri.scheme}://${uri.host}${uri.path}';
  }

  static dynamic _decode(String body) {
    // Caractères invisibles ajoutés par certains copier-coller (marques de
    // sens de lecture, espaces insécables, largeur nulle) : ils cassent le JSON.
    var t = body
        .replaceAll(RegExp('[\u200B-\u200F\u202A-\u202E\u2060\uFEFF]'), '')
        .replaceAll('\u00A0', ' ')
        .trim();
    // Blocs de code Markdown éventuels.
    t = t.replaceAll(RegExp(r'^```[a-zA-Z]*\s*'), '').replaceAll(RegExp(r'\s*```$'), '');
    // Guillemets typographiques.
    t = t.replaceAll('\u201C', '"').replaceAll('\u201D', '"').replaceAll('\u2019', "'");
    try {
      return jsonDecode(t);
    } catch (_) {
      // Virgules en trop avant } ou ]
      final fixed = t.replaceAllMapped(RegExp(r',\s*([}\]])'), (m) => m[1]!);
      return jsonDecode(fixed);
    }
  }

  static dynamic _pick(Map m, List<String> keys) {
    for (final k in keys) {
      if (m.containsKey(k) && m[k] != null) return m[k];
    }
    return null;
  }

  /// Compare "1.2.10" et "1.2.9" numériquement.
  static int _compareNames(String a, String b) {
    List<int> parts(String v) => v
        .split(RegExp(r'[^0-9]+'))
        .where((e) => e.isNotEmpty)
        .map(int.parse)
        .toList();
    final pa = parts(a), pb = parts(b);
    for (var i = 0; i < math.max(pa.length, pb.length); i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x.compareTo(y);
    }
    return 0;
  }

  /// Retourne les infos de mise à jour si une version plus récente existe,
  /// sinon `null` (aussi `null` en cas d'erreur réseau : on ne bloque jamais
  /// l'utilisateur à cause d'un problème de connexion).
  static Future<UpdateInfo?> check() async {
    lastCheck = DateTime.now();
    lastOk = false;
    if (!NativeUpdater.supported) {
      status = "Vérification disponible uniquement sur Android";
      return null;
    }
    if (!isConfigured) {
      status = "Lien Pastebin non configuré (app_config.dart)";
      return null;
    }

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8)
      ..userAgent = _userAgent;
    try {
      // Paramètre aléatoire : évite tout cache du Pastebin.
      final uri = Uri.parse(
        '${rawUrl()}?t=${DateTime.now().millisecondsSinceEpoch}',
      );
      final req = await client.getUrl(uri);
      req.headers.set(HttpHeaders.cacheControlHeader, 'no-cache, no-store');
      req.headers.set(HttpHeaders.pragmaHeader, 'no-cache');
      req.headers.set(HttpHeaders.acceptHeader, 'text/plain,application/json,*/*');
      final resp = await req.close().timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) {
        status = "Pastebin a répondu : HTTP ${resp.statusCode}";
        await resp.drain<void>();
        return null;
      }

      final body = await resp.transform(utf8.decoder).join();
      dynamic json;
      try {
        json = _decode(body);
      } catch (_) {
        status = "Contenu Pastebin illisible (JSON invalide ou page HTML)";
        return null;
      }
      if (json is! Map) {
        status = "Le Pastebin doit contenir un objet JSON { ... }";
        return null;
      }

      int asInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v'.trim()) ?? 0;
      bool asBool(dynamic v) {
        final t = '$v'.trim().toLowerCase();
        return v == true || t == 'true' || t == '1' || t == 'oui' || t == 'yes';
      }

      final info = UpdateInfo(
        versionCode: asInt(_pick(json, ['version_code', 'versionCode', 'code', 'build'])),
        versionName: '${_pick(json, ['version_name', 'versionName', 'version']) ?? ''}',
        force: asBool(_pick(json, ['force', 'mandatory', 'force_update', 'obligatoire'])),
        minVersionCode: asInt(_pick(json, ['min_version_code', 'minVersionCode', 'min_code'])),
        apkUrl: '${_pick(json, ['apk_url', 'apkUrl', 'url', 'download_url', 'apk']) ?? ''}'.trim(),
        apkUrlAndroid7: '${_pick(json, ['apk_url_android7', 'apkUrlAndroid7', 'apk_android7', 'url_android7']) ?? ''}'.trim(),
        apkUrlAndroid8Plus: '${_pick(json, ['apk_url_android8plus', 'apkUrlAndroid8Plus', 'apk_android8plus', 'url_android8plus']) ?? ''}'.trim(),
        message: '${_pick(json, ['message', 'notes', 'changelog', 'description']) ?? ''}'.trim(),
      );

      lastOk = true; // Pastebin lu et compris
      final installed = await NativeUpdater.appInfo();
      final String current = "v${installed.versionName} (code ${installed.versionCode})";

      // Plus récente ? On compare le code de version ; à défaut, le nom.
      final bool newer;
      if (info.versionCode > 0) {
        newer = norm(info.versionCode) > norm(installed.versionCode);
      } else if (info.versionName.isNotEmpty) {
        newer = _compareNames(info.versionName, installed.versionName) > 0;
      } else {
        status = "Pastebin : ajoutez version_code ou version_name";
        return null;
      }

      if (!newer) {
        status = "À jour — installée $current, Pastebin ${info.versionName} (code ${info.versionCode})";
        return null;
      }
      if (!info.hasAnyUrl) {
        status = "Mise à jour détectée mais apk_url est vide dans le Pastebin";
        return null;
      }
      status = "Mise à jour détectée : ${info.versionName} (installée $current)";
      return info;
    } on SocketException {
      status = "Pas de connexion internet";
      return null;
    } on TimeoutException {
      status = "Délai dépassé en lisant le Pastebin";
      return null;
    } catch (e) {
      status = "Erreur : $e";
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// Convertit un lien de partage Google Drive en lien de téléchargement.
  static String normalizeUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri != null && uri.host.contains('drive.google.com')) {
      final seg = uri.pathSegments;
      final i = seg.indexOf('d');
      final id = (i != -1 && seg.length > i + 1)
          ? seg[i + 1]
          : uri.queryParameters['id'];
      if (id != null) {
        return 'https://drive.google.com/uc?export=download&confirm=t&id=$id';
      }
    }
    return url;
  }

  /// Télécharge l'APK dans le cache de l'application (aucun accès stockage
  /// requis) en signalant la progression. Lève une exception en cas d'échec.
  static Future<File> download(
    UpdateInfo info, {
    required void Function(int received, int total) onProgress,
    bool Function()? isCancelled,
    String? url,
    String variant = '',
  }) async {
    final target = Uri.tryParse(normalizeUrl((url ?? info.apkUrl).trim()));
    if (target == null ||
        !(target.scheme == 'http' || target.scheme == 'https') ||
        target.host.isEmpty) {
      throw const HttpException(
        "Le lien de téléchargement du Pastebin est invalide (il doit commencer par https://).",
      );
    }
    final dir = Directory('${Directory.systemTemp.path}/updates');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final safeName = info.versionName.replaceAll(RegExp(r'[^0-9A-Za-z._-]'), '_');
    final file = File('${dir.path}/item_rdc_$safeName$variant.apk');
    if (file.existsSync()) file.deleteSync();

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    IOSink? sink;
    try {
      final req = await client.getUrl(target);
      final resp = await req.close();
      if (resp.statusCode != 200) {
        throw HttpException('Serveur indisponible (code ${resp.statusCode}).');
      }
      final contentType = resp.headers.contentType?.mimeType ?? '';
      if (contentType.contains('html')) {
        throw const HttpException("Le lien ne pointe pas vers un fichier APK.");
      }

      final total = resp.contentLength; // -1 si inconnu
      sink = file.openWrite();
      var received = 0;
      await for (final chunk in resp) {
        if (isCancelled?.call() == true) throw const HttpException('Annulé');
        sink.add(chunk);
        received += chunk.length;
        onProgress(received, total);
      }
      await sink.flush();
      await sink.close();
      sink = null;

      if (total > 0 && received != total) {
        throw const HttpException('Téléchargement incomplet. Réessayez.');
      }
      // Un APK est une archive ZIP : il commence par "PK".
      final head = await file.openRead(0, 2).first;
      if (head.length < 2 || head[0] != 0x50 || head[1] != 0x4B) {
        throw const HttpException("Le fichier téléchargé n'est pas un APK valide.");
      }
      onProgress(received, received);
      return file;
    } catch (e) {
      try {
        await sink?.close();
      } catch (_) {}
      if (file.existsSync()) file.deleteSync();
      rethrow;
    } finally {
      client.close(force: true);
    }
  }
}
