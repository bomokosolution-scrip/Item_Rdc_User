import 'package:flutter/material.dart';
import 'package:item_rdc/core/app_theme.dart';
import 'package:item_rdc/core/user_session.dart';
import 'package:provider/provider.dart';

/// Photo de profil (locale > URL > initiales).
class UserAvatar extends StatelessWidget {
  final double radius;
  const UserAvatar({super.key, this.radius = 30});

  @override
  Widget build(BuildContext context) {
    final bytes = context.select<UserSession, dynamic>((s) => s.localImage);
    final url = context.select<UserSession, String>((s) => s.profileImageUrl);
    final name = context.select<UserSession, String>((s) => s.fullName);

    ImageProvider? image;
    if (bytes != null) {
      image = MemoryImage(bytes);
    } else if (url.isNotEmpty) {
      image = ResizeImage(
        NetworkImage(url),
        width: (radius * 2 * MediaQuery.of(context).devicePixelRatio).round(),
      );
    }

    final initial = name.isNotEmpty ? name[0].toUpperCase() : null;

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white.withValues(alpha: 0.2),
      backgroundImage: image,
      onBackgroundImageError: image == null ? null : (_, _) {},
      child: image != null
          ? null
          : initial != null
          ? Text(
              initial,
              style: TextStyle(
                color: Colors.white,
                fontSize: radius * 0.9,
                fontWeight: FontWeight.w700,
              ),
            )
          : Icon(Icons.person_rounded, color: Colors.white, size: radius),
    );
  }
}

/// Pastille de statut du compte.
class PlanBadge extends StatelessWidget {
  final bool premium;
  const PlanBadge({super.key, required this.premium});

  @override
  Widget build(BuildContext context) {
    final c = premium ? AppColors.gold : Colors.white70;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            premium ? Icons.workspace_premium_rounded : Icons.person_outline,
            size: 14,
            color: c,
          ),
          const SizedBox(width: 5),
          Text(
            premium ? "PREMIUM" : "GRATUIT",
            style: TextStyle(
              color: c,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
