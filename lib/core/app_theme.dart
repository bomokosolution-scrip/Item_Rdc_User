import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Palette d'origine de l'application (inchangée).
class AppColors {
  static const Color brand = Color(0xFF7B3221);
  static const Color brandDark = Color(0xFF780000);
  static const Color lightBackground = Color(0xFFF0F2F5);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color darkBackground = Color(0xFF0F0F0F);
  static const Color darkCard = Color(0xFF1A1A1A);

  /// Rouge des illustrations / boutons d'authentification d'origine.
  static const Color authRed = Color(0xFF780000);
  static const Color authSheet = Color(0xFF501010);

  // Nuances dérivées de la teinte de la marque.
  static const Color brandDeep = Color(0xFF5C2418);
  static const Color brandDarker = Color(0xFF2A0808);
  static const Color brandSoft = Color(0xFFE0A090);

  static const Color gold = Color(0xFFFFC857);

  static bool isDark(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark;

  static Color accent(BuildContext c) => isDark(c) ? brandSoft : brand;

  static List<Color> headerGradient(BuildContext c) => isDark(c)
      ? const [Color(0xFF5A1010), brandDarker]
      : const [brand, brandDeep];
}

class ThemeManager extends ChangeNotifier {
  static const String _prefKey = 'theme_mode';
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  /// Recharge le thème choisi lors du dernier lancement.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      switch (prefs.getString(_prefKey)) {
        case 'dark':
          _themeMode = ThemeMode.dark;
        case 'light':
          _themeMode = ThemeMode.light;
        default:
          _themeMode = ThemeMode.system;
      }
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefKey,
        _themeMode == ThemeMode.dark
            ? 'dark'
            : _themeMode == ThemeMode.light
            ? 'light'
            : 'system',
      );
    } catch (_) {}
  }

  void setMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    _persist();
  }

  void toggleTheme(bool isDarkMode) =>
      setMode(isDarkMode ? ThemeMode.dark : ThemeMode.light);

  void setSystemTheme() => setMode(ThemeMode.system);

  static const RoundedRectangleBorder _roundedTop = RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  );

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: AppColors.brand,
    scaffoldBackgroundColor: AppColors.lightBackground,
    colorScheme: ColorScheme.light(
      primary: AppColors.brand,
      onPrimary: Colors.white,
      secondary: AppColors.brandDeep,
      onSecondary: Colors.white,
      surface: const Color(0xFFF4F0EF),
      onSurface: Colors.black87,
      error: const Color(0xFFB3261E),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.brand,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 19,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.black87),
      bodyMedium: TextStyle(color: Colors.black54),
    ),
    cardTheme: CardThemeData(
      color: AppColors.lightCard,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      textColor: Colors.black,
      iconColor: Colors.black54,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: Colors.black38),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.brand, width: 1.6),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.brand,
        minimumSize: const Size(0, 48),
        side: BorderSide(color: AppColors.brand.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.lightCard,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.lightCard,
      surfaceTintColor: Colors.transparent,
      shape: _roundedTop,
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: AppColors.lightBackground,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.brandDeep,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: DividerThemeData(
      color: Colors.black.withValues(alpha: 0.08),
      space: 1,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.brand,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: AppColors.brandDark,
    scaffoldBackgroundColor: AppColors.darkBackground,
    colorScheme: ColorScheme.dark(
      primary: AppColors.brandSoft,
      onPrimary: AppColors.brandDark,
      secondary: AppColors.brandSoft,
      onSecondary: AppColors.brandDark,
      surface: const Color(0xFF242424),
      onSurface: Colors.white,
      error: const Color(0xFFF2B8B5),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkCard,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 19,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white70),
    ),
    cardTheme: CardThemeData(
      color: AppColors.darkCard,
      shadowColor: Colors.white.withValues(alpha: 0.1),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      textColor: Colors.white,
      iconColor: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF2A2A2A),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: Colors.white38),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.brandSoft, width: 1.6),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.brandDark,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.brandDark,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.brandSoft,
        minimumSize: const Size(0, 48),
        side: BorderSide(color: AppColors.brandSoft.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.darkCard,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.darkCard,
      surfaceTintColor: Colors.transparent,
      shape: _roundedTop,
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: AppColors.darkBackground,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF2E2E2E),
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: DividerThemeData(
      color: Colors.white.withValues(alpha: 0.08),
      space: 1,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.brandSoft,
    ),
  );
}
