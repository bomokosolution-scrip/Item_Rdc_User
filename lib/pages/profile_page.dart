import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:item_rdc/core/app_theme.dart';
import 'package:item_rdc/core/auth_service.dart';
import 'package:item_rdc/core/user_session.dart';
import 'package:item_rdc/widgets/ui.dart';
import 'package:item_rdc/widgets/user_avatar.dart';
import 'package:provider/provider.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _phone = TextEditingController();
  bool _saving = false;
  bool _filled = false;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    super.dispose();
  }

  /// Remplit les champs une seule fois (les mises à jour en direct
  /// n'écrasent plus ce que l'utilisateur est en train de saisir).
  void _fillOnce(UserSession s) {
    if (_filled || !s.docLoaded) return;
    _filled = true;
    _first.text = s.firstName;
    _last.text = s.lastName;
    _phone.text = s.phone;
  }

  Future<void> _pickImage() async {
    final session = context.read<UserSession>();
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 360,
        maxHeight: 360,
        imageQuality: 70,
      );
      if (file == null) return;
      await session.setLocalImage(await file.readAsBytes());
    } catch (_) {
      if (mounted) showToast(context, "Impossible de charger l'image.", error: true);
    }
  }

  Future<void> _save() async {
    final uid = context.read<UserSession>().uid;
    if (uid.isEmpty) return;

    final first = _first.text.trim();
    final last = _last.text.trim();
    if (first.isEmpty || last.isEmpty) {
      showToast(context, "Nom et prénom requis.", error: true);
      return;
    }

    setState(() => _saving = true);
    try {
      await authService.updateProfile(
        uid: uid,
        firstName: first,
        lastName: last,
        phone: _phone.text.trim(),
      );
      await authService.updateDisplayName("$first $last");
      if (mounted) showToast(context, "Profil mis à jour avec succès.");
    } catch (_) {
      if (mounted) showToast(context, "Échec de la mise à jour.", error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<UserSession>();
    _fillOnce(session);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Profil")),
      body: Stack(
        children: [
          const BackdropImage(
            asset: 'assets/images/profile_bg.png',
            alignment: Alignment.bottomCenter,
          ),
          SafeArea(
            child: ResponsiveBody(
              maxWidth: 560,
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                child: Column(
                  children: [
                    FadeSlideIn(
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: AppColors.headerGradient(context),
                              ),
                            ),
                            child: const UserAvatar(radius: 54),
                          ),
                          Material(
                            color: AppColors.authRed,
                            shape: const CircleBorder(
                              side: BorderSide(color: Colors.white, width: 2),
                            ),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _pickImage,
                              child: const Padding(
                                padding: EdgeInsets.all(9),
                                child: Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(child: PlanBadgeThemed(premium: session.isPremium)),
                    const SizedBox(height: 26),
                    FadeSlideIn(
                      index: 1,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: AppTextField(
                                      controller: _first,
                                      label: "Prénom",
                                      icon: Icons.person_outline_rounded,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: AppTextField(
                                      controller: _last,
                                      label: "Nom",
                                      icon: Icons.person_outline_rounded,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              AppTextField(
                                controller: _phone,
                                label: "Téléphone",
                                icon: Icons.phone_outlined,
                                keyboardType: TextInputType.phone,
                              ),
                              const SizedBox(height: 14),
                              _ReadOnlyRow(
                                icon: Icons.mail_outline_rounded,
                                label: "E-mail",
                                value: session.email,
                              ),
                              const SizedBox(height: 10),
                              _ReadOnlyRow(
                                icon: Icons.fingerprint_rounded,
                                label: "Identifiant (UID) — appuyez pour copier",
                                value: session.uid,
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: session.uid));
                                  showToast(context, "UID copié");
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    FadeSlideIn(
                      index: 2,
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.brightness == Brightness.dark
                                ? AppColors.brandDark
                                : AppColors.brand,
                          ),
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_rounded),
                          label: Text(_saving ? "Enregistrement…" : "Enregistrer"),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscure;
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
      ),
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  const _ReadOnlyRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            IconBadge(icon: icon, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 11.5, color: theme.textTheme.bodyMedium?.color),
                  ),
                  Text(
                    value.isEmpty ? "—" : value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.copy_rounded, size: 18, color: theme.textTheme.bodyMedium?.color),
          ],
        ),
      ),
    );
  }
}

/// Badge de statut lisible sur fond clair comme sombre.
class PlanBadgeThemed extends StatelessWidget {
  final bool premium;
  const PlanBadgeThemed({super.key, required this.premium});

  @override
  Widget build(BuildContext context) {
    final color = premium ? const Color(0xFFB8860B) : Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    return InfoPill(
      premium ? "COMPTE PREMIUM" : "COMPTE GRATUIT",
      color: color,
      icon: premium ? Icons.workspace_premium_rounded : Icons.person_outline,
    );
  }
}
