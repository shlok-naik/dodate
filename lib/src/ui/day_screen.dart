import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../core/dates.dart';
import '../core/scheduler.dart';
import 'add_task_screen.dart';
import 'dodo.dart';
import 'feedback.dart';
import 'settings_sheet.dart';
import 'stage_actions.dart';
import 'task_detail_screen.dart';
import 'theme.dart';
import 'widgets.dart';

/// One day's work: big date heading, a week strip, and the pieces to do.
class DayScreen extends StatefulWidget {
  const DayScreen({super.key, required this.state, required this.selected, required this.onSelect});

  final AppState state;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  State<DayScreen> createState() => _DayScreenState();
}

class _DayScreenState extends State<DayScreen> {
  bool _scrolled = false;
  int _dir = 0;
  bool? _wasAllDone;

  AppState get state => widget.state;

  void _pick(String date, String current) {
    if (date == current) return;
    HapticFeedback.selectionClick();
    setState(() => _dir = diffDays(current, date).sign);
    widget.onSelect(date);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final c = context.colors;
        final today = state.today;
        final date = widget.selected ?? today;
        final entries = state.entriesFor(date);
        final shown = entries.where((e) => e.status != EntryStatus.missed).toList();
        final planned = entries.where((e) => e.status == EntryStatus.planned).toList();
        final done = entries.where((e) => e.status == EntryStatus.done).toList();
        final total = shown.fold(0, (a, e) => a + e.item.minutes);
        final doneMins = done.fold(0, (a, e) => a + e.loggedMinutes);
        final blocked = state.blockedDates.contains(date);
        final isToday = date == today;
        final allDone = isToday && planned.isEmpty && done.isNotEmpty;

        // Celebrate the moment today's last piece is ticked off.
        if (isToday) {
          if (_wasAllDone == false && allDone) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) AppFeedback.of(context).celebrate();
            });
          }
          _wasAllDone = allDone;
        }

        var sub = '${shortDate(date)} · ';
        sub += blocked
            ? 'Day off'
            : total == 0
                ? 'nothing planned'
                : '${formatMinutesLong(total)} of homework${total > state.dailyLimit ? ' · over limit' : ''}';

        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.depth == 0 && (n.metrics.pixels > 0) != _scrolled) setState(() => _scrolled = n.metrics.pixels > 0);
            return false;
          },
          child: Column(children: [
            _Header(
              scrolled: _scrolled,
              title: relativeDayName(date, today),
              sub: sub,
              ring: isToday && !blocked && shown.isNotEmpty
                  ? ProgressRing(
                      value: doneMins / (total == 0 ? 1 : total),
                      label: '${done.length} of ${shown.length} done',
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        RollText('${done.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        Text('/${shown.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ]),
                    )
                  : null,
              dir: _dir,
              strip: _DayStrip(state: state, selected: date, onPick: (d) => _pick(d, date)),
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragEnd: (d) {
                  final v = d.primaryVelocity ?? 0;
                  if (v.abs() > 300) _pick(addDays(date, v < 0 ? 1 : -1), date);
                },
                child: AnimatedSwitcher(
                  duration: motion(context, 220),
                  switchInCurve: smooth,
                  transitionBuilder: (child, a) {
                    final incoming = child.key == ValueKey(date);
                    return FadeTransition(
                      opacity: a,
                      child: SlideTransition(
                        position: Tween(begin: Offset((incoming ? 1 : -1) * _dir * 0.1, 0), end: Offset.zero).animate(a),
                        child: child,
                      ),
                    );
                  },
                  child: ListView(
                    key: ValueKey(date),
                    padding: EdgeInsets.fromLTRB(24, 8, 24, 136 + MediaQuery.paddingOf(context).bottom),
                    children: _body(context, c, date, today, entries, blocked, allDone),
                  ),
                ),
              ),
            ),
          ]),
        );
      },
    );
  }

  List<Widget> _body(BuildContext context, DodateColors c, String date, String today, List<DayEntry> entries,
      bool blocked, bool allDone) {
    final isPast = date.compareTo(today) < 0;
    final due = state.tasks.where((t) => t.dueDate == date && !t.completed).toList()
      ..sort((a, b) => a.dueTime.compareTo(b.dueTime));
    var i = 0;
    Widget s(Widget w) => Stagger(index: i++, child: w);

    if (state.tasks.isEmpty) {
      return [
        s(const Padding(padding: EdgeInsets.only(top: 24), child: Align(alignment: Alignment.centerLeft, child: Dodo(mood: DodoMood.chill, size: 140)))),
        s(Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text('Turn due dates into do dates.', style: Styles.h2(c.ink)),
        )),
        s(Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
              'Tell me what’s due and when. I’ll chop it into small pieces across the days before, so nothing is a last-minute panic.',
              style: TextStyle(fontSize: 16, height: 1.5, color: c.muted)),
        )),
        s(Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Align(
            alignment: Alignment.centerLeft,
            child: PillButton(label: 'Add homework', onTap: () => showAddTaskSheet(context, state)),
          ),
        )),
      ];
    }

    return [
      for (final w in state.plan.warnings)
        s(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: WarningCard(
            warning: w,
            action: w.type == WarningType.notEnoughTime ? _RaiseButton(state: state, taskId: w.taskId) : null,
          ),
        )),
      for (final t in due)
        s(Pressable(
          onTap: () => openTaskDetail(context, state, t.id),
          child: SizedBox(
            height: 40,
            child: Row(children: [
              Icon(Icons.flag_rounded, size: 18, color: c.tintFor(t.id).fg),
              const SizedBox(width: 10),
              Expanded(
                child: Text('${t.title} due ${t.dueTime}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w700, color: c.tintFor(t.id).fg)),
              ),
            ]),
          ),
        )),
      if (blocked && !isPast)
        s(_Centered(
          mascot: DodoMood.sleep,
          title: 'Day off. Shhh.',
          body: 'Even dodos need a lie-in. Your work moved to the other days.',
        ))
      else if (entries.isEmpty)
        s(_Centered(
          mascot: DodoMood.chill,
          title: isPast ? 'That day’s gone.' : 'Free day!',
          body: isPast ? 'No time machine yet. Look ahead instead.' : 'Nothing’s planned. Go outside, nap, whatever you like.',
        )),
      for (final e in entries) s(_EntryRow(key: ValueKey('${e.item.stageId}-${e.status.name}'), state: state, entry: e, date: date)),
      AnimatedSwitcher(
        duration: motion(context, 420),
        switchInCurve: Curves.easeOutBack,
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(a), child: child),
        ),
        child: allDone
            ? Container(
                key: const ValueKey('all-done'),
                margin: const EdgeInsets.only(top: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(24)),
                child: Row(children: [
                  const Dodo(mood: DodoMood.party, size: 72),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('All done today!', style: Styles.h3(c.ink)),
                      const SizedBox(height: 4),
                      Text('Future you says thanks. The rest of the evening is yours.',
                          style: TextStyle(fontSize: 14, height: 20 / 14, color: c.muted)),
                    ]),
                  ),
                ]),
              )
            : const SizedBox.shrink(key: ValueKey('not-done')),
      ),
      if (!isPast)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: Key('block-$date'),
            style: TextButton.styleFrom(
              foregroundColor: blocked ? c.accent : c.muted,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(48, 48),
            ),
            onPressed: () {
              final snap = state.snapshot();
              state.toggleBlocked(date);
              AppFeedback.of(context).say(
                blocked ? 'Back on — plan updated' : '${weekdayName(date)} off — work moved to other days',
                undo: snap,
              );
            },
            child: Text(blocked ? 'I can work after all' : date == today ? 'Can’t work today?' : 'Can’t work on ${weekdayName(date)}?'),
          ),
        ),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.scrolled, required this.title, required this.sub, required this.ring, required this.dir, required this.strip});

  final bool scrolled;
  final String title;
  final String sub;
  final Widget? ring;
  final int dir;
  final Widget strip;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedContainer(
      duration: motion(context, 200),
      padding: EdgeInsets.fromLTRB(24, MediaQuery.paddingOf(context).top + 24, 24, 4),
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(bottom: BorderSide(color: scrolled ? c.line : c.bg)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          height: 48,
          child: Row(children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: motion(context, 280),
                switchInCurve: Curves.easeOutBack,
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                    position: Tween(begin: Offset(0, child.key == ValueKey(title) ? 0.3 : -0.3), end: Offset.zero).animate(a),
                    child: child,
                  ),
                ),
                layoutBuilder: (cur, prev) => Stack(alignment: Alignment.centerLeft, children: [...prev, if (cur != null) cur]),
                child: Text(title, key: ValueKey(title), maxLines: 1, overflow: TextOverflow.ellipsis, style: Styles.display(c.ink)),
              ),
            ),
            AnimatedSwitcher(
              duration: motion(context, 300),
              transitionBuilder: (child, a) => ScaleTransition(scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack), child: child),
              child: ring ?? const SizedBox.shrink(),
            ),
            const SettingsButton(),
          ]),
        ),
        const SizedBox(height: 4),
        AnimatedSwitcher(
          duration: motion(context, 160),
          child: Text(sub, key: ValueKey(sub), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, height: 1.5, color: c.muted)),
        ),
        const SizedBox(height: 20),
        strip,
      ]),
    );
  }
}

/// The week around the selected day. The highlight slides between days;
/// dots under each date show that day's pieces in their assignment colours.
class _DayStrip extends StatelessWidget {
  const _DayStrip({required this.state, required this.selected, required this.onPick});

  final AppState state;
  final String selected;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final today = state.today;
    final monday = mondayOf(selected);
    final sel = diffDays(monday, selected);
    final selIsToday = selected == today;
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth / 7;
      return SizedBox(
        height: 72,
        child: Stack(children: [
          AnimatedPositioned(
            duration: motion(context, 320),
            curve: Curves.easeOutBack,
            left: sel * w + (w - 40) / 2,
            top: 22,
            width: 40,
            height: 40,
            child: AnimatedContainer(
              duration: motion(context, 200),
              decoration: BoxDecoration(color: selIsToday ? c.accent : c.ink, shape: BoxShape.circle),
            ),
          ),
          Row(children: [
            for (var i = 0; i < 7; i++)
              Builder(builder: (context) {
                final date = addDays(monday, i);
                final isSel = date == selected, isToday = date == today;
                final blocked = state.blockedDates.contains(date);
                final pieces = state.entriesFor(date).where((e) => e.status != EntryStatus.missed).take(4).toList();
                final minutes = pieces.fold(0, (a, e) => a + e.item.minutes);
                return SizedBox(
                  width: w,
                  child: Pressable(
                    key: Key('day-$date'),
                    label: '${shortDate(date)}, ${formatMinutesLong(minutes)} planned',
                    selected: isSel,
                    scale: 0.9,
                    onTap: () => onPick(date),
                    child: Column(children: [
                      SizedBox(
                        height: 16,
                        child: Text(weekdayInitial(date), style: TextStyle(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w600, color: c.muted)),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 40,
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: motion(context, 200),
                            style: TextStyle(
                              fontFamily: bodyFont,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isSel
                                  ? (isToday ? c.onAccent : c.bg)
                                  : isToday
                                      ? c.accent
                                      : date.compareTo(today) < 0
                                          ? c.muted
                                          : c.ink,
                            ),
                            child: Text('${dayOfMonth(date)}'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 6,
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          if (blocked)
                            Container(width: 10, height: 4, decoration: BoxDecoration(color: c.line, borderRadius: BorderRadius.circular(2)))
                          else
                            for (final e in pieces)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0, end: 1),
                                  duration: motion(context, 300),
                                  curve: Curves.easeOutBack,
                                  builder: (context, v, child) => Transform.scale(scale: v, child: child),
                                  child: TintDot(
                                    size: 4,
                                    color: e.status == EntryStatus.done ? c.line : c.tintFor(e.item.taskId).fg,
                                  ),
                                ),
                              ),
                        ]),
                      ),
                    ]),
                  ),
                );
              }),
          ]),
        ]),
      );
    });
  }
}

/// One piece of work: round check in the assignment's colour, stage and task,
/// and how long it takes.
class _EntryRow extends StatelessWidget {
  const _EntryRow({super.key, required this.state, required this.entry, required this.date});

  final AppState state;
  final DayEntry entry;
  final String date;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final item = entry.item;
    final done = entry.status == EntryStatus.done;
    final missed = entry.status == EntryStatus.missed;
    final planned = entry.status == EntryStatus.planned;
    final task = state.taskById(item.taskId);
    final tint = c.tintFor(item.taskId);
    final single = task != null && task.stages.length == 1;
    final title = single ? item.taskTitle : item.stageName;
    final subParts = [
      if (!single) item.taskTitle,
      if (task != null) 'due ${relativeDayName(task.dueDate, state.today).toLowerCase()}',
    ];
    final minutes = done ? entry.loggedMinutes : item.minutes;
    final canToggle = planned || (done && date == state.today);

    return AnimatedOpacity(
      duration: motion(context, 200),
      opacity: missed ? 0.5 : 1,
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
        child: Row(children: [
          Transform.translate(
            offset: const Offset(-12, 0),
            child: Semantics(
              button: true,
              label: missed ? null : (done ? 'Mark not done: $title' : 'Mark done: $title'),
              child: GestureDetector(
                key: Key('check-${item.stageId}-${entry.status.name}'),
                behavior: HitTestBehavior.opaque,
                onTap: missed || !canToggle
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        final fb = AppFeedback.of(context);
                        final snap = state.snapshot();
                        if (done) {
                          state.unlogToday(item.stageId);
                        } else {
                          state.logWork(item.taskId, item.stageId, item.minutes);
                          fb.say(
                            date == state.today ? '${formatMinutes(item.minutes)} done' : 'Done early — ${weekdayName(date)} is lighter now',
                            undo: snap,
                            done: true,
                          );
                        }
                      },
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: missed
                        ? Icon(Icons.redo_rounded, size: 20, color: c.muted)
                        : CheckDot(done: done, color: tint.fg),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Pressable(
              scale: 0.98,
              onTap: planned ? () => showStageActions(context, state, item.taskId, item.stageId, plannedMinutes: item.minutes) : () => openTaskDetail(context, state, item.taskId),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _Strike(
                        on: done,
                        child: Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 16, height: 1.5, fontWeight: FontWeight.w600, color: done ? c.muted : c.ink)),
                      ),
                      Text(
                        missed ? 'Moved forward' : subParts.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, height: 20 / 14, color: c.muted),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(12)),
                    child: Text(formatMinutes(minutes),
                        style: TextStyle(
                            fontSize: 14,
                            height: 20 / 14,
                            fontWeight: FontWeight.w600,
                            color: c.muted,
                            fontFeatures: const [FontFeature.tabularFigures()])),
                  ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// A line that draws across text, left to right, when [on].
class _Strike extends StatelessWidget {
  const _Strike({required this.on, required this.child});

  final bool on;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Stack(children: [
      child,
      Positioned.fill(
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: on ? 1 : 0),
          duration: motion(context, 300),
          curve: Curves.easeOut,
          builder: (context, v, _) => Align(
            alignment: const Alignment(-1, 0.15),
            child: FractionallySizedBox(
              widthFactor: v,
              child: Container(height: 2, decoration: BoxDecoration(color: c.muted, borderRadius: BorderRadius.circular(1))),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.mascot, required this.title, required this.body});

  final DodoMood mascot;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(children: [
        Dodo(mood: mascot, size: mascot == DodoMood.sleep ? 160 : 140),
        const SizedBox(height: 16),
        Text(title, textAlign: TextAlign.center, style: Styles.h3(c.ink)),
        const SizedBox(height: 4),
        Text(body, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, height: 1.5, color: c.muted)),
      ]),
    );
  }
}

/// "Allow 3h 30m" on a won't-fit warning: raises the daily limit just enough.
class _RaiseButton extends StatelessWidget {
  const _RaiseButton({required this.state, required this.taskId});

  final AppState state;
  final String taskId;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final limit = state.limitToFit(taskId);
    if (limit == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Pressable(
        label: 'Allow ${formatMinutesLong(limit)} a day',
        onTap: () {
          final snap = state.snapshot();
          state.setDailyLimit(limit);
          AppFeedback.of(context).say('Daily limit is now ${formatMinutesLong(limit)}', undo: snap);
        },
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: c.warnBtn, borderRadius: BorderRadius.circular(20)),
          child: Text('Allow ${formatMinutesLong(limit)}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: c.warnInk)),
        ),
      ),
    );
  }
}

/// Opens an assignment's detail page.
void openTaskDetail(BuildContext context, AppState state, String taskId) {
  Navigator.of(context).push(taskDetailRoute(state, taskId));
}

/// Opens Settings from any screen header.
class SettingsButton extends StatefulWidget {
  const SettingsButton({super.key});

  @override
  State<SettingsButton> createState() => _SettingsButtonState();
}

class _SettingsButtonState extends State<SettingsButton> {
  double _turns = 0;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(12, 0),
      child: IconButton(
        key: const Key('open-settings'),
        tooltip: 'Settings',
        onPressed: () {
          setState(() => _turns += 0.25);
          showSettingsSheet(context);
        },
        icon: AnimatedRotation(
          turns: _turns,
          duration: motion(context, 400),
          curve: Curves.easeOutBack,
          child: Icon(Icons.tune_rounded, color: context.colors.muted),
        ),
      ),
    );
  }
}
