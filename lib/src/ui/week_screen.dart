import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../core/dates.dart';
import '../core/models.dart';
import 'add_task_screen.dart';
import 'stage_actions.dart';
import 'tasks_screen.dart';
import 'theme.dart';
import 'widgets.dart';

/// The home screen: a Monday-to-Sunday strip showing how full each day is,
/// and the selected day's work below it.
class WeekScreen extends StatefulWidget {
  const WeekScreen({super.key, required this.state});

  final AppState state;

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> {
  int _weekOffset = 0;
  String? _selected;

  AppState get state => widget.state;

  void _changeWeek(int delta) {
    setState(() {
      _weekOffset = delta == 0 ? 0 : _weekOffset + delta;
      final monday = addDays(mondayOf(state.today), 7 * _weekOffset);
      final today = state.today;
      _selected = diffDays(monday, today) >= 0 && diffDays(monday, today) < 7 ? today : monday;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final c = context.colors;
        final today = state.today;
        final monday = addDays(mondayOf(today), 7 * _weekOffset);
        var selected = _selected ?? today;
        if (diffDays(monday, selected) < 0 || diffDays(monday, selected) > 6) selected = monday;
        final warnings = state.plan.warnings;

        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            key: const Key('add-task'),
            onPressed: () => showAddTaskSheet(context, state),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Assignment'),
          ),
          body: SafeArea(
            bottom: false,
            child: GestureDetector(
              onHorizontalDragEnd: (d) {
                final v = d.primaryVelocity ?? 0;
                if (v.abs() > 300) _changeWeek(v < 0 ? 1 : -1);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                children: [
                  Row(
                    children: [
                      Text('dodate',
                          style: TextStyle(
                              fontFamily: displayFont, fontWeight: FontWeight.w700, fontSize: 24, color: c.accent)),
                      const Spacer(),
                      IconButton(
                        key: const Key('open-tasks'),
                        tooltip: 'Assignments',
                        icon: const Icon(Icons.checklist_rounded),
                        onPressed: () => Navigator.push(
                            context, MaterialPageRoute(builder: (_) => TasksScreen(state: state))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(weekRangeLabel(monday), style: Theme.of(context).textTheme.titleMedium),
                      const Spacer(),
                      if (_weekOffset != 0)
                        TextButton(onPressed: () => _changeWeek(0), child: const Text('This week')),
                      IconButton(
                        key: const Key('prev-week'),
                        tooltip: 'Previous week',
                        onPressed: () => _changeWeek(-1),
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      IconButton(
                        key: const Key('next-week'),
                        tooltip: 'Next week',
                        onPressed: () => _changeWeek(1),
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _WeekStrip(
                    state: state,
                    monday: monday,
                    selected: selected,
                    onSelect: (d) => setState(() => _selected = d),
                  ),
                  if (warnings.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    for (final w in warnings)
                      Padding(padding: const EdgeInsets.only(bottom: 10), child: WarningCard(warning: w)),
                  ],
                  const SizedBox(height: 24),
                  _DayDetail(state: state, date: selected),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.state, required this.monday, required this.selected, required this.onSelect});

  final AppState state;
  final String monday;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final today = state.today;
    final dueDates = {for (final t in state.tasks) if (!t.completed) t.dueDate};
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Builder(builder: (context) {
                final date = addDays(monday, i);
                final minutes = state.entriesFor(date).fold(0, (a, e) => a + e.item.minutes);
                final blocked = state.blockedDates.contains(date);
                final isToday = date == today;
                final isSelected = date == selected;
                final fill = math.min(1.0, minutes / state.dailyLimit);
                final over = minutes > state.dailyLimit;
                return Semantics(
                  button: true,
                  label: '${shortDate(date)}, ${formatMinutesLong(minutes)} planned',
                  child: InkWell(
                    key: Key('day-$date'),
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => onSelect(date),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          Text(weekdayInitial(date),
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.muted)),
                          const SizedBox(height: 6),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isToday ? c.accent : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: isSelected && !isToday ? c.ink : Colors.transparent, width: 1.5),
                            ),
                            child: Text('${dayOfMonth(date)}',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: isToday ? c.onAccent : c.ink)),
                          ),
                          const SizedBox(height: 8),
                          // How full the day is, against the daily limit.
                          Container(
                            width: 8,
                            height: 30,
                            alignment: Alignment.bottomCenter,
                            decoration: BoxDecoration(
                                color: c.surfaceAlt, borderRadius: BorderRadius.circular(4)),
                            child: blocked
                                ? null
                                : FractionallySizedBox(
                                    heightFactor: fill,
                                    child: Container(
                                      decoration: BoxDecoration(
                                          color: over ? c.warn : c.accent,
                                          borderRadius: BorderRadius.circular(4)),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: dueDates.contains(date) ? c.ink : Colors.transparent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }
}

class _DayDetail extends StatelessWidget {
  const _DayDetail({required this.state, required this.date});

  final AppState state;
  final String date;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final today = state.today;
    final entries = state.entriesFor(date);
    final planned = entries.where((e) => e.status == EntryStatus.planned).toList();
    final total = entries.where((e) => e.status != EntryStatus.missed).fold(0, (a, e) => a + e.item.minutes);
    final blocked = state.blockedDates.contains(date);
    final isPast = date.compareTo(today) < 0;
    final due = state.tasks.where((t) => t.dueDate == date && !t.completed).toList()
      ..sort((a, b) => a.dueTime.compareTo(b.dueTime));
    final allDone = date == today && planned.isEmpty && entries.any((e) => e.status == EntryStatus.done);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(relativeDayName(date, today), style: text.displaySmall),
        const SizedBox(height: 4),
        Text(
          blocked
              ? '${shortDate(date)} · Day off'
              : '${shortDate(date)} · ${formatMinutesLong(total)} of ${formatMinutesLong(state.dailyLimit)}',
          style: text.bodySmall?.copyWith(fontSize: 14),
        ),
        const SizedBox(height: 16),
        for (final t in due)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Icon(Icons.outlined_flag_rounded, size: 18, color: c.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: 'Due ${t.dueTime}  ', style: TextStyle(color: c.muted, fontSize: 14)),
                  TextSpan(text: t.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                ])),
              ),
            ]),
          ),
        if (allDone)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              Icon(Icons.check_circle_rounded, color: c.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text('All done for today. Nice work.',
                    style: TextStyle(fontWeight: FontWeight.w600, color: c.ink)),
              ),
            ]),
          ),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Column(children: [
              Icon(blocked ? Icons.beach_access_outlined : Icons.wb_sunny_outlined, size: 32, color: c.muted),
              const SizedBox(height: 10),
              Text(
                blocked
                    ? 'Day off. Work has been moved to other days.'
                    : state.tasks.isEmpty
                        ? 'Add an assignment and Dodate will spread\nthe work across your week.'
                        : 'Nothing planned. Enjoy it.',
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(fontSize: 15),
              ),
            ]),
          ),
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SessionCard(state: state, entry: e, date: date),
          ),
        if (!isPast)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: Key('block-$date'),
              onPressed: () => state.toggleBlocked(date),
              icon: Icon(blocked ? Icons.event_available_outlined : Icons.event_busy_outlined, size: 18),
              label: Text(blocked ? 'I can work this day' : 'I can\'t work this day'),
            ),
          ),
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.state, required this.entry, required this.date});

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
    final minutes = done ? entry.loggedMinutes : item.minutes;

    return Opacity(
      opacity: missed ? 0.6 : 1,
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: planned
              ? () => showStageActions(context, state, item.taskId, item.stageId, plannedMinutes: item.minutes)
              : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
            child: Row(
              children: [
                TintBadge(taskId: item.taskId, title: item.taskTitle),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.taskTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: c.muted)),
                      const SizedBox(height: 2),
                      Text(
                        item.stageName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: done ? c.muted : c.ink,
                          decoration: done ? TextDecoration.lineThrough : null,
                          decorationColor: c.muted,
                        ),
                      ),
                      if (missed) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: c.surfaceAlt, borderRadius: BorderRadius.circular(8)),
                          child: Text('Moved forward',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.muted)),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(formatMinutes(minutes),
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: c.muted,
                        fontFeatures: const [FontFeature.tabularFigures()])),
                const SizedBox(width: 4),
                if (!missed)
                  IconButton(
                    key: Key('check-${item.stageId}-${entry.status.name}'),
                    tooltip: done ? 'Done' : 'Mark done',
                    onPressed: planned
                        ? () {
                            HapticFeedback.lightImpact();
                            state.logWork(item.taskId, item.stageId, item.minutes);
                          }
                        : null,
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                      child: done
                          ? Icon(Icons.check_circle_rounded, key: const ValueKey('done'), color: c.accent, size: 28)
                          : Icon(Icons.radio_button_unchecked_rounded,
                              key: const ValueKey('todo'), color: c.line, size: 28),
                    ),
                  )
                else
                  const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the add-assignment sheet (kept here so the week screen owns the flow).
Future<void> showAddTaskSheet(BuildContext context, AppState state) async {
  final task = await showModalBottomSheet<Task>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => AddTaskSheet(state: state),
  );
  if (task == null || !context.mounted) return;
  final warnings = state.plan.warnings.where((w) => w.taskId == task.id).toList();
  if (warnings.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${task.title} is spread across your week.')));
    return;
  }
  // Warn straight away if the deadline can't be met.
  await showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      icon: Icon(Icons.hourglass_bottom_rounded, color: context.colors.warn),
      title: Text(warnings.first.headline, textAlign: TextAlign.center),
      content: Text(warnings.first.message, textAlign: TextAlign.center),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
    ),
  );
}
