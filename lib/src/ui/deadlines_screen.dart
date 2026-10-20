import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/dates.dart';
import '../core/scheduler.dart';
import 'day_screen.dart';
import 'dodo.dart';
import 'feedback.dart';
import 'theme.dart';
import 'widgets.dart';

/// Every assignment by deadline: what's next, progress rings, what's handed in.
class DeadlinesScreen extends StatefulWidget {
  const DeadlinesScreen({super.key, required this.state});

  final AppState state;

  @override
  State<DeadlinesScreen> createState() => _DeadlinesScreenState();
}

class _DeadlinesScreenState extends State<DeadlinesScreen> {
  bool _scrolled = false;

  AppState get state => widget.state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final c = context.colors;
        final today = state.today;
        final tasks = [...state.tasks]..sort((a, b) => '${a.dueDate}T${a.dueTime}'.compareTo('${b.dueDate}T${b.dueTime}'));
        final open = tasks.where((t) => !t.completed).toList();
        final handed = tasks.where((t) => t.completed).toList();
        final warned = {for (final w in state.plan.warnings) w.taskId: w};
        final next = open.firstOrNull;
        var i = 0;
        Widget s(Widget w) => Stagger(index: i++, child: w);

        String when(String date) => switch (diffDays(today, date)) {
              < 0 => 'overdue',
              0 => 'today',
              1 => 'tomorrow',
              < 7 => weekdayName(date),
              _ => shortDate(date),
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
                    Expanded(child: Text('Deadlines', style: Styles.display(c.ink))),
                    const SettingsButton(),
                  ]),
                ),
                const SizedBox(height: 4),
                Text(next == null ? 'All handed in' : '${open.length} to hand in · next ${when(next.dueDate)}',
                    style: TextStyle(fontSize: 16, color: c.muted)),
              ]),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(24, 16, 24, 136 + MediaQuery.paddingOf(context).bottom),
                children: [
                  if (next == null)
                    s(Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Column(children: [
                        const Dodo(mood: DodoMood.party, size: 140),
                        const SizedBox(height: 16),
                        Text(tasks.isEmpty ? 'Nothing here yet' : 'Nothing to hand in!', style: Styles.h3(c.ink)),
                        const SizedBox(height: 4),
                        Text(tasks.isEmpty ? 'Add an assignment with the + button.' : 'Everything’s in. Enjoy it.',
                            style: TextStyle(color: c.muted)),
                      ]),
                    ))
                  else ...[
                    s(_NextUp(state: state, taskId: next.id, warned: warned.containsKey(next.id), when: when(next.dueDate))),
                    const SizedBox(height: 24),
                    s(const SectionLabel('To hand in')),
                    for (final t in open)
                      s(Pressable(
                        key: Key('deadline-${t.id}'),
                        scale: 0.98,
                        onTap: () => openTaskDetail(context, state, t.id),
                        child: Container(
                          height: 72,
                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
                          child: Row(children: [
                            SizedBox(
                              width: 56,
                              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(shortDate(t.dueDate).split(' ').first.toUpperCase(),
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.muted)),
                                Text('${dayOfMonth(t.dueDate)}',
                                    style: TextStyle(fontFamily: displayFont, fontWeight: FontWeight.w800, fontSize: 20, height: 1.2, color: c.tintFor(t.id).fg)),
                              ]),
                            ),
                            Expanded(
                              child: Builder(builder: (context) {
                                final total = t.stages.fold(0, (a, s) => a + s.minutes);
                                final left = remainingForTask(t, state.logs);
                                final w = warned[t.id];
                                final days = diffDays(today, t.dueDate);
                                final sub = w != null
                                    ? (w.type == WarningType.overdue ? 'Overdue · ${formatMinutes(left)} left' : 'Won’t fit · ${formatMinutes(w.shortfall)} over')
                                    : left == 0
                                        ? 'Ready to hand in'
                                        : '${days <= 0 ? 'Due today' : days == 1 ? 'Due tomorrow' : 'In $days days'} · ${formatMinutes(total - left)} of ${formatMinutes(total)}';
                                return Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text(sub,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 14, color: w != null ? c.warn : c.muted)),
                                ]);
                              }),
                            ),
                            const SizedBox(width: 16),
                            Builder(builder: (context) {
                              final total = t.stages.fold(0, (a, s) => a + s.minutes);
                              final done = total - remainingForTask(t, state.logs);
                              final pct = total == 0 ? 0.0 : done / total;
                              return ProgressRing(size: 32, value: pct, color: c.tintFor(t.id).fg, label: '${(pct * 100).round()} percent done');
                            }),
                          ]),
                        ),
                      )),
                  ],
                  if (handed.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    s(const SectionLabel('Handed in')),
                    for (final t in handed)
                      s(Container(
                        height: 48,
                        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
                        child: Row(children: [
                          SizedBox(width: 56, child: Align(alignment: Alignment.centerLeft, child: Icon(Icons.check_rounded, size: 18, color: c.accent))),
                          Expanded(
                            child: Text(t.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: c.muted, decoration: TextDecoration.lineThrough, decorationColor: c.muted)),
                          ),
                          TextButton(
                            key: Key('reopen-${t.id}'),
                            onPressed: () {
                              state.reopenTask(t.id);
                              AppFeedback.of(context).say('Back on your plan');
                            },
                            child: const Text('Undo'),
                          ),
                        ]),
                      )),
                  ],
                ],
              ),
            ),
          ]),
        );
      },
    );
  }
}

class _NextUp extends StatelessWidget {
  const _NextUp({required this.state, required this.taskId, required this.warned, required this.when});

  final AppState state;
  final String taskId;
  final bool warned;
  final String when;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = state.taskById(taskId)!;
    final left = remainingForTask(t, state.logs);
    return Pressable(
      scale: 0.98,
      onTap: () => openTaskDetail(context, state, t.id),
      child: AnimatedContainer(
        duration: motion(context, 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: warned ? c.warnBg : c.surfaceAlt, borderRadius: BorderRadius.circular(24)),
        child: Row(children: [
          Dodo(mood: warned ? DodoMood.sweat : left > 0 ? DodoMood.write : DodoMood.party, size: 80),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(warned ? 'NEXT UP · WON’T FIT' : 'NEXT UP', style: Styles.kicker(warned ? c.warn : c.muted)),
              const SizedBox(height: 4),
              Text(t.title, style: Styles.h3(c.ink)),
              const SizedBox(height: 4),
              Text('Due $when, ${t.dueTime} · ${left > 0 ? '${formatMinutes(left)} left' : 'ready to hand in'}',
                  style: TextStyle(fontSize: 14, color: c.muted)),
            ]),
          ),
        ]),
      ),
    );
  }
}
