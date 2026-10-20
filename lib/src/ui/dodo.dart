import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum DodoMood { sleep, chill, party, write, sweat }

const _labels = {
  DodoMood.sleep: 'A dodo asleep in a nightcap',
  DodoMood.chill: 'A dodo in sunglasses under the sun',
  DodoMood.party: 'A dodo in a party hat, cheering',
  DodoMood.write: 'A dodo holding a pencil',
  DodoMood.sweat: 'A worried dodo, sweating',
};

// The mascot is drawn in a 160×160 box, one SVG layer per moving part.
String _svg(String body) => '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 160 160">$body</svg>';

final _shadow = _svg('<ellipse cx="80" cy="148" rx="44" ry="5" fill="#121614" opacity="0.07"/>');
final _legs = _svg('<path d="M68 128v14M92 128v14M62 142h10M86 142h10" stroke="#E0A93F" stroke-width="5" stroke-linecap="round" fill="none"/>');
final _tail = _svg('<path d="M36 92c-10-6-14-16-10-22 6 2 9 8 10 12 0-8 4-14 10-15 2 7-1 14-4 18" fill="#F3EEE4"/>');
final _body = _svg('<ellipse cx="80" cy="100" rx="48" ry="38" fill="#8FA8B8"/><ellipse cx="90" cy="110" rx="27" ry="22" fill="#D3DEE5"/>');
final _wing = _svg('<ellipse cx="62" cy="102" rx="19" ry="13" fill="#7892A4" transform="rotate(-18 62 102)"/>');
final _arm = _svg('<path d="M40 92c-8-10-10-20-6-28" stroke="#7892A4" stroke-width="10" stroke-linecap="round" fill="none"/>');
final _head = _svg('<circle cx="106" cy="58" r="24" fill="#8FA8B8"/>'
    '<path d="M100 76c4 8 6 14 6 22" stroke="#8FA8B8" stroke-width="18" stroke-linecap="round" fill="none"/>'
    '<path d="M121 50c14-2 27 4 31 14 2 6-1 12-7 12-2-5-6-7-11-7l-14 2c-4-6-4-15 1-21z" fill="#F2B33D"/>'
    '<path d="M145 76c-2-5-6-7-11-7" stroke="#C98516" stroke-width="3" stroke-linecap="round" fill="none"/>'
    '<circle cx="101" cy="67" r="4.5" fill="#F09AB4" opacity="0.7"/>');
final _eye = _svg('<circle cx="111" cy="52" r="4.5" fill="#121614"/><circle cx="112.6" cy="50.4" r="1.6" fill="#FFFFFF"/>');
final _sleepFace = _svg('<path d="M106 53c2 3 7 3 9 0" stroke="#121614" stroke-width="2.5" stroke-linecap="round" fill="none"/>'
    '<path d="M88 40c-4-14 4-26 18-26 10 0 16 6 18 12-10-3-22 0-36 14z" fill="#3D6FD1"/><circle cx="124" cy="25" r="5" fill="#F3EEE4"/>');
final _shades = _svg('<rect x="99" y="46" width="18" height="11" rx="5" fill="#121614"/>'
    '<path d="M99 50h-8" stroke="#121614" stroke-width="2.5" stroke-linecap="round"/>'
    '<path d="M103 49l5-2" stroke="#FFFFFF" stroke-width="1.6" stroke-linecap="round" opacity="0.7"/>');
final _hat = _svg('<path d="M94 37l10-30 14 26z" fill="#7B5CD6"/>'
    '<path d="M97 28l15-3M100 19l9-2" stroke="#F2C94C" stroke-width="3" stroke-linecap="round"/><circle cx="104" cy="6" r="4" fill="#C84D74"/>');
final _pencil = _svg('<g transform="rotate(-35 46 92)"><rect x="40" y="52" width="12" height="56" rx="2" fill="#F2C94C"/>'
    '<rect x="40" y="52" width="12" height="10" rx="2" fill="#F09AB4"/><rect x="40" y="60" width="12" height="4" fill="#C2C7C3"/>'
    '<path d="M40 108l6 12 6-12z" fill="#F3DFB6"/><path d="M44.5 116l1.5 4 1.5-4z" fill="#121614"/></g>');
final _hand = _svg('<ellipse cx="56" cy="98" rx="10" ry="8" fill="#7892A4"/>');
final _brow = _svg('<path d="M104 42l12-4" stroke="#121614" stroke-width="2.5" stroke-linecap="round"/>');
final _sun = _svg('<circle cx="28" cy="30" r="12" fill="#F2C94C"/>'
    '<path d="M28 8v6M28 46v6M6 30h6M44 30h6M12 14l4 4M40 42l4 4M12 46l4-4M40 18l4-4" stroke="#F2C94C" stroke-width="3" stroke-linecap="round"/>');
String _drop(double x, double y, double r) => _svg(
    '<path d="M$x ${y}c0 0-$r ${r * 1.3}-$r ${r * 1.9}a$r $r 0 0 0 ${r * 2} 0c0-${r * 0.6}-$r-${r * 1.9}-$r-${r * 1.9}z" fill="#8DB4F5"/>');
final _drops = [_drop(88, 30, 7), _drop(78, 48, 4)];
const _bits = [
  (Color(0xFF3D6FD1), 18.0, 40.0, 30.0),
  (Color(0xFFC84D74), 40.0, 18.0, -20.0),
  (Color(0xFF2E8C63), 140.0, 98.0, 40.0),
  (Color(0xFFE0A93F), 132.0, 22.0, -40.0),
];

/// The Dodate mascot. Each mood has its own idle animation; it holds still
/// when the system asks for reduced motion.
class Dodo extends StatefulWidget {
  const Dodo({super.key, this.mood = DodoMood.party, this.size = 160});

  final DodoMood mood;
  final double size;

  @override
  State<Dodo> createState() => _DodoState();
}

class _DodoState extends State<Dodo> with SingleTickerProviderStateMixin {
  // 36s divides evenly by every loop period used below, so nothing jumps on wrap.
  static const _period = 36.0;
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 36));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: _labels[widget.mood],
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: widget.size,
          child: RepaintBoundary(
            child: AnimatedBuilder(animation: _c, builder: (context, _) => _frame(_c.value * _period)),
          ),
        ),
      ),
    );
  }

  /// Sine wave in [-1, 1] with the given period in seconds.
  double _w(double t, double period, [double phase = 0]) => math.sin((t / period + phase) * 2 * math.pi);

  Widget _frame(double t) {
    final k = widget.size / 160;
    final m = widget.mood;
    Widget layer(String svg, {Matrix4? transform, double px = 80, double py = 80}) {
      final pic = SvgPicture.string(svg, width: widget.size, height: widget.size);
      if (transform == null) return pic;
      return Transform(transform: transform, origin: Offset(px * k, py * k), child: pic);
    }

    Matrix4 rot(double deg) => Matrix4.rotationZ(deg * math.pi / 180);

    // Whole-body idle motion.
    final Matrix4 bob = switch (m) {
      DodoMood.party => Matrix4.translationValues(0, -8 * k * _w(t, 0.9).abs(), 0)..rotateZ(3 * math.pi / 180 * _w(t, 1.8)),
      DodoMood.sleep => Matrix4.diagonal3Values(1, 1 + 0.03 * (0.5 + 0.5 * _w(t, 3)), 1),
      DodoMood.sweat => Matrix4.translationValues(_w(t, 1.8) > 0.85 ? 1.5 * k * _w(t, 0.2) : 0, 0, 0),
      _ => Matrix4.translationValues(0, -2 * k * (0.5 + 0.5 * _w(t, 2.4)), 0),
    };
    // Blink: eyes squash shut briefly every 4s.
    final phase = (t % 4) / 4;
    final blink = phase > 0.92 && phase < 0.98 ? 0.1 : 1.0;

    final body = <Widget>[
      layer(_tail, transform: rot(-6 * (0.5 + 0.5 * _w(t, 1.8))), px: 44, py: 90),
      layer(_body),
      if (m == DodoMood.party) layer(_arm, transform: rot(18 * (0.5 + 0.5 * _w(t, 0.45))), px: 40, py: 92) else layer(_wing),
      layer(_head),
      if (m != DodoMood.sleep && m != DodoMood.chill) layer(_eye, transform: Matrix4.diagonal3Values(1, blink, 1), px: 111, py: 52),
      if (m == DodoMood.sleep) layer(_sleepFace),
      if (m == DodoMood.chill) layer(_shades),
      if (m == DodoMood.party) layer(_hat, transform: rot(8 * _w(t, 0.9)), px: 106, py: 37),
      if (m == DodoMood.write) layer(_pencil, transform: Matrix4.translationValues(1.5 * k * _w(t, 0.8), 0, 0)..rotateZ(5 * math.pi / 180 * _w(t, 0.8)), px: 46, py: 92),
      if (m == DodoMood.write) layer(_hand),
      if (m == DodoMood.sweat) layer(_brow),
    ];

    return Stack(clipBehavior: Clip.none, children: [
      layer(_shadow, transform: m == DodoMood.party ? Matrix4.diagonal3Values(1 - 0.2 * _w(t, 0.9).abs(), 1, 1) : null, px: 80, py: 148),
      layer(_legs),
      Transform(transform: bob, origin: Offset(80 * k, 140 * k), child: Stack(children: body)),
      if (m == DodoMood.chill) layer(_sun, transform: rot(t * 30), px: 28, py: 30),
      if (m == DodoMood.sweat)
        for (var i = 0; i < 2; i++)
          Builder(builder: (_) {
            final p = ((t + i * 0.5) % 1.8) / 1.2;
            if (p > 1) return const SizedBox.shrink();
            return Opacity(opacity: 1 - p, child: Transform.translate(offset: Offset(0, 10 * k * p * p), child: layer(_drops[i])));
          }),
      if (m == DodoMood.sleep)
        for (var i = 0; i < 3; i++)
          Builder(builder: (_) {
            final p = ((t + i * 0.8) % 2.4) / 2.4;
            return Positioned(
              left: (128 + 18 * p) * k,
              top: (8 - 26 * p) * k,
              child: Opacity(
                opacity: math.sin(p * math.pi),
                child: Text('z',
                    style: TextStyle(fontFamily: 'Arial', fontWeight: FontWeight.w700, fontSize: (14 - i * 2) * k, color: const Color(0xFF7B5CD6), height: 1)),
              ),
            );
          }),
      if (m == DodoMood.party)
        for (final (i, b) in _bits.indexed)
          Positioned(
            left: b.$2 * k,
            top: (b.$3 - 6 * (0.5 + 0.5 * _w(t, 1.2 + i * 0.6))) * k,
            child: Transform.rotate(
              angle: (b.$4 + 180 * (t / (1.2 + i * 0.6) % 1)) * math.pi / 180,
              child: Container(width: 8 * k, height: 4 * k, decoration: BoxDecoration(color: b.$1, borderRadius: BorderRadius.circular(2 * k))),
            ),
          ),
    ]);
  }
}
