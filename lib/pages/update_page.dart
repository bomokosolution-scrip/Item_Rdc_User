import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:item_rdc/core/app_theme.dart';
import 'package:item_rdc/core/update_service.dart';
import 'package:item_rdc/widgets/app_dialog.dart';
import 'package:item_rdc/widgets/ui.dart';

enum _Phase { info, downloading, ready, error }

/// Page de mise à jour : téléchargement DANS l'application, puis choix entre
/// installer directement ou désinstaller d'abord. Si [mandatory] est vrai,
/// l'utilisateur ne peut pas continuer sans mettre à jour.
class UpdatePage extends StatefulWidget {
  final UpdateInfo info;
  final bool mandatory;
  const UpdatePage({super.key, required this.info, required this.mandatory});

  @override
  State<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends State<UpdatePage> with WidgetsBindingObserver {
  _Phase _phase = _Phase.info;
  int _received = 0;
  int _total = -1;
  DateTime _lastPaint = DateTime.fromMillisecondsSinceEpoch(0);
  String _error = '';
  File? _apk;
  InstalledApp? _installed;
  bool _awaitingPermission = false;
  bool _busy = false;

  /// Famille d'Android choisie : true = Android 7 et moins, false = Android 8+.
  /// Pré-sélectionnée selon le téléphone, modifiable par l'utilisateur.
  bool? _legacy;

  bool get _legacyChoice =>
      _legacy ?? UpdateInfo.isLegacySdk(_installed?.sdkInt ?? 0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NativeUpdater.appInfo().then((v) {
      if (mounted) {
        setState(() {
          _installed = v;
          _legacy ??= UpdateInfo.isLegacySdk(v.sdkInt);
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Au retour des réglages « sources inconnues », on relance l'installation.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed && _awaitingPermission) {
      _awaitingPermission = false;
      if (await NativeUpdater.canInstall()) _install();
    }
  }

  double? get _progress => _total > 0 ? (_received / _total).clamp(0.0, 1.0) : null;

  String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

  Future<void> _download() async {
    setState(() {
      _phase = _Phase.downloading;
      _received = 0;
      _total = -1;
      _error = '';
    });
    try {
      final file = await UpdateService.download(
        widget.info,
        onProgress: (received, total) {
          // Limite les redessins (≈ 10 par seconde).
          final now = DateTime.now();
          final done = total > 0 && received >= total;
          if (!done && now.difference(_lastPaint).inMilliseconds < 100) return;
          _lastPaint = now;
          if (mounted) {
            setState(() {
              _received = received;
              _total = total;
            });
          }
        },
        isCancelled: () => !mounted,
        url: widget.info.urlFor(legacy: _legacyChoice),
        variant: widget.info.hasChoice ? (_legacyChoice ? '_android7' : '_android8plus') : '',
      );
      if (!mounted) return;
      setState(() {
        _apk = file;
        _phase = _Phase.ready; // 100 %
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is HttpException
            ? e.message
            : e is SocketException
            ? "Pas de connexion internet. Vérifiez votre réseau."
            : "Le téléchargement a échoué. Réessayez.";
        _phase = _Phase.error;
      });
    }
  }

  Future<void> _install() async {
    final apk = _apk;
    if (apk == null || _busy) return;
    setState(() => _busy = true);
    try {
      if (!await NativeUpdater.canInstall()) {
        if (!mounted) return;
        final go = await showAppConfirm(
          context,
          icon: Icons.security_rounded,
          title: "Autorisation requise",
          message:
              "Pour installer la mise à jour, autorisez Item RDC à installer des applications dans les réglages qui vont s'ouvrir, puis revenez ici.",
          confirmLabel: "Ouvrir les réglages",
          cancelLabel: "Annuler",
        );
        if (go) {
          _awaitingPermission = true;
          await NativeUpdater.openInstallSettings();
        }
        return;
      }
      await NativeUpdater.installApk(apk.path);
    } catch (e) {
      final detail = e is PlatformException ? (e.message ?? '') : '';
      if (mounted) {
        showToast(
          context,
          detail.isEmpty
              ? "Impossible de lancer l'installation."
              : "Impossible de lancer l'installation : $detail",
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uninstallFirst() async {
    final apk = _apk;
    if (apk == null || _busy) return;
    final ok = await showAppConfirm(
      context,
      icon: Icons.delete_sweep_rounded,
      title: "Désinstaller d'abord ?",
      message:
          "1. La nouvelle version est enregistrée dans « Téléchargements ».\n2. La version actuelle est désinstallée.\n3. Ouvrez l'application « Fichiers » (ou « Téléchargements »), touchez le fichier Item_RDC_${widget.info.versionName}.apk, puis « Installer ».\n\nVos données de compte restent sur nos serveurs.",
      confirmLabel: "Continuer",
      cancelLabel: "Retour",
      destructive: true,
    );
    if (!ok) return;

    setState(() => _busy = true);
    try {
      final name = 'Item_RDC_${widget.info.versionName}.apk';
      final where = await NativeUpdater.saveToDownloads(apk.path, name);
      if (!mounted) return;
      showToast(context, "Enregistré : $where");
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await NativeUpdater.uninstall();
    } catch (_) {
      if (mounted) {
        showToast(
          context,
          "Enregistrement impossible. Utilisez « Installer directement ».",
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = widget.info;

    return PopScope(
      canPop: !widget.mandatory,
      onPopInvokedWithResult: (didPop, _) async {
        // Mise à jour obligatoire : retour = proposer de quitter l'application.
        if (!didPop && widget.mandatory) {
          final quit = await confirmExit(context);
          if (quit) SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: ResponsiveBody(
            maxWidth: 520,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
              child: Column(
                children: [
                  FadeSlideIn(
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: AppColors.headerGradient(context)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Icon(
                        _phase == _Phase.ready
                            ? Icons.check_rounded
                            : _phase == _Phase.error
                            ? Icons.error_outline_rounded
                            : Icons.system_update_rounded,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    widget.mandatory ? "Mise à jour obligatoire" : "Mise à jour disponible",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: [
                      InfoPill("Actuelle ${_installed?.versionName ?? '…'}"),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                      InfoPill("Nouvelle ${info.versionName}", color: const Color(0xFF2E9E5B)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    widget.mandatory
                        ? "Pour continuer à utiliser Item RDC, installez la dernière version."
                        : "Une nouvelle version d'Item RDC est disponible.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                  if (info.message.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.cardTheme.color,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.accent(context).withValues(alpha: 0.25)),
                      ),
                      child: Text(
                        info.message,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 26),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _buildPhase(context),
                  ),
                  if (!widget.mandatory && _phase != _Phase.downloading) ...[
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: const Text("Plus tard"),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhase(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppColors.accent(context);

    switch (_phase) {
      case _Phase.info:
        return Column(
          key: const ValueKey('info'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.info.hasChoice) ...[
              Text(
                (_installed?.sdkInt ?? 0) > 0
                    ? "Votre téléphone : Android ${_installed!.release.isEmpty ? _installed!.sdkInt : _installed!.release}"
                    : "Choisissez la version adaptée à votre téléphone",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text("Android 7 et moins"),
                    selected: _legacyChoice,
                    onSelected: (_) => setState(() => _legacy = true),
                  ),
                  ChoiceChip(
                    label: const Text("Android 8 et plus"),
                    selected: !_legacyChoice,
                    onSelected: (_) => setState(() => _legacy = false),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],
            FilledButton.icon(
              onPressed: _download,
              icon: const Icon(Icons.download_rounded),
              label: const Text("Télécharger la mise à jour"),
            ),
          ],
        );

      case _Phase.downloading:
        final p = _progress;
        return Column(
          key: const ValueKey('downloading'),
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: p,
                      strokeWidth: 9,
                      strokeCap: StrokeCap.round,
                      backgroundColor: accent.withValues(alpha: 0.15),
                    ),
                  ),
                  Text(
                    p == null ? "…" : "${(p * 100).floor()}%",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _total > 0
                  ? "${_mb(_received)} Mo / ${_mb(_total)} Mo"
                  : "${_mb(_received)} Mo téléchargés",
              style: TextStyle(color: theme.textTheme.bodyMedium?.color),
            ),
            const SizedBox(height: 4),
            Text(
              "Ne fermez pas l'application…",
              style: TextStyle(fontSize: 12.5, color: theme.textTheme.bodyMedium?.color),
            ),
          ],
        );

      case _Phase.ready:
        return Column(
          key: const ValueKey('ready'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF2E9E5B)),
                const SizedBox(width: 8),
                Text(
                  "Téléchargement terminé (100 %)",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _OptionCard(
              icon: Icons.system_update_alt_rounded,
              title: "Installer directement",
              subtitle: "Recommandé • Met à jour en conservant vos données",
              primary: true,
              busy: _busy,
              onTap: _install,
            ),
            const SizedBox(height: 12),
            _OptionCard(
              icon: Icons.delete_sweep_rounded,
              title: "Désinstaller d'abord",
              subtitle: "Désinstalle la version actuelle, puis installez le fichier enregistré dans Téléchargements",
              primary: false,
              busy: _busy,
              onTap: _uninstallFirst,
            ),
          ],
        );

      case _Phase.error:
        return Column(
          key: const ValueKey('error'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                _error,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _download,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text("Réessayer"),
            ),
          ],
        );
    }
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool primary;
  final bool busy;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primary,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = AppColors.isDark(context);
    final bg = primary ? (dark ? AppColors.brandDark : AppColors.brand) : theme.cardTheme.color;
    final fg = primary ? Colors.white : theme.textTheme.bodyLarge?.color;
    final sub = primary ? Colors.white70 : theme.textTheme.bodyMedium?.color;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      elevation: primary ? 4 : 0,
      shadowColor: Colors.black45,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: busy ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: primary
              ? null
              : BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.accent(context).withValues(alpha: 0.35)),
                ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: (primary ? Colors.white : AppColors.accent(context)).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: busy
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
                      )
                    : Icon(icon, color: primary ? Colors.white : AppColors.accent(context)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: fg),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 12.5, height: 1.3, color: sub)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: sub),
            ],
          ),
        ),
      ),
    );
  }
}
