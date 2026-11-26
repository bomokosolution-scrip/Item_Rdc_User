import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:item_rdc/core/app_config.dart';
import 'package:item_rdc/core/app_theme.dart';
import 'package:item_rdc/core/update_service.dart';
import 'package:item_rdc/widgets/ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// Affiche une boîte de dialogue avec animation (zoom + fondu).
Future<T?> showAppDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'dialog',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (ctx, _, _) => SafeArea(child: Center(child: builder(ctx))),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: ScaleTransition(scale: Tween(begin: 0.86, end: 1.0).animate(curved), child: child),
      );
    },
  );
}

/// Coque commune : en-tête dégradé avec icône ronde, puis le contenu.
class AppDialogShell extends StatelessWidget {
  final IconData? icon;
  final Widget? headerChild;
  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget> actions;

  const AppDialogShell({
    super.key,
    this.icon,
    this.headerChild,
    required this.title,
    this.subtitle,
    required this.body,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = AppColors.isDark(context);

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        constraints: const BoxConstraints(maxWidth: 380),
        decoration: BoxDecoration(
          color: dark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 40,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: AppColors.headerGradient(context),
                  ),
                ),
                child: Column(
                  children: [
                    headerChild ??
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(icon, color: Colors.white, size: 34),
                        ),
                    const SizedBox(height: 14),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 6),
                child: DefaultTextStyle(
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.45,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                  textAlign: TextAlign.center,
                  child: body,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
                child: Row(
                  children: [
                    for (int i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(child: actions[i]),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialogue de confirmation stylé. Retourne `true` si confirmé.
Future<bool> showAppConfirm(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String message,
  String confirmLabel = "Confirmer",
  String cancelLabel = "Annuler",
  bool destructive = false,
}) async {
  final result = await showAppDialog<bool>(
    context,
    builder: (ctx) => AppDialogShell(
      icon: icon,
      title: title,
      body: Text(message),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: destructive ? AppColors.authRed : null,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Confirmation avant de quitter l'application.
Future<bool> confirmExit(BuildContext context) => showAppConfirm(
  context,
  icon: Icons.exit_to_app_rounded,
  title: "Quitter l'application ?",
  message: "Voulez-vous vraiment quitter Item RDC ?",
  confirmLabel: "Quitter",
  cancelLabel: "Rester",
  destructive: true,
);

/// Confirmation de déconnexion.
Future<bool> confirmLogout(BuildContext context) => showAppConfirm(
  context,
  icon: Icons.logout_rounded,
  title: "Se déconnecter ?",
  message:
      "Vous devrez vous reconnecter pour accéder à vos cours, vidéos et à votre abonnement.",
  confirmLabel: "Se déconnecter",
  cancelLabel: "Annuler",
  destructive: true,
);

/// Boîte « À propos » : application, version, développeur.
Future<void> showAboutAppDialog(BuildContext context) async {
  final installed = await NativeUpdater.appInfo();
  if (!context.mounted) return;

  await showAppDialog<void>(
    context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return AppDialogShell(
        headerChild: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Image.asset(
              'assets/images/app_icon.png',
              width: 78,
              height: 78,
              cacheWidth: 240,
              errorBuilder: (_, _, _) => const SizedBox(
                width: 78,
                height: 78,
                child: Icon(Icons.school_rounded, color: Colors.white, size: 44),
              ),
            ),
          ),
        ),
        title: "Item RDC",
        subtitle: "Version ${installed.versionName} (${installed.versionCode})",
        body: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Cours, vidéos et bibliothèque universitaire : tout ce dont vous avez besoin, au même endroit.",
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.accent(ctx).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.accent(ctx).withValues(alpha: 0.25)),
              ),
              child: Column(
                children: [
                  Text(
                    "DÉVELOPPÉ PAR",
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w800,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppConfig.developerName,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accent(ctx),
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () async {
                      await Clipboard.setData(
                        const ClipboardData(text: AppConfig.developerEmail),
                      );
                      if (ctx.mounted) showToast(ctx, "E-mail copié");
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.mail_outline_rounded, size: 18, color: theme.textTheme.bodyLarge?.color),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              AppConfig.developerEmail,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.copy_rounded, size: 15, color: theme.textTheme.bodyMedium?.color),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Mises à jour : ${UpdateService.status}",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "© ${DateTime.now().year} ${AppConfig.developerName} — Tous droits réservés",
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () => launchUrl(
              Uri.parse('mailto:${AppConfig.developerEmail}?subject=Item%20RDC'),
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text("Contacter"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Fermer"),
          ),
        ],
      );
    },
  );
}
