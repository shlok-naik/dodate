import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import 'theme.dart';
import 'widgets.dart';

/// Toasts (with Undo) and confetti, drawn above every screen and sheet.
class AppFeedback extends StatefulWidget {
  const AppFeedback({super.key, required this.state, required this.child});

  final AppState state;
  final Widget child;

  static AppFeedbackState of(BuildContext context) => context.findAncestorStateOfType<AppFeedbackState>()!;

  @override
  State<AppFeedback> createState() => AppFeedbackState();
}

class _Toast {
  _Toast(this.id, this.message, this.undo, this.done);
  final int id;
  final String message;
  final String? undo; // AppState snapshot to restore
  final bool done;
}

class AppFeedbackState extends State<AppFeedback> {
  _Toast? _toast;
  Timer? _timer;
  int _ids = 0;
  final List<int> _bursts = [];

  /// Shows [message]. With [undo] (from [AppState.snapshot]) it offers Undo.
  void say(String message, {String? undo, bool done = false}) {
    _timer?.cancel();
    setState(() => _toast = _Toast(++_ids, message, undo, done));
    _timer = Timer(Duration(milliseconds: undo != null ? 4000 : 2400), dismiss);
  }

  void dismiss() {
    _timer?.cancel();
    if (mounted && _toast != null) setState(() => _toast = null);
  }

  void celebrate() => setState(() => _bursts.add(++_ids));

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = _toast;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Stack(children: [
      widget.child,
      Positioned(
        left: 24,
        right: 24,
        bottom: (bottom > 0 ? bottom : 24) + 72,
        child: AnimatedSwitcher(
          duration: motion(context, 280),
          switchInCurve: Curves.easeOutBack,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(a),
              child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(a), child: child),
            ),
          ),
          child: t == null
              ? const SizedBox.shrink()
              : Material(
                  key: ValueKey(t.id),
                  color: c.ink,
                  elevation: 0,
                  borderRadius: BorderRadius.circular(18),
                  shadowColor: Colors.black26,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 52),
                    padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 32, offset: Offset(0, 12))],
                    ),
                    child: Semantics(
                      liveRegion: true,
                      child: Row(children: [
                        if (t.done) ...[
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: motion(context, 400),
                            curve: Curves.elasticOut,
                            builder: (context, v, child) => Transform.scale(scale: v, child: child),
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(color: c.toastAccent, shape: BoxShape.circle),
                              child: Icon(Icons.check_rounded, size: 16, color: c.bg),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(t.message,
                                style: TextStyle(color: c.bg, fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        if (t.undo != null)
                          TextButton(
                            key: const Key('toast-undo'),
                            style: TextButton.styleFrom(foregroundColor: c.toastAccent, minimumSize: const Size(48, 36)),
                            onPressed: () {
                              final snap = t.undo!;
                              dismiss();
                              widget.state.restore(snap);
                            },
                            child: const Text('Undo'),
                          ),
                      ]),
                    ),
                  ),
                ),
        ),
      ),
      for (final id in _bursts)
        Positioned.fill(
          key: ValueKey('confetti-$id'),
          child: Confetti(onDone: () => setState(() => _bursts.remove(id))),
        ),
    ]);
  }
}
