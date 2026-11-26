import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:item_rdc/core/app_theme.dart';
import 'package:item_rdc/core/auth_service.dart';
import 'package:item_rdc/widgets/app_dialog.dart';
import 'package:item_rdc/widgets/theme_toggle.dart';
import 'package:item_rdc/widgets/ui.dart';

/// Écran d'accueil non connecté : décor des assets + boutons Login / Sign up.
class AuthenticationPage extends StatelessWidget {
  const AuthenticationPage({super.key});

  void _openSheet(BuildContext context, bool login) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AuthSheet(initialLogin: login),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = AppColors.isDark(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final quit = await confirmExit(context);
        if (quit) SystemNavigator.pop();
      },
      child: Scaffold(
      body: Stack(
        children: [
          const BackdropImage(asset: 'assets/images/auth_bg.png'),
          const SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.only(top: 4, right: 6),
                child: ThemeToggleButton(),
              ),
            ),
          ),
          SafeArea(
            child: ResponsiveBody(
              maxWidth: 560,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    FadeSlideIn(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              'assets/images/app_icon.png',
                              width: 40,
                              height: 40,
                              cacheWidth: 120,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.school_rounded,
                                color: AppColors.authRed,
                                size: 32,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            "ITEM RDC",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              color: dark ? Colors.white : AppColors.authRed,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // L'illustration prend la place restante : aucun
                    // débordement sur les petits écrans.
                    Expanded(
                      child: FadeSlideIn(
                        index: 2,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Image.asset(
                            'assets/images/auth_bg2.png',
                            fit: BoxFit.contain,
                            width: double.infinity,
                            cacheWidth: 1000,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
                    FadeSlideIn(
                      index: 3,
                      child: Text(
                        "Bienvenue dans l'application\nqui définit votre avenir.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FadeSlideIn(
                      index: 4,
                      child: Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.authRed,
                                minimumSize: const Size(0, 52),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () => _openSheet(context, true),
                              child: const Text("Connexion"),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: dark ? Colors.white : Colors.black87,
                                backgroundColor: dark ? Colors.transparent : Colors.white,
                                side: const BorderSide(
                                  color: AppColors.authRed,
                                  width: 1.4,
                                ),
                                minimumSize: const Size(0, 52),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () => _openSheet(context, false),
                              child: const Text("Inscription"),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

/// Feuille de connexion / inscription (gère elle-même son état et se ferme
/// toute seule : plus de conflit de navigation avec l'écran principal).
class AuthSheet extends StatefulWidget {
  final bool initialLogin;
  const AuthSheet({super.key, required this.initialLogin});

  @override
  State<AuthSheet> createState() => _AuthSheetState();
}

class _AuthSheetState extends State<AuthSheet> {
  late bool _isLogin = widget.initialLogin;

  final _email = TextEditingController();
  final _password = TextEditingController();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _phone = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  String? _error;
  String? _info;

  static final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _fail(String message) => setState(() {
    _error = message;
    _info = null;
    _loading = false;
  });

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final email = _email.text.trim();
    final password = _password.text;

    if (!_emailRegex.hasMatch(email)) { _fail("Adresse e-mail invalide."); return; }
    if (password.length < 6) {
      { _fail("Le mot de passe doit contenir au moins 6 caractères."); return; }
    }

    final first = _first.text.trim();
    final last = _last.text.trim();
    final phone = _phone.text.trim();
    if (!_isLogin) {
      if (first.isEmpty || last.isEmpty) { _fail("Nom et prénom requis."); return; }
      if (phone.length < 8) { _fail("Numéro de téléphone valide requis."); return; }
    }

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });

    try {
      if (_isLogin) {
        await authService.signIn(email: email, password: password);
      } else {
        final cred = await authService.createAccount(
          email: email,
          password: password,
        );
        final user = cred.user;
        if (user != null) {
          await user.updateDisplayName("$first $last");
          await authService.createUserProfile(
            uid: user.uid,
            firstName: first,
            lastName: last,
            email: email,
            phone: phone,
          );
          // L'e-mail de vérification ne doit pas bloquer l'inscription.
          user.sendEmailVerification().catchError((_) {});
        }
      }
      // L'écran principal s'affiche tout seul (changement d'état d'auth) ;
      // on ferme seulement cette feuille.
      if (mounted) Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      if (mounted) _fail(authErrorMessage(e));
    } catch (_) {
      if (mounted) _fail("Une erreur inattendue est survenue.");
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (!_emailRegex.hasMatch(email)) {
      { _fail("Saisissez d'abord votre e-mail ci-dessus."); return; }
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await authService.sendPasswordReset(email: email);
      if (mounted) {
        setState(() {
          _loading = false;
          _info = "E-mail de réinitialisation envoyé à $email.";
        });
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) _fail(authErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.authSheet, AppColors.brandDarker],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(26, 14, 26, 22),
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 34,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.white38,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            const Align(
                              alignment: Alignment.centerRight,
                              child: ThemeToggleButton(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _isLogin
                            ? "Connectez-vous\nà votre succès"
                            : "Créez votre futur\nmaintenant",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 22),
                      if (!_isLogin) ...[
                        Row(
                          children: [
                            Expanded(
                              child: _field(
                                "Prénom",
                                _first,
                                Icons.person_outline_rounded,
                                action: TextInputAction.next,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _field(
                                "Nom",
                                _last,
                                Icons.person_outline_rounded,
                                action: TextInputAction.next,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      _field(
                        "E-mail",
                        _email,
                        Icons.mail_outline_rounded,
                        type: TextInputType.emailAddress,
                        action: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                      if (!_isLogin) ...[
                        _field(
                          "Téléphone",
                          _phone,
                          Icons.phone_outlined,
                          type: TextInputType.phone,
                          action: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),
                      ],
                      _field(
                        "Mot de passe",
                        _password,
                        Icons.lock_outline_rounded,
                        password: true,
                        action: TextInputAction.done,
                        onSubmit: _loading ? null : _submit,
                      ),
                      if (_isLogin)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _loading ? null : _forgotPassword,
                            child: const Text(
                              "Mot de passe oublié ?",
                              style: TextStyle(color: Colors.white70, fontSize: 12.5),
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: 8),
                      if (_error != null) _banner(_error!, error: true),
                      if (_info != null) _banner(_info!),
                      const SizedBox(height: 10),
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
                            : Text(_isLogin ? "SE CONNECTER" : "CRÉER MON COMPTE"),
                      ),
                      const SizedBox(height: 14),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: _loading
                            ? null
                            : () => setState(() {
                                _isLogin = !_isLogin;
                                _error = null;
                                _info = null;
                              }),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            _isLogin
                                ? "Pas encore de compte ? Inscrivez-vous"
                                : "Déjà un compte ? Connectez-vous",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white38,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _banner(String text, {bool error = false}) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: (error ? Colors.red : Colors.green).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (error ? Colors.redAccent : Colors.greenAccent).withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType? type,
    TextInputAction? action,
    bool password = false,
    VoidCallback? onSubmit,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 5),
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        TextField(
          controller: controller,
          obscureText: password && _obscure,
          keyboardType: type,
          textInputAction: action,
          autocorrect: !password && type != TextInputType.emailAddress,
          onSubmitted: onSubmit == null ? null : (_) => onSubmit(),
          style: const TextStyle(color: Colors.black87),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            prefixIcon: Icon(icon, color: Colors.grey, size: 20),
            suffixIcon: password
                ? IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: Colors.grey,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.brandSoft, width: 1.6),
            ),
          ),
        ),
      ],
    );
  }
}
