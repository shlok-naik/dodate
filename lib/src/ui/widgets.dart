import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/scheduler.dart';
import 'theme.dart';

/// Animation length, or zero when the system asks for reduced motion.
Duration motion(BuildContext context, int ms) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : Duration(milliseconds: ms);

const springOut = Curves.easeOutBack;
const smooth = Curves.easeOutCubic;

/// Shrinks a little while pressed, like the design's buttons.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.scale = 0.96, this.label, this.selected});

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final String? label;
  final bool? selected;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap != null && v != _down) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      label: widget.label,
      selected: widget.selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? widget.scale : 1,
          duration: motion(context, 120),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Text that rolls up when its value changes.
class RollText extends StatelessWidget {
  const RollText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedSwitcher(
        duration: motion(context, 260),
        switchInCurve: smooth,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, a) {
          final incoming = child.key == ValueKey(text);
          final slide = Tween(begin: Offset(0, incoming ? 0.8 : -0.8), end: Offset.zero).animate(a);
          return FadeTransition(opacity: a, child: SlideTransition(position: slide, child: child));
        },
        layoutBuilder: (current, previous) => Stack(alignment: Alignment.centerLeft, children: [...previous, if (current != null) current]),
        child: Text(text, key: ValueKey(text), style: style),
      ),
    );
  }
}

/// Circular progress that eases to its new value.
class ProgressRing extends StatelessWidget {
  const ProgressRing({super.key, required this.value, this.size = 40, this.stroke = 4, this.color, this.child, this.label});

  final double value;
  final double size;
  final double stroke;
  final Color? color;
  final Widget? child;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: label,
      child: SizedBox(
        width: size,
        height: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value.clamp(0, 1).toDouble()),
          duration: motion(context, 700),
          curve: smooth,
          builder: (context, v, _) => CustomPaint(
            painter: _RingPainter(v, stroke, c.surfaceAlt, color ?? c.accent),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v, this.stroke, this.track, this.color);
  final double v, stroke;
  final Color track, color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(r, 0, math.pi * 2, false, p..color = track);
    if (v > 0) canvas.drawArc(r, -math.pi / 2, math.pi * 2 * v, false, p..color = color..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.v != v || o.color != color || o.track != track;
}

/// Round checkbox: the fill grows, the tick draws itself and a ring pops out.
class CheckDot extends StatelessWidget {
  const CheckDot({super.key, required this.done, required this.color, this.size = 26});

  final bool done;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: done ? 1 : 0),
      duration: motion(context, done ? 520 : 220),
      curve: Curves.linear,
      builder: (context, t, _) => CustomPaint(
        size: Size.square(size),
        painter: _CheckPainter(t, done, color, c.accent, c.onAccent),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.t, this.done, this.ring, this.accent, this.tick);
  final double t;
  final bool done;
  final Color ring, accent, tick;

  @override
  void paint(Canvas canvas, Size size) {
    final ctr = size.center(Offset.zero);
    final r = size.width / 2;
    // Fill grows with a little overshoot, then the tick draws, then a ring fades out.
    final fill = done ? Curves.easeOutBack.transform((t / 0.45).clamp(0, 1)) : t;
    final draw = done ? ((t - 0.25) / 0.4).clamp(0.0, 1.0) : t;
    canvas.drawCircle(ctr, r - 1, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Color.lerp(ring, accent, t.clamp(0, 1))!);
    if (fill > 0) canvas.drawCircle(ctr, r * fill.clamp(0, 1.1), Paint()..color = accent);
    if (draw > 0) {
      final s = size.width / 24;
      final path = Path()
        ..moveTo(7 * s, 12.5 * s)
        ..lineTo(10.6 * s, 16 * s)
        ..lineTo(17.4 * s, 8.5 * s);
      final m = path.computeMetrics().first;
      canvas.drawPath(m.extractPath(0, m.length * draw), Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * s
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = tick);
    }
    if (done && t > 0.2 && t < 1) {
      final b = (t - 0.2) / 0.8;
      canvas.drawCircle(ctr, r * (1 + b * 0.9), Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = accent.withValues(alpha: 0.5 * (1 - b)));
    }
  }

  @override
  bool shouldRepaint(_CheckPainter o) => o.t != t || o.done != done || o.ring != ring;
}

/// A row of options; the selected fill slides between them.
class SlidingChips<T> extends StatelessWidget {
  const SlidingChips({
    super.key,
    required this.options,
    required this.value,
    required this.onPick,
    this.height = 48,
    this.gap = 8,
    this.keyPrefix,
  });

  final List<(T, Widget, String)> options; // value, content, semantic label
  final T? value;
  final ValueChanged<T> onPick;
  final double height;
  final double gap;
  final String? keyPrefix;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final idx = options.indexWhere((o) => o.$1 == value);
    final radius = height >= 64 ? 16.0 : height / 2;
    return LayoutBuilder(builder: (context, box) {
      final n = options.length;
      final w = (box.maxWidth - gap * (n - 1)) / n;
      return SizedBox(
        height: height,
        child: Stack(children: [
          for (var i = 0; i < n; i++)
            Positioned(
              left: i * (w + gap),
              width: w,
              top: 0,
              bottom: 0,
              child: DecoratedBox(decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(radius))),
            ),
          if (idx >= 0)
            AnimatedPositioned(
              duration: motion(context, 320),
              curve: Curves.easeOutBack,
              left: idx * (w + gap),
              width: w,
              top: 0,
              bottom: 0,
              child: DecoratedBox(decoration: BoxDecoration(color: c.chipOn, borderRadius: BorderRadius.circular(radius))),
            ),
          for (var i = 0; i < n; i++)
            Positioned(
              left: i * (w + gap),
              width: w,
              top: 0,
              bottom: 0,
              child: Pressable(
                key: keyPrefix == null ? null : Key('$keyPrefix-${options[i].$1}'),
                label: options[i].$3,
                selected: i == idx,
                scale: 0.92,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onPick(options[i].$1);
                },
                child: Center(
                  child: AnimatedDefaultTextStyle(
                    duration: motion(context, 200),
                    style: TextStyle(
                      fontFamily: bodyFont,
                      fontSize: 16,
                      height: 1.5,
                      fontWeight: FontWeight.w700,
                      color: i == idx ? c.chipOnInk : c.ink,
                    ),
                    child: ExcludeSemantics(child: options[i].$2),
                  ),
                ),
              ),
            ),
        ]),
      );
    });
  }
}

/// Filled pill button from the design: primary (accent), ink or soft.
enum PillKind { primary, ink, soft }

class PillButton extends StatelessWidget {
  const PillButton({super.key, required this.label, required this.onTap, this.kind = PillKind.primary, this.height = 56});

  final String label;
  final VoidCallback? onTap;
  final PillKind kind;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (bg, fg) = switch (kind) {
      PillKind.primary => (c.accent, c.onAccent),
      PillKind.ink => (c.ink, c.bg),
      PillKind.soft => (c.surfaceAlt, c.ink),
    };
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: motion(context, 220),
        height: height,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(height / 2),
          boxShadow: kind == PillKind.primary ? [BoxShadow(color: c.accentShadow, blurRadius: 24, offset: const Offset(0, 8))] : null,
        ),
        child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: fg)),
      ),
    );
  }
}

/// Assignment colour as a small dot.
class TintDot extends StatelessWidget {
  const TintDot({super.key, required this.color, this.size = 8});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) =>
      Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

/// Amber card for "needs more time"; muted red only for truly overdue work.
class WarningCard extends StatelessWidget {
  const WarningCard({super.key, required this.warning, this.action});

  final PlanWarning warning;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final overdue = warning.type == WarningType.overdue;
    final fg = overdue ? c.danger : c.warnInk;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(color: overdue ? c.dangerBg : c.warnBg, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: '${warning.headline}. ', style: const TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(text: warning.message),
              ]),
              style: TextStyle(fontSize: 14, height: 20 / 14, color: fg),
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// Small uppercase section label.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 32,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(text.toUpperCase(), style: Styles.kicker(context.colors.muted)),
        ),
      );
}

/// Fades and slides children in, one after another, when first shown.
class Stagger extends StatelessWidget {
  const Stagger({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final d = motion(context, 380 + 40 * math.min(index, 8));
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: d,
      curve: Interval(d == Duration.zero ? 0 : math.min(index, 8) * 40 / d.inMilliseconds, 1, curve: smooth),
      builder: (context, t, child) =>
          Opacity(opacity: t, child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: child)),
      child: child,
    );
  }
}

/// One burst of confetti over everything; remove it when [onDone] fires.
class Confetti extends StatefulWidget {
  const Confetti({super.key, this.onDone, this.count = 80});

  final VoidCallback? onDone;
  final int count;

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _Piece {
  _Piece(math.Random r, this.color)
      : x = r.nextDouble(),
        drift = (r.nextDouble() - 0.5) * 160,
        spin = (r.nextDouble() * 4 - 2) * math.pi,
        delay = r.nextDouble() * 0.12,
        speed = 0.6 + r.nextDouble() * 0.4,
        w = 6 + r.nextDouble() * 6,
        h = 4 + r.nextDouble() * 8,
        round = r.nextDouble() > 0.7;
  final double x, drift, spin, delay, speed, w, h;
  final bool round;
  final Color color;
}

class _ConfettiState extends State<Confetti> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  List<_Piece> _pieces = const [];

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone?.call();
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pieces.isEmpty) {
      final c = context.colors;
      final colors = [...c.tints.map((t) => t.fg), c.accent, c.warnBar];
      final r = math.Random();
      _pieces = [for (var i = 0; i < widget.count; i++) _Piece(r, colors[i % colors.length])];
      if (MediaQuery.disableAnimationsOf(context)) {
        WidgetsBinding.instance.addPostFrameCallback((_) => widget.onDone?.call());
      } else {
        _c.forward();
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => CustomPaint(size: Size.infinite, painter: _ConfettiPainter(_pieces, _c.value)),
          ),
        ),
      );
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);
  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final local = ((t - p.delay) / (1 - p.delay) * (1 / p.speed)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final fall = Curves.easeOutQuad.transform(local);
      final dx = p.x * size.width + p.drift * fall;
      final dy = -20 + (size.height + 40) * fall;
      final paint = Paint()..color = p.color.withValues(alpha: local > 0.8 ? (1 - local) / 0.2 : 1);
      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(p.spin * local);
      if (p.round) {
        canvas.drawCircle(Offset.zero, p.w / 2, paint);
      } else {
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: p.w, height: p.h), const Radius.circular(2)), paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter o) => o.t != t;
}
