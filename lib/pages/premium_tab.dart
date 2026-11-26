import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:item_rdc/core/app_config.dart';
import 'package:item_rdc/core/app_theme.dart';
import 'package:item_rdc/core/user_session.dart';
import 'package:item_rdc/widgets/app_drawer.dart' show openExternalLink;
import 'package:item_rdc/widgets/premium_countdown.dart';
import 'package:item_rdc/widgets/ui.dart';
import 'package:item_rdc/widgets/user_avatar.dart';
import 'package:provider/provider.dart';

/// Onglet "Mon abonnement" : statut, date d'expiration complète et compte à
/// rebours (jours, heures, minutes, secondes, tierces).
class PremiumTab extends StatelessWidget {
  const PremiumTab({super.key});

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final session = context.watch<UserSession>();
    final premium = session.isPremium;
    final expiry = session.premiumExpiry;
    final bought = session.premiumBoughtAt;

    final dateFmt = DateFormat("EEEE d MMMM yyyy", 'fr_FR');
    final timeFmt = DateFormat("HH:mm:ss", 'fr_FR');

    double? progress;
    if (premium && expiry != null && bought != null) {
      final total = expiry.difference(bought).inSeconds;
      if (total > 0) {
        progress = (expiry.difference(DateTime.now()).inSeconds / total).clamp(0.0, 1.0);
      }
    }

    return ResponsiveBody(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          FadeSlideIn(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: premium
                      ? AppColors.headerGradient(context)
                      : [const Color(0xFF4A4A4A), const Color(0xFF2B2B2B)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const UserAvatar(radius: 26),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              session.fullName.isEmpty ? "Utilisateur" : session.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              session.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                      PlanBadge(premium: premium),
                    ],
                  ),
                  const SizedBox(height: 22),
                  if (premium && expiry != null) ...[
                    const Text(
                      "TEMPS RESTANT",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    PremiumCountdown(expiry: expiry),
                    if (progress != null) ...[
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          color: AppColors.gold,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                    ],
                  ] else ...[
                    Row(
                      children: [
                        const Icon(Icons.lock_outline_rounded, color: Colors.white70),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            session.wasPremium
                                ? "Votre abonnement Premium a expiré."
                                : "Vous utilisez le compte gratuit.",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (expiry != null)
            FadeSlideIn(
              index: 1,
              child: _InfoCard(
                rows: [
                  _InfoRow(
                    Icons.event_rounded,
                    premium ? "Expire le" : "A expiré le",
                    "${_cap(dateFmt.format(expiry))} à ${timeFmt.format(expiry)}",
                  ),
                  if (bought != null)
                    _InfoRow(
                      Icons.event_available_rounded,
                      "Activé le",
                      "${_cap(dateFmt.format(bought))} à ${timeFmt.format(bought)}",
                    ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          FadeSlideIn(
            index: 2,
            child: _InfoCard(
              title: "Avec Premium",
              rows: const [
                _InfoRow(Icons.picture_as_pdf_rounded, "Documents", "Tous les cours et PDF Premium"),
                _InfoRow(Icons.play_circle_fill_rounded, "Vidéos", "Toutes les leçons Premium"),
                _InfoRow(Icons.bolt_rounded, "Accès immédiat", "Ouverture instantanée sans téléchargement"),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FadeSlideIn(
            index: 3,
            child: FilledButton.icon(
              onPressed: () => openExternalLink(context, AppConfig.whatsApp),
              icon: const Icon(Icons.workspace_premium_rounded),
              label: Text(premium ? "Prolonger mon abonnement" : "Passer Premium"),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);
}

class _InfoCard extends StatelessWidget {
  final String? title;
  final List<_InfoRow> rows;
  const _InfoCard({this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(
                title!,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 12),
            ],
            for (int i = 0; i < rows.length; i++) ...[
              if (i > 0) const Divider(height: 22),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconBadge(icon: rows[i].icon, size: 38),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rows[i].label,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          rows[i].value,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
