import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mode d'affichage des fichiers : liste compacte, détails (couverture +
/// propriétaire) ou grandes cartes. Le choix est mémorisé.
enum ViewMode { list, details, large }

class ViewModeStore extends ValueNotifier<ViewMode> {
  ViewModeStore._() : super(ViewMode.list);
  static final ViewModeStore instance = ViewModeStore._();

  static const String _key = 'view_mode';

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final saved = p.getString(_key);
      value = ViewMode.values.firstWhere(
        (m) => m.name == saved,
        orElse: () => ViewMode.list,
      );
    } catch (_) {}
  }

  Future<void> choose(ViewMode mode) async {
    value = mode;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key, mode.name);
    } catch (_) {}
  }
}
