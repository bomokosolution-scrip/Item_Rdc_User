import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Décomposition d'une durée : jours, heures, minutes, secondes, tierces.
/// 1 tierce = 1/60 de seconde (0 à 59).
class TimeParts {
  final int days, hours, minutes, seconds, tierces;
  const TimeParts(this.days, this.hours, this.minutes, this.seconds, this.tierces);

  factory TimeParts.from(Duration d) {
    if (d.isNegative) return const TimeParts(0, 0, 0, 0, 0);
    final micros = d.inMicroseconds % 1000000;
    return TimeParts(
      d.inDays,
      d.inHours % 24,
      d.inMinutes % 60,
      d.inSeconds % 60,
      (micros * 60) ~/ 1000000,
    );
  }

  static String two(int v) => v.toString().padLeft(2, '0');
}

/// Compte à rebours Premium, mis à jour à chaque image (≈ 60 fois / s)
/// pour afficher les tierces. Seul ce petit widget est reconstruit.
class PremiumCountdown extends StatefulWidget {
  final DateTime expiry;

  /// `true` : une seule ligne compacte (menu latéral).
  final bool compact;
  final Color? color;

  const PremiumCountdown({
    super.key,
    required this.expiry,
    this.compact = false,
    this.color,
  });

  @override
  State<PremiumCountdown> createState() => _PremiumCountdownState();
}

class _PremiumCountdownState extends State<PremiumCountdown>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<TimeParts> _parts = ValueNotifier(
    const TimeParts(0, 0, 0, 0, 0),
  );

  @override
  void initState() {
    super.initState();
    _update();
    _ticker = createTicker((_) => _update())..start();
  }

  void _update() {
    _parts.value = TimeParts.from(widget.expiry.difference(DateTime.now()));
  }

  @override
  void didUpdateWidget(covariant PremiumCountdown old) {
    super.didUpdateWidget(old);
    if (old.expiry != widget.expiry) _update();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _parts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ValueListenableBuilder<TimeParts>(
        valueListenable: _parts,
        builder: (context, p, _) =>
            widget.compact ? _compact(p) : _boxes(context, p),
      ),
    );
  }

  Widget _compact(TimeParts p) {
    return Text(
      "${p.days} j ${TimeParts.two(p.hours)} h ${TimeParts.two(p.minutes)} min "
      "${TimeParts.two(p.seconds)} s ${TimeParts.two(p.tierces)} t",
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: widget.color ?? Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }

  Widget _boxes(BuildContext context, TimeParts p) {
    final items = <(String, String)>[
      (p.days.toString().padLeft(2, '0'), "Jours"),
      (TimeParts.two(p.hours), "Heures"),
      (TimeParts.two(p.minutes), "Minutes"),
      (TimeParts.two(p.seconds), "Secondes"),
      (TimeParts.two(p.tierces), "Tierces"),
    ];
    return Row(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(child: _TimeBox(value: items[i].$1, label: items[i].$2)),
        ],
      ],
    );
  }
}

class _TimeBox extends StatelessWidget {
  final String value;
  final String label;
  const _TimeBox({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 10.5),
            ),
          ),
        ],
      ),
    );
  }
}
