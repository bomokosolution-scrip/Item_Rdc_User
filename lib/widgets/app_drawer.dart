import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:item_rdc/core/app_config.dart';
import 'package:item_rdc/core/app_theme.dart';
import 'package:item_rdc/core/auth_service.dart';
import 'package:item_rdc/core/user_session.dart';
import 'package:item_rdc/pages/profile_page.dart';
import 'package:item_rdc/pages/security_page.dart';
import 'package:item_rdc/widgets/app_dialog.dart';
import 'package:item_rdc/widgets/premium_countdown.dart';
import 'package:item_rdc/widgets/ui.dart';
import 'package:item_rdc/widgets/user_avatar.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openExternalLink(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  var ok = false;
  if (uri != null) {
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
  if (!ok && context.mounted) {
    showToast(context, "Impossible d'ouvrir le lien.", error: true);
  }
}

/// Menu latéral. [onSelectTab] change l'onglet de l'écran principal.
class AppDrawer extends StatelessWidget {
  final int currentTab;
  final ValueChanged<int> onSelectTab;
  final VoidCallback onRefresh;

  const AppDrawer({
    super.key,
    required this.currentTab,
    required this.onSelectTab,
    required this.onRefresh,
  });

  void _closeThen(BuildContext context, VoidCallback action) {
    Navigator.of(context).pop();
    action();
  }

  void _push(BuildContext context, Widget page) {
    _closeThen(context, () {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    });
  }

  Future<void> _logout(BuildContext context) async {
    final ok = await confirmLogout(context);
    if (ok && context.mounted) {
      Navigator.of(context).popUntil((r) => r.isFirst);
      await authService.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: (MediaQuery.of(context).size.width * 0.86).clamp(260.0, 340.0),
      child: Column(
        children: [
          const _DrawerHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              children: [
                const _Label("Explorer"),
                _Tile(
                  icon: Icons.folder_copy_rounded,
                  title: "Documents",
                  selected: currentTab == 0,
                  onTap: () => _closeThen(context, () => onSelectTab(0)),
                ),
                _Tile(
                  icon: Icons.play_circle_fill_rounded,
                  title: "Vidéos",
                  selected: currentTab == 1,
                  onTap: () => _closeThen(context, () => onSelectTab(1)),
                ),
                _Tile(
                  icon: Icons.local_library_rounded,
                  title: "Bibliothèque",
                  selected: currentTab == 2,
                  onTap: () => _closeThen(context, () => onSelectTab(2)),
                ),
                _Tile(
                  icon: Icons.workspace_premium_rounded,
                  title: "Mon abonnement Premium",
                  selected: currentTab == 3,
                  onTap: () => _closeThen(context, () => onSelectTab(3)),
                ),
                const _Label("Compte"),
                _Tile(
                  icon: Icons.person_outline_rounded,
                  title: "Profil",
                  onTap: () => _push(context, const ProfilePage()),
                ),
                _Tile(
                  icon: Icons.shield_outlined,
                  title: "Sécurité",
                  onTap: () => _push(context, const SecurityPage()),
                ),
                const _Label("Support & Plus"),
                _Tile(
                  icon: Icons.sync_rounded,
                  title: "Synchroniser les données",
                  onTap: () => _closeThen(context, onRefresh),
                ),
                _Tile(
                  faIcon: FontAwesomeIcons.whatsapp,
                  title: "WhatsApp Admin",
                  onTap: () => _closeThen(
                    context,
                    () => openExternalLink(context, AppConfig.whatsApp),
                  ),
                ),
                _Tile(
                  faIcon: FontAwesomeIcons.telegram,
                  title: "Canal Telegram",
                  onTap: () => _closeThen(
                    context,
                    () => openExternalLink(context, AppConfig.telegram),
                  ),
                ),
                _Tile(
                  icon: Icons.apps_rounded,
                  title: "Plus d'applications",
                  onTap: () => _closeThen(
                    context,
                    () => openExternalLink(context, AppConfig.moreApps),
                  ),
                ),
                _Tile(
                  icon: Icons.share_rounded,
                  title: "Partager l'application",
                  onTap: () => _closeThen(context, () {
                    Clipboard.setData(
                      const ClipboardData(
                        text:
                            "Rejoins-moi sur Item RDC : cours, vidéos et bibliothèque universitaire. Contacte-nous sur WhatsApp : ${AppConfig.whatsApp}",
                      ),
                    );
                    showToast(context, "Lien de partage copié");
                  }),
                ),
                _Tile(
                  icon: Icons.info_outline_rounded,
                  title: "À propos",
                  onTap: () {
                    // Contexte stable : celui du Navigator (le menu se ferme).
                    final stable = Navigator.of(context).context;
                    Navigator.of(context).pop();
                    showAboutAppDialog(stable);
                  },
                ),
                const _Label("Apparence"),
                const _ThemeSelector(),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _logout(context),
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  label: const Text("Déconnexion"),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<UserSession>();
    final premium = session.isPremium;
    final expiry = session.premiumExpiry;
    final name = session.fullName.isEmpty ? "Utilisateur" : session.fullName;

    return GestureDetector(
      onLongPress: () {
        Clipboard.setData(
          ClipboardData(
            text:
                "Nom : $name\nE-mail : ${session.email}\nCompte : ${premium ? 'Premium' : 'Gratuit'}\nUID : ${session.uid}",
          ),
        );
        showToast(context, "Informations copiées");
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          20,
          MediaQuery.of(context).padding.top + 18,
          20,
          20,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.headerGradient(context),
          ),
          borderRadius: const BorderRadius.only(
            bottomRight: Radius.circular(28),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const UserAvatar(radius: 32),
                const Spacer(),
                PlanBadge(premium: premium),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              session.email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            if (premium && expiry != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 16, color: AppColors.gold),
                    const SizedBox(width: 8),
                    Expanded(
                      child: PremiumCountdown(
                        expiry: expiry,
                        compact: true,
                        color: AppColors.gold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
          color: Theme.of(context).textTheme.bodyMedium?.color,
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData? icon;
  final FaIconData? faIcon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _Tile({
    this.icon,
    this.faIcon,
    required this.title,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppColors.accent(context);
    final color = selected ? accent : theme.listTileTheme.iconColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? accent.withValues(alpha: 0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: faIcon != null
                      ? FaIcon(faIcon, size: 21, color: color)
                      : Icon(icon, size: 24, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? accent : theme.listTileTheme.textColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector();

  @override
  Widget build(BuildContext context) {
    final mode = context.select<ThemeManager, ThemeMode>((t) => t.themeMode);
    final manager = context.read<ThemeManager>();
    final accent = AppColors.accent(context);
    final dark = AppColors.isDark(context);

    Widget chip(ThemeMode m, IconData icon, String label) {
      final selected = mode == m;
      return Expanded(
        child: GestureDetector(
          onTap: () => manager.setMode(m),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? (dark ? AppColors.brandDark : AppColors.brand)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color,
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          chip(ThemeMode.system, Icons.brightness_auto_rounded, "Auto"),
          chip(ThemeMode.light, Icons.light_mode_rounded, "Clair"),
          chip(ThemeMode.dark, Icons.dark_mode_rounded, "Sombre"),
        ],
      ),
    );
  }
}
