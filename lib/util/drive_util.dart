class DriveUtil {
  static String getDirectLink(String url) {
    if (url.contains('drive.google.com')) {
      final RegExp regExp = RegExp(r'\/d\/([^\/]+)|id=([^\&]+)');
      final Match? match = regExp.firstMatch(url);
      if (match != null) {
        final String id = match.group(1) ?? match.group(2) ?? "";
        if (id.isNotEmpty) {
          // Format UC pour streaming direct
          return 'https://drive.google.com/uc?id=$id&confirm=t';
        }
      }
    }
    return url;
  }

  static bool isVideo(String url, String? type) {
    final lowerUrl = url.toLowerCase();
    final lowerType = type?.toLowerCase() ?? "";
    
    final videoExtensions = ['.mp4', '.mkv', '.mov', '.avi', '.webm', '.3gp', '.flv'];
    bool hasVideoExt = videoExtensions.any((ext) => lowerUrl.contains(ext));
    bool isVideoType = lowerType.contains('video') || lowerType == 'mp4';
    
    if (lowerUrl.contains('drive.google.com')) {
      // Si ce n'est pas un PDF, on traite comme une vidéo pour privilégier le streaming
      if (lowerUrl.contains('.pdf') || lowerType.contains('pdf')) return false;
      return true; 
    }

    return hasVideoExt || isVideoType || lowerUrl.contains('youtube.com') || lowerUrl.contains('youtu.be');
  }
}
