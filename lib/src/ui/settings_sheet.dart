import 'package:flutter/material.dart';

import '../core/dates.dart';
import 'feedback.dart';
import 'stage_actions.dart';
import 'theme.dart';
import 'widgets.dart';

const _limitChoices = [60, 120, 180, 240, 300];

/// Daily limit and appearance.
Future<void> showSettingsSheet(BuildContext context) {
  final fb = AppFeedback.of(context)..dismiss();
  final state = fb.widget.state;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    sheetAnimationStyle: sheetMotion(context),
    builder: (sheetContext) => ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final c = context.colors;
        final custom = !_limitChoices.contains(state.dailyLimit);
        var i = 0;
        Widget s(Widget w) => Stagger(index: i++, child: w);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              s(Text('Settings', style: Styles.h2(c.ink))),
              const SizedBox(height: 24),
              s(Row(children: [
                const Expanded(child: Text('Most homework in a day', style: TextStyle(fontWeight: FontWeight.w600))),
                RollText(formatMinutesLong(state.dailyLimit), style: TextStyle(fontWeight: FontWeight.w700, color: c.accent)),
              ])),
              const SizedBox(height: 4),
              s(Text('Dodate never plans more than this on one day.', style: TextStyle(fontSize: 14, height: 20 / 14, color: c.muted))),
              const SizedBox(height: 16),
              s(SlidingChips<int>(
                keyPrefix: 'limit',
                value: state.dailyLimit,
                onPick: state.setDailyLimit,
                options: [for (final m in _limitChoices) (m, Text(formatMinutes(m)), formatMinutesLong(m))],
              )),
              s(Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const Key('change-limit'),
                  style: TextButton.styleFrom(foregroundColor: custom ? c.accent : c.muted, padding: EdgeInsets.zero),
                  onPressed: () async {
                    final m = await askMinutes(context, 'Daily limit', initial: state.dailyLimit);
                    if (m != null) await state.setDailyLimit(m);
                  },
                  child: Text(custom ? 'Custom: ${formatMinutesLong(state.dailyLimit)}' : 'Another amount'),
                ),
              )),
              const SizedBox(height: 8),
              s(Container(
                height: 56,
                decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
                child: Row(children: [
                  const Expanded(child: Text('Appearance', style: TextStyle(fontWeight: FontWeight.w600))),
                  _ThemeSwitch(
                    value: state.theme,
                    onPick: (v) => state.setTheme(v),
                  ),
                ]),
              )),
            ]),
          ),
        );
      },
    ),
  );
}

class _ThemeSwitch extends StatelessWidget {
  const _ThemeSwitch({required this.value, required this.onPick});

  final String? value;
  final ValueChanged<String?> onPick;

  static const _options = [(null, 'Auto'), ('light', 'Light'), ('dark', 'Dark')];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final idx = _options.indexWhere((o) => o.$1 == value);
    const w = 64.0;
    return Container(
      height: 40,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: w * _options.length,
        child: Stack(children: [
          AnimatedPositioned(
            duration: motion(context, 300),
            curve: Curves.easeOutBack,
            left: idx * w,
            width: w,
            top: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: c.bg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Color(0x29000000), blurRadius: 2, offset: Offset(0, 1))],
              ),
            ),
          ),
          Row(children: [
            for (final (i, o) in _options.indexed)
              SizedBox(
                width: w,
                child: Pressable(
                  key: Key('theme-${o.$1 ?? 'auto'}'),
                  label: o.$2,
                  selected: i == idx,
                  onTap: () => onPick(o.$1),
                  child: Center(
                    child: Text(o.$2,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: i == idx ? c.ink : c.muted)),
                  ),
                ),
              ),
          ]),
        ]),
      ),
    );
  }
}

/// Spring-ish entry for every bottom sheet.
AnimationStyle sheetMotion(BuildContext context) => MediaQuery.disableAnimationsOf(context)
    ? AnimationStyle.noAnimation
    : const AnimationStyle(duration: Duration(milliseconds: 420), reverseDuration: Duration(milliseconds: 220), curve: Curves.easeOutCubic);
