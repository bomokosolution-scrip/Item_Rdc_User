import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:item_rdc/core/app_theme.dart';
import 'package:item_rdc/core/auth_service.dart';
import 'package:item_rdc/widgets/ui.dart';

class SecurityPage extends StatelessWidget {
  const SecurityPage({super.key});

  void _showChangePassword(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ChangePasswordSheet(),
    );
  }

  Future<void> _sendReset(BuildContext context) async {
    final email = authService.currentUser?.email;
    if (email == null) return;
    try {
      await authService.sendPasswordReset(email: email);
      if (context.mounted) showToast(context, "E-mail de réinitialisation envoyé.");
    } catch (e) {
      if (context.mounted) showToast(context, authErrorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = authService.currentUser?.email ?? "Aucun e-mail";

    return Scaffold(
      appBar: AppBar(title: const Text("Sécurité")),
      body: Stack(
        children: [
          const BackdropImage(asset: 'assets/images/security_bg.png'),
          SafeArea(
            child: ResponsiveBody(
              maxWidth: 560,
              child: LayoutBuilder(
                builder: (context, c) {
                  // L'illustration s'adapte à la hauteur disponible.
                  final illustrationH = (c.maxHeight * 0.34).clamp(120.0, 300.0);
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                    child: Column(
                      children: [
                        FadeSlideIn(
                          child: SizedBox(
                            height: illustrationH,
                            child: Image.asset(
                              'assets/images/security_icon.png',
                              fit: BoxFit.contain,
                              cacheWidth: 900,
                              errorBuilder: (_, _, _) => const SizedBox.shrink(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        FadeSlideIn(
                          index: 1,
                          child: _SecurityAction(
                            icon: Icons.alternate_email_rounded,
                            title: "Adresse e-mail",
                            subtitle: email,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FadeSlideIn(
                          index: 2,
                          child: _SecurityAction(
                            icon: Icons.lock_reset_rounded,
                            title: "Changer le mot de passe",
                            subtitle: "Choisissez un nouveau mot de passe",
                            onTap: () => _showChangePassword(context),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FadeSlideIn(
                          index: 3,
                          child: _SecurityAction(
                            icon: Icons.mark_email_read_outlined,
                            title: "Réinitialiser par e-mail",
                            subtitle: "Recevoir un lien de réinitialisation",
                            onTap: () => _sendReset(context),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SecurityAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const _SecurityAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.authSheet,
      borderRadius: BorderRadius.circular(22),
      elevation: 3,
      shadowColor: Colors.black45,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(Icons.chevron_right_rounded, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_old.text.isEmpty) {
      { setState(() => _error = "Saisissez votre mot de passe actuel."); return; }
    }
    if (_new.text.length < 6) {
      { setState(() => _error = "Le nouveau mot de passe doit contenir au moins 6 caractères."); return; }
    }
    if (_new.text != _confirm.text) {
      { setState(() => _error = "La confirmation ne correspond pas."); return; }
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await authService.changePassword(
        oldPassword: _old.text,
        newPassword: _new.text,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text("Mot de passe modifié avec succès.")),
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.code == 'invalid-credential' || e.code == 'wrong-password'
              ? "Mot de passe actuel incorrect."
              : authErrorMessage(e);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = "Une erreur inattendue est survenue.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.authSheet,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(26, 14, 26, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white38,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      "Changer le mot de passe",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 22),
                    _field(_old, "Mot de passe actuel"),
                    const SizedBox(height: 12),
                    _field(_new, "Nouveau mot de passe"),
                    const SizedBox(height: 12),
                    _field(_confirm, "Confirmer le mot de passe", last: true),
                    if (_error != null)
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        disabledBackgroundColor: Colors.white54,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: AppColors.authRed,
                              ),
                            )
                          : const Text("Valider"),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _loading ? null : () => Navigator.of(context).pop(),
                      child: const Text("Annuler", style: TextStyle(color: Colors.white70)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, {bool last = false}) {
    return TextField(
      controller: c,
      obscureText: _obscure,
      textInputAction: last ? TextInputAction.done : TextInputAction.next,
      onSubmitted: last && !_loading ? (_) => _submit() : null,
      style: const TextStyle(color: Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        prefixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.grey, size: 20),
        suffixIcon: IconButton(
          icon: Icon(
            _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            color: Colors.grey,
            size: 20,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
