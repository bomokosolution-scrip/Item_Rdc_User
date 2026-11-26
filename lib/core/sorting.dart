import 'package:cloud_firestore/cloud_firestore.dart';

/// Modes de tri proposés dans les listes (dossiers, catégories, universités…).
enum SortMode { newest, oldest, az, za, most }

class Sorting {
  Sorting._();

  static const Map<String, String> _accents = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
    'ç': 'c',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
    'ñ': 'n',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
    'ý': 'y', 'ÿ': 'y',
  };

  /// Minuscules sans accents : « Économie » se classe avec les « E ».
  static String fold(String s) {
    final lower = s.trim().toLowerCase();
    final b = StringBuffer();
    for (final r in lower.runes) {
      final ch = String.fromCharCode(r);
      b.write(_accents[ch] ?? ch);
    }
    return b.toString();
  }

  /// Date d'un champ Firestore (`createdAt`). Un document tout juste créé
  /// (horodatage serveur pas encore confirmé) est considéré comme « maintenant ».
  static DateTime? dateOf(Object? raw, {bool pending = false}) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    if (raw == null && pending) return DateTime.now();
    return null;
  }

  /// Trie sans modifier la liste d'origine. Tri stable : à critère égal,
  /// l'ordre d'origine est conservé. Les éléments sans date (anciens
  /// contenus) sont considérés comme les plus anciens.
  static List<T> apply<T>(
    Iterable<T> input,
    SortMode mode, {
    required String Function(T) title,
    DateTime? Function(T)? date,
    int Function(T)? count,
  }) {
    final list = input.toList();
    // Index d'origine pour garantir la stabilité du tri.
    final order = List<int>.generate(list.length, (i) => i);
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);

    int cmpIndex(int a, int b) => a.compareTo(b);

    order.sort((a, b) {
      final x = list[a];
      final y = list[b];
      int r;
      switch (mode) {
        case SortMode.az:
          r = fold(title(x)).compareTo(fold(title(y)));
          break;
        case SortMode.za:
          r = fold(title(y)).compareTo(fold(title(x)));
          break;
        case SortMode.newest:
          r = (date?.call(y) ?? epoch).compareTo(date?.call(x) ?? epoch);
          break;
        case SortMode.oldest:
          r = (date?.call(x) ?? epoch).compareTo(date?.call(y) ?? epoch);
          break;
        case SortMode.most:
          r = (count?.call(y) ?? 0).compareTo(count?.call(x) ?? 0);
          break;
      }
      return r != 0 ? r : cmpIndex(a, b);
    });
    return [for (final i in order) list[i]];
  }
}

/// « Internship » a été renommé « Stage » : les anciens documents enregistrés
/// avec l'ancien nom restent visibles et sont affichés sous « Stage ».
String normType(Object? raw) {
  final t = (raw ?? '').toString().trim();
  return t.toLowerCase() == 'internship' ? 'Stage' : t;
}
