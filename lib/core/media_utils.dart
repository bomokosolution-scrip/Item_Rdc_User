/// Outils pour ouvrir PDF et vidéos INSTANTANÉMENT, sans les télécharger.
///
/// - Google Drive : on utilise la page `/preview` (diffusion en continu,
///   la première page / les premières secondes s'affichent immédiatement).
/// - PDF ailleurs : visionneuse en ligne (rendu côté serveur, pas de
///   téléchargement du fichier complet sur le téléphone).
/// - YouTube : lecteur YouTube intégré.
/// - Fichier vidéo direct (mp4...) : lecture en streaming (ExoPlayer).
class MediaUtils {
  MediaUtils._();

  /// Ajoute https:// si besoin et retire les espaces.
  static String clean(String url) {
    final u = url.trim();
    if (u.isEmpty) return u;
    if (u.startsWith('http://') || u.startsWith('https://')) return u;
    return 'https://$u';
  }

  static String? driveId(String url) {
    final uri = Uri.tryParse(clean(url));
    if (uri == null || !uri.host.contains('drive.google.com')) return null;
    final seg = uri.pathSegments;
    final i = seg.indexOf('d');
    if (i != -1 && seg.length > i + 1) return seg[i + 1];
    final id = uri.queryParameters['id'];
    return (id != null && id.isNotEmpty) ? id : null;
  }

  static bool isDrive(String url) => driveId(url) != null;

  static bool isYoutube(String url) {
    final host = Uri.tryParse(clean(url))?.host.toLowerCase() ?? '';
    return host.contains('youtube.com') ||
        host.contains('youtu.be') ||
        host.contains('youtube-nocookie.com');
  }

  static String drivePreviewUrl(String id) =>
      'https://drive.google.com/file/d/$id/preview';

  static String driveDownloadUrl(String id) =>
      'https://drive.google.com/uc?export=download&confirm=t&id=$id';

  /// URL à charger dans la visionneuse de documents.
  static String documentViewUrl(String url) {
    final id = driveId(url);
    if (id != null) return drivePreviewUrl(id);
    final u = clean(url);
    return 'https://docs.google.com/gview?embedded=1&url=${Uri.encodeComponent(u)}';
  }

  /// URL directe (pour le lecteur PDF natif ou le navigateur).
  static String directUrl(String url) {
    final id = driveId(url);
    return id != null ? driveDownloadUrl(id) : clean(url);
  }

  static bool looksLikePdf(String url) {
    final path = (Uri.tryParse(clean(url))?.path ?? '').toLowerCase();
    return path.endsWith('.pdf');
  }

  static bool looksLikeVideoFile(String url) {
    final path = (Uri.tryParse(clean(url))?.path ?? '').toLowerCase();
    return path.endsWith('.mp4') ||
        path.endsWith('.m3u8') ||
        path.endsWith('.webm') ||
        path.endsWith('.mov') ||
        path.endsWith('.mkv');
  }
}
