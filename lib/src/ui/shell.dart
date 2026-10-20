import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import 'add_task_screen.dart';
import 'day_screen.dart';
import 'deadlines_screen.dart';
import 'theme.dart';
import 'week_screen.dart';
import 'widgets.dart';

/// Home: Day, Week and Deadlines behind a floating tab bar, plus the add button.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.state});

  final AppState state;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  int _dir = 1;
  String? _day; // selected day on the Day tab; null means today

  void _go(int tab) {
    if (tab == _tab) return;
    HapticFeedback.selectionClick();
    setState(() {
      _dir = tab > _tab ? 1 : -1;
      _tab = tab;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = widget.state;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final screens = [
      DayScreen(key: const ValueKey('day'), state: state, selected: _day, onSelect: (d) => setState(() => _day = d)),
      WeekScreen(
        key: const ValueKey('week'),
        state: state,
        onOpenDay: (d) => setState(() {
          _day = d;
          _dir = -1;
          _tab = 0;
        }),
      ),
      DeadlinesScreen(key: const ValueKey('deadlines'), state: state),
    ];

    return Scaffold(
      body: Stack(children: [
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: motion(context, 260),
            switchInCurve: smooth,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, a) {
              final incoming = child.key == screens[_tab].key;
              final dx = (incoming ? 1 : -1) * _dir * 0.08;
              return FadeTransition(
                opacity: a,
                child: SlideTransition(position: Tween(begin: Offset(dx, 0), end: Offset.zero).animate(a), child: child),
              );
            },
            child: screens[_tab],
          ),
        ),
        // Fade the list out under the floating bar.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 120 + bottom,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  stops: const [0.3, 1],
                  colors: [c.bg, c.bg.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: bottom > 0 ? bottom : 24,
          height: 56,
          child: Row(children: [
            Expanded(child: _TabBar(tab: _tab, onTap: _go, alert: state.plan.warnings.isNotEmpty)),
            const SizedBox(width: 8),
            Pressable(
              key: const Key('add-task'),
              label: 'Add assignment',
              scale: 0.88,
              onTap: () => showAddTaskSheet(context, state),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: c.accent,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: c.accentShadow, blurRadius: 24, offset: const Offset(0, 8))],
                ),
                child: Icon(Icons.add_rounded, color: c.onAccent, size: 28),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.tab, required this.onTap, required this.alert});

  final int tab;
  final ValueChanged<int> onTap;
  final bool alert;

  static const _labels = ['Day', 'Week', 'Deadlines'];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: c.glass,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: c.ink.withValues(alpha: 0.06)),
            boxShadow: [BoxShadow(color: c.navShadow, blurRadius: 32, offset: const Offset(0, 8))],
          ),
          child: LayoutBuilder(builder: (context, box) {
            final w = box.maxWidth / 3;
            return Stack(children: [
              AnimatedPositioned(
                duration: motion(context, 340),
                curve: Curves.easeOutBack,
                left: tab * w,
                width: w,
                top: 0,
                bottom: 0,
                child: DecoratedBox(decoration: BoxDecoration(color: c.navOn, borderRadius: BorderRadius.circular(24))),
              ),
              Row(children: [
                for (var i = 0; i < 3; i++)
                  Expanded(
                    child: Pressable(
                      key: Key('tab-${_labels[i].toLowerCase()}'),
                      label: _labels[i],
                      selected: i == tab,
                      scale: 0.94,
                      onTap: () => onTap(i),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        AnimatedDefaultTextStyle(
                          duration: motion(context, 200),
                          style: TextStyle(
                            fontFamily: bodyFont,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: i == tab ? c.accent : c.ink,
                          ),
                          child: Text(_labels[i]),
                        ),
                        if (i == 2 && alert) ...[
                          const SizedBox(width: 4),
                          const _Pulse(),
                        ],
                      ]),
                    ),
                  ),
              ]),
            ]);
          }),
        ),
      ),
    );
  }
}

/// Amber dot that gently pulses: something won't fit.
class _Pulse extends StatefulWidget {
  const _Pulse();

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!MediaQuery.disableAnimationsOf(context) && !_c.isAnimating) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Something won\'t fit',
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final v = _c.value < 0.5 ? Curves.easeInOut.transform((_c.value / 0.5)) : 0.0;
            return Transform.scale(
              scale: 1 + 0.4 * (v < 0.5 ? v * 2 : (1 - v) * 2),
              child: Container(width: 8, height: 8, decoration: BoxDecoration(color: context.colors.warnBar, shape: BoxShape.circle)),
            );
          },
        ),
      );
}
