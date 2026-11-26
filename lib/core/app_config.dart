/// Liens de contact et paramètres généraux.
class AppConfig {
  static const String whatsApp = "https://wa.me/243891989036";
  static const String telegram = "https://t.me/GodWinAdmin";
  static const String moreApps = "https://apps.worldsolution.site";

  /// Développeur
  static const String developerName = "Bomoko Solution";
  static const String developerEmail = "bomokosolution@gmail.com";

  /// Lien RAW de votre Pastebin contenant les informations de mise à jour
  /// (JSON). Remplacez REPLACE_ME par l'identifiant de votre paste, par
  /// exemple : https://pastebin.com/raw/AbCd1234
  static const String updateUrl = "https://pastebin.com/raw/uyydKb9D";

  /// Utilisée seulement si la version native n'est pas lisible.
  static const String fallbackVersionName = "1.0.0";

  /// Durée d'essai Premium offerte à l'inscription.
  static const Duration signupTrial = Duration(days: 1);
}
