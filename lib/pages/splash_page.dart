import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

/// Couleurs du drapeau de la RDC.
class RdcColors {
  static const Color blue = Color(0xFF007FFF);
  static const Color yellow = Color(0xFFF7D618);
  static const Color red = Color(0xFFCE1126);
  static const Color deepBlue = Color(0xFF051446);
  static const Color midBlue = Color(0xFF0A2A78);
}

/// Écran de démarrage : drapeau de la RDC flottant (Lottie) sur un fond
/// aux couleurs bleu, jaune et rouge.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..forward();

  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    super.dispose();
  }

  Animation<double> _interval(double a, double b, [Curve c = Curves.easeOutCubic]) =>
      CurvedAnimation(parent: _intro, curve: Interval(a, b, curve: c));

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // Le drapeau s'adapte à la largeur ET à la hauteur de l'écran.
    final flagW = math.min(
      math.min(size.width * 0.9, 440.0),
      size.height * 0.40 * 600 / 520,
    );
    final flagAnim = _interval(0.0, 0.6, Curves.easeOutBack);
    final flagFade = _interval(0.0, 0.45, Curves.easeOut);
    final titleAnim = _interval(0.35, 0.8);
    final tagAnim = _interval(0.55, 1.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: RdcColors.deepBlue,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Fond dégradé bleu profond
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF040E38), RdcColors.midBlue, Color(0xFF061A55)],
                ),
              ),
            ),
            // Halos jaune (haut-droite) et rouge (bas-gauche) qui respirent
            RepaintBoundary(
              child: AnimatedBuilder(
              animation: _loop,
              builder: (context, _) {
                final t = math.sin(_loop.value * 2 * math.pi);
                return Stack(
                  children: [
                    Positioned(
                      right: -size.width * 0.35,
                      top: -size.width * 0.30,
                      child: _glow(size.width * 1.0, RdcColors.yellow, 0.16 + 0.05 * t),
                    ),
                    Positioned(
                      left: -size.width * 0.4,
                      bottom: -size.width * 0.35,
                      child: _glow(size.width * 1.1, RdcColors.red, 0.26 - 0.06 * t),
                    ),
                    Positioned(
                      left: size.width * 0.1,
                      top: size.height * 0.18,
                      child: _glow(size.width * 0.7, RdcColors.blue, 0.18),
                    ),
                  ],
                );
              },
            ),
            ),
            // Contenu
            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  FadeTransition(
                    opacity: flagFade,
                    child: ScaleTransition(
                      scale: flagAnim.drive(Tween(begin: 0.7, end: 1.0)),
                      child: SizedBox(
                        width: flagW,
                        child: AspectRatio(
                          aspectRatio: 600 / 520,
                          child: RepaintBoundary(child: Lottie.asset(
                            'assets/lottie/drc_flag.json',
                            fit: BoxFit.contain,
                            repeat: true,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.flag_rounded,
                              color: RdcColors.yellow,
                              size: 120,
                            ),
                          )),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  FadeTransition(
                    opacity: titleAnim,
                    child: SlideTransition(
                      position: titleAnim.drive(
                        Tween(begin: const Offset(0, 0.4), end: Offset.zero),
                      ),
                      child: const Text(
                        "ITEM RDC",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 7,
                          shadows: [Shadow(color: Colors.black45, blurRadius: 14, offset: Offset(0, 4))],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Trait tricolore
                  FadeTransition(
                    opacity: titleAnim,
                    child: SizedBox(
                      width: 150,
                      height: 5,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: const Row(
                          children: [
                            Expanded(child: ColoredBox(color: RdcColors.blue)),
                            Expanded(child: ColoredBox(color: RdcColors.yellow)),
                            Expanded(child: ColoredBox(color: RdcColors.red)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FadeTransition(
                    opacity: tagAnim,
                    child: const Text(
                      "Tout ce dont vous avez besoin.",
                      style: TextStyle(
                        color: RdcColors.yellow,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const Spacer(flex: 3),
                  // Barre de chargement tricolore
                  Padding(
                    padding: const EdgeInsets.fromLTRB(56, 0, 56, 38),
                    child: _TricolorLoader(animation: _loop),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glow(double d, Color c, double alpha) {
    return Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [c.withValues(alpha: alpha), c.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

/// Barre de chargement : un reflet tricolore qui glisse en boucle.
class _TricolorLoader extends StatelessWidget {
  final Animation<double> animation;
  const _TricolorLoader({required this.animation});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        return Container(
          height: 5,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(5),
          ),
          clipBehavior: Clip.antiAlias,
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              // 3 allers-retours par cycle de 6 s => ~2 s par passage
              final v = (animation.value * 3) % 1.0;
              final seg = w * 0.38;
              return Stack(
                children: [
                  Positioned(
                    left: -seg + (w + seg) * Curves.easeInOut.transform(v),
                    width: seg,
                    top: 0,
                    bottom: 0,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [RdcColors.blue, RdcColors.yellow, RdcColors.red],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
