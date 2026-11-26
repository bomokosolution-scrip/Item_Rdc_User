import 'package:flutter_test/flutter_test.dart';
import 'package:item_rdc/core/media_utils.dart';
import 'package:item_rdc/widgets/premium_countdown.dart';

void main() {
  group('MediaUtils', () {
    test('Google Drive : /file/d/ID/view -> /preview', () {
      const url = 'https://drive.google.com/file/d/ABC123/view?usp=sharing';
      expect(MediaUtils.driveId(url), 'ABC123');
      expect(MediaUtils.documentViewUrl(url),
          'https://drive.google.com/file/d/ABC123/preview');
    });

    test('Google Drive : open?id=ID', () {
      expect(MediaUtils.driveId('https://drive.google.com/open?id=XYZ'), 'XYZ');
    });

    test('PDF direct -> visionneuse en ligne', () {
      expect(
        MediaUtils.documentViewUrl('https://site.com/a b.pdf'),
        startsWith('https://docs.google.com/gview?embedded=1&url='),
      );
    });

    test('YouTube et fichiers vidéo', () {
      expect(MediaUtils.isYoutube('https://youtu.be/abc'), true);
      expect(MediaUtils.isYoutube('https://site.com/v.mp4'), false);
      expect(MediaUtils.looksLikeVideoFile('https://site.com/v.mp4'), true);
    });
  });

  group('TimeParts', () {
    test('jours, heures, minutes, secondes, tierces', () {
      final p = TimeParts.from(
        const Duration(days: 2, hours: 3, minutes: 4, seconds: 5, milliseconds: 500),
      );
      expect([p.days, p.hours, p.minutes, p.seconds], [2, 3, 4, 5]);
      expect(p.tierces, 30); // 0,5 s = 30 tierces
    });

    test('durée négative -> zéro', () {
      final p = TimeParts.from(const Duration(seconds: -5));
      expect([p.days, p.hours, p.minutes, p.seconds, p.tierces], [0, 0, 0, 0, 0]);
    });
  });
}
