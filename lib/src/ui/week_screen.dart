import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/dates.dart';
import 'day_screen.dart';
import 'dodo.dart';
import 'stage_actions.dart';
import 'theme.dart';
import 'widgets.dart';

/// Monday to Sunday: a load chart against the daily limit, then each day's work.
class WeekScreen extends StatefulWidget {
  const WeekScreen({super.key, required this.state, required this.onOpenDay});

  final AppState state;
  final ValueChanged<String> onOpenDay;

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> {
  int _offset = 0;
  int _dir = 1;
  bool _scrolled = false;

  AppState get state => widget.state;

  void _go(int offset) {
    if (offset == _offset) return;
    setState(() {
      _dir = (offset - _offset).sign;
      _offset = offset;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final c = context.colors;
        final today = state.today;
        final monday = addDays(mondayOf(today), 7 * _offset);
        final days = [
          for (var i = 0; i < 7; i++)
            () {
              final d = addDays(monday, i);
              final entries = state.entriesFor(d);
              final mins = entries.where((e) => e.status != EntryStatus.missed).fold(0, (a, e) => a + e.item.minutes);
              return (d, entries, mins);
            }(),
        ];
        final weekMins = days.fold(0, (a, d) => a + d.$3);
        final title = switch (_offset) {
          0 => 'This week',
          1 => 'Next week',
          -1 => 'Last week',
          _ => _offset > 1 ? 'Later' : 'Earlier',
        };

        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.depth == 0 && (n.metrics.pixels > 0) != _scrolled) setState(() => _scrolled = n.metrics.pixels > 0);
            return false;
          },
          child: Column(children: [
            AnimatedContainer(
              duration: motion(context, 200),
              padding: EdgeInsets.fromLTRB(24, MediaQuery.paddingOf(context).top + 24, 24, 16),
              decoration: BoxDecoration(color: c.bg, border: Border(bottom: BorderSide(color: _scrolled ? c.line : c.bg))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  height: 48,
                  child: Row(children: [
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: motion(context, 220),
                        layoutBuilder: (cur, prev) => Stack(alignment: Alignment.centerLeft, children: [...prev, if (cur != null) cur]),
                        child: Text(title, key: ValueKey(title), maxLines: 1, overflow: TextOverflow.ellipsis, style: Styles.display(c.ink)),
                      ),
                    ),
                    IconButton(key: const Key('prev-week'), tooltip: 'Previous week', onPressed: () => _go(_offset - 1), icon: Icon(Icons.chevron_left_rounded, color: c.ink)),
                    IconButton(key: const Key('next-week'), tooltip: 'Next week', onPressed: () => _go(_offset + 1), icon: Icon(Icons.chevron_right_rounded, color: c.ink)),
                    const SettingsButton(),
                  ]),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 24,
                  child: Row(children: [
                    Expanded(
                      child: Text('${weekRangeLabel(monday)} · ${weekMins > 0 ? '${formatMinutesLong(weekMins)} of homework' : 'no homework'}',
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, color: c.muted)),
                    ),
                    AnimatedSwitcher(
                      duration: motion(context, 200),
                      child: _offset == 0
                          ? const SizedBox.shrink()
                          : GestureDetector(
                              key: const Key('this-week'),
                              onTap: () => _go(0),
                              child: Text('Back to this week', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.accent)),
                            ),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                _LoadChart(key: ValueKey(monday), days: days.map((d) => (d.$1, d.$3)).toList(), state: state),
              ]),
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragEnd: (d) {
                  final v = d.primaryVelocity ?? 0;
                  if (v.abs() > 300) _go(_offset + (v < 0 ? 1 : -1));
                },
                child: AnimatedSwitcher(
                  duration: motion(context, 240),
                  switchInCurve: smooth,
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(begin: Offset((child.key == ValueKey(monday) ? 1 : -1) * _dir * 0.08, 0), end: Offset.zero).animate(a),
                      child: child,
                    ),
                  ),
                  child: ListView(
                    key: ValueKey(monday),
                    padding: EdgeInsets.fromLTRB(24, 0, 24, 136 + MediaQuery.paddingOf(context).bottom),
                    children: [
                      if (weekMins == 0 && diffDays(today, addDays(monday, 6)) >= 0)
                        Stagger(
                          index: 0,
                          child: Container(
                            margin: const EdgeInsets.only(top: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(24)),
                            child: Row(children: [
                              const Dodo(mood: DodoMood.chill, size: 64),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('Quiet week.', style: Styles.h3(c.ink)),
                                  const SizedBox(height: 4),
                                  Text('Nothing planned. Enjoy the break.', style: TextStyle(fontSize: 14, color: c.muted)),
                                ]),
                              ),
                            ]),
                          ),
                        ),
                      for (final (i, d) in days.indexed) Stagger(index: i + 1, child: _DayBlock(state: state, date: d.$1, entries: d.$2, minutes: d.$3, onOpen: () => widget.onOpenDay(d.$1))),
                    ],
                  ),
                ),
              ),
            ),
          ]),
        );
      },
    );
  }
}

/// One bar per day; the dashed line is the daily limit.
class _LoadChart extends StatelessWidget {
  const _LoadChart({super.key, required this.days, required this.state});

  final List<(String, int)> days;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const h = 32.0;
    final limit = state.dailyLimit;
    final maxM = math.max(limit, days.fold(0, (a, d) => math.max(a, d.$2)));
    return SizedBox(
      height: h,
      child: Stack(children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: limit / maxM * h,
          child: CustomPaint(size: const Size(double.infinity, 1.5), painter: _Dashes(c.line)),
        ),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (final (i, (d, m)) in days.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: state.blockedDates.contains(d) ? 4 : math.max(4, m / maxM * h)),
                duration: motion(context, 500 + i * 40),
                curve: Curves.easeOutBack,
                builder: (context, v, _) {
                  final isToday = d == state.today, over = m > limit, past = d.compareTo(state.today) < 0;
                  return Container(
                    height: v.clamp(0, h),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: (over ? c.warnBar : isToday ? c.accent : m > 0 ? c.muted : c.line)
                          .withValues(alpha: past ? 0.25 : isToday || over ? 1 : 0.35),
                    ),
                  );
                },
              ),
            ),
          ],
        ]),
      ]),
    );
  }
}

class _Dashes extends CustomPainter {
  _Dashes(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = size.height;
    for (var x = 0.0; x < size.width; x += 7) {
      canvas.drawLine(Offset(x, 0), Offset(math.min(x + 4, size.width), 0), p);
    }
  }

  @override
  bool shouldRepaint(_Dashes o) => o.color != color;
}

class _DayBlock extends StatelessWidget {
  const _DayBlock({required this.state, required this.date, required this.entries, required this.minutes, required this.onOpen});

  final AppState state;
  final String date;
  final List<DayEntry> entries;
  final int minutes;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final today = state.today;
    final isToday = date == today;
    final blocked = state.blockedDates.contains(date);
    final due = state.tasks.where((t) => t.dueDate == date && !t.completed).toList();
    return Opacity(
      opacity: date.compareTo(today) < 0 ? 0.45 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
        child: Column(children: [
          Pressable(
            key: Key('week-day-$date'),
            label: 'Open ${weekdayName(date)} ${dayOfMonth(date)}',
            scale: 0.98,
            onTap: onOpen,
            child: SizedBox(
              height: 48,
              child: Row(children: [
                SizedBox(
                  width: 44,
                  child: Text('${dayOfMonth(date)}',
                      style: TextStyle(fontFamily: displayFont, fontWeight: FontWeight.w800, fontSize: 28, letterSpacing: -0.8, color: isToday ? c.accent : c.ink)),
                ),
                Expanded(
                  child: Text(relativeDayName(date, today) == 'Yesterday' ? weekdayName(date) : relativeDayName(date, today),
                      style: TextStyle(fontWeight: FontWeight.w600, color: isToday ? c.accent : c.muted)),
                ),
                Text(blocked ? 'Off' : minutes > 0 ? formatMinutes(minutes) : 'None',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: minutes > state.dailyLimit ? c.warn : c.muted,
                        fontFeatures: const [FontFeature.tabularFigures()])),
              ]),
            ),
          ),
          for (final t in due)
            Pressable(
              onTap: () => openTaskDetail(context, state, t.id),
              child: SizedBox(
                height: 40,
                child: Row(children: [
                  SizedBox(width: 44, child: Align(alignment: Alignment.centerLeft, child: Icon(Icons.flag_rounded, size: 16, color: c.tintFor(t.id).fg))),
                  Expanded(
                    child: Text('${t.title} due ${t.dueTime}',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: c.tintFor(t.id).fg)),
                  ),
                ]),
              ),
            ),
          for (final e in entries)
            Pressable(
              scale: 0.98,
              onTap: e.status == EntryStatus.planned
                  ? () => showStageActions(context, state, e.item.taskId, e.item.stageId, plannedMinutes: date == today ? e.item.minutes : null)
                  : () => openTaskDetail(context, state, e.item.taskId),
              child: SizedBox(
                height: 40,
                child: Row(children: [
                  SizedBox(width: 44, child: Align(alignment: Alignment.centerLeft, child: TintDot(color: c.tintFor(e.item.taskId).fg))),
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: e.item.taskTitle),
                        if ((state.taskById(e.item.taskId)?.stages.length ?? 1) > 1)
                          TextSpan(text: '  ${e.item.stageName}', style: TextStyle(color: c.muted)),
                        if (e.status == EntryStatus.missed) TextSpan(text: '  moved', style: TextStyle(color: c.muted, fontSize: 13)),
                      ]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: e.status == EntryStatus.planned ? c.ink : c.muted,
                        decoration: e.status == EntryStatus.done ? TextDecoration.lineThrough : null,
                        decorationColor: c.muted,
                      ),
                    ),
                  ),
                  Text(formatMinutes(e.status == EntryStatus.done ? e.loggedMinutes : e.item.minutes),
                      style: TextStyle(fontSize: 14, color: c.muted, fontFeatures: const [FontFeature.tabularFigures()])),
                ]),
              ),
            ),
          if (blocked)
            SizedBox(
              height: 40,
              child: Row(children: [
                Transform.translate(offset: const Offset(-8, 0), child: const SizedBox(width: 44, child: Dodo(mood: DodoMood.sleep, size: 40))),
                Text('Day off. Shhh.', style: TextStyle(color: c.muted)),
              ]),
            ),
        ]),
      ),
    );
  }
}
