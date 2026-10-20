import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../core/dates.dart';
import '../core/models.dart';
import '../core/scheduler.dart';
import 'dodo.dart';
import 'feedback.dart';
import 'stage_actions.dart';
import 'theme.dart';
import 'widgets.dart';

Route<void> taskDetailRoute(AppState state, String taskId) =>
    MaterialPageRoute(builder: (_) => TaskDetailScreen(state: state, taskId: taskId));

/// One assignment: progress, its stages, and where the plan puts each piece.
class TaskDetailScreen extends StatelessWidget {
  const TaskDetailScreen({super.key, required this.state, required this.taskId});

  final AppState state;
  final String taskId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final task = state.taskById(taskId);
          if (task == null) return const SizedBox.shrink();
          return _Body(state: state, task: task);
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.task});

  final AppState state;
  final Task task;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tint = c.tintFor(task.id);
    final today = state.today;
    final total = task.stages.fold(0, (a, s) => a + s.minutes);
    final logged = task.stages.fold(0, (a, s) => a + state.loggedFor(s.id).clamp(0, s.minutes));
    final left = task.completed ? 0 : remainingForTask(task, state.logs);
    final warning = state.plan.warnings.where((w) => w.taskId == task.id).firstOrNull;
    final days = diffDays(today, task.dueDate);
    final pieces = [
      for (final e in state.plan.days.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
        for (final item in e.value)
          if (item.taskId == task.id) (e.key, item),
    ];
    final fb = AppFeedback.of(context);

    final (DodoMood, String, String, Color, Color)? mascot = task.completed
        ? (DodoMood.party, 'Handed in. Legend.', 'The dodo did a little dance.', c.accentSoft, c.ink)
        : warning != null
            ? (DodoMood.sweat, warning.headline, warning.message, c.warnBg, c.warnInk)
            : left == 0
                ? (DodoMood.party, 'Ready to hand in!', 'All the work is done. Tap below once it’s in.', c.surfaceAlt, c.ink)
                : null;
    final status = task.completed
        ? 'Handed in'
        : warning != null
            ? 'Won’t fit'
            : left == 0
                ? 'Ready'
                : 'On track';

    var i = 0;
    Widget s(Widget w) => Stagger(index: i++, child: w);

    return Stack(children: [
      // A soft glow in the assignment's colour.
      Positioned(
        right: -80,
        top: -80,
        child: IgnorePointer(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1),
            duration: motion(context, 700),
            curve: Curves.easeOutBack,
            builder: (context, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [tint.fg.withValues(alpha: 0.18), tint.fg.withValues(alpha: 0)]),
              ),
            ),
          ),
        ),
      ),
      ListView(
        padding: EdgeInsets.fromLTRB(24, MediaQuery.paddingOf(context).top + 24, 24, MediaQuery.paddingOf(context).bottom + 32),
        children: [
          Row(children: [
            Transform.translate(
              offset: const Offset(-12, 0),
              child: IconButton(
                key: const Key('detail-back'),
                tooltip: 'Back',
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.chevron_left_rounded, color: c.ink, size: 28),
              ),
            ),
            const Spacer(),
            TextButton(
              key: const Key('detail-delete'),
              style: TextButton.styleFrom(foregroundColor: c.muted, textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              onPressed: () {
                final snap = state.snapshot();
                Navigator.pop(context);
                state.deleteTask(task.id);
                fb.say('Deleted — plan updated', undo: snap);
              },
              child: const Text('Delete'),
            ),
          ]),
          s(Row(children: [
            TintDot(color: tint.fg),
            const SizedBox(width: 8),
            Text('${formatMinutesLong(total)} · ${task.size.label}${task.stages.length > 1 ? ' · ${task.stages.length} stages' : ''}',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.muted)),
          ])),
          const SizedBox(height: 8),
          s(Text(task.title, style: Styles.display(c.ink))),
          const SizedBox(height: 4),
          s(Text(
            task.completed
                ? 'Handed in'
                : 'Due ${shortDate(task.dueDate)}, ${task.dueTime}${days > 1 ? ' · $days days' : days == 1 ? ' · tomorrow' : days == 0 ? ' · today' : ''}',
            style: TextStyle(fontWeight: FontWeight.w600, color: warning != null ? c.warn : c.muted),
          )),
          const SizedBox(height: 24),
          s(Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            RollText(formatMinutesLong(logged), style: Styles.h3(c.ink)),
            Text(' of ${formatMinutesLong(total)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: c.muted)),
            const Spacer(),
            Text(status, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: warning != null ? c.warn : c.accent)),
          ])),
          const SizedBox(height: 8),
          s(ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: total == 0 ? 0 : logged / total),
              duration: motion(context, 800),
              curve: smooth,
              builder: (context, v, _) => LinearProgressIndicator(value: v, minHeight: 6, color: tint.fg, backgroundColor: c.surfaceAlt),
            ),
          )),
          const SizedBox(height: 24),
          if (mascot != null)
            s(Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: mascot.$4, borderRadius: BorderRadius.circular(24)),
              child: Row(children: [
                Dodo(mood: mascot.$1, size: 64),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(mascot.$2, style: Styles.h3(mascot.$5)),
                    const SizedBox(height: 4),
                    Text(mascot.$3, style: TextStyle(fontSize: 14, height: 20 / 14, color: mascot.$5.withValues(alpha: 0.85))),
                  ]),
                ),
              ]),
            )),
          if (task.stages.length > 1) ...[
            s(const SectionLabel('Stages')),
            for (final st in task.stages)
              s(Pressable(
                scale: 0.98,
                onTap: task.completed ? null : () => showStageActions(context, state, task.id, st.id),
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
                  child: Row(children: [
                    CheckDot(done: task.completed || remainingMinutes(st, state.logs) == 0, color: tint.fg, size: 22),
                    const SizedBox(width: 14),
                    Expanded(child: Text(st.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                    Text('${formatMinutes(state.loggedFor(st.id))} of ${formatMinutes(st.minutes)}',
                        style: TextStyle(fontSize: 14, color: c.muted, fontFeatures: const [FontFeature.tabularFigures()])),
                  ]),
                ),
              )),
            const SizedBox(height: 16),
          ],
          s(const SectionLabel('Plan')),
          if (pieces.isEmpty && !task.completed)
            s(SizedBox(height: 56, child: Align(alignment: Alignment.centerLeft, child: Text('Nothing left to plan.', style: TextStyle(color: c.muted))))),
          // Timeline: a line threads each piece down to the hand-in flag.
          Stack(children: [
            Positioned(
              left: 69,
              top: 28,
              bottom: 28,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: motion(context, 700),
                curve: smooth,
                builder: (context, v, _) => Align(
                  alignment: Alignment.topCenter,
                  child: FractionallySizedBox(heightFactor: v, child: Container(width: 2, color: c.line)),
                ),
              ),
            ),
            Column(children: [
              for (final (date, item) in pieces)
                s(Pressable(
                  scale: 0.98,
                  onTap: () => showStageActions(context, state, task.id, item.stageId, plannedMinutes: date == today ? item.minutes : null),
                  child: SizedBox(
                    height: 64,
                    child: Row(children: [
                      SizedBox(
                        width: 56,
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(date == today ? 'TODAY' : shortDate(date).split(' ').first.toUpperCase(),
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.muted)),
                          Text('${dayOfMonth(date)}',
                              style: TextStyle(fontFamily: displayFont, fontWeight: FontWeight.w800, fontSize: 20, height: 1.2, color: date == today ? c.accent : c.ink)),
                        ]),
                      ),
                      SizedBox(
                        width: 28,
                        child: Center(
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(color: c.bg, shape: BoxShape.circle, border: Border.all(color: tint.fg, width: 2)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(task.stages.length > 1 ? item.stageName : 'Work', style: const TextStyle(fontWeight: FontWeight.w600))),
                      Text(formatMinutes(item.minutes), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.muted)),
                    ]),
                  ),
                )),
              s(SizedBox(
                height: 64,
                child: Row(children: [
                  const SizedBox(width: 56),
                  SizedBox(width: 28, child: Container(color: c.bg, child: Icon(Icons.flag_rounded, size: 18, color: tint.fg))),
                  const SizedBox(width: 8),
                  Text('Hand in ${shortDate(task.dueDate)}, ${task.dueTime}', style: TextStyle(fontWeight: FontWeight.w700, color: tint.fg)),
                ]),
              )),
            ]),
          ]),
          const SizedBox(height: 24),
          s(PillButton(
            key: const Key('hand-in'),
            kind: task.completed ? PillKind.soft : PillKind.ink,
            label: task.completed ? 'Not handed in yet' : 'Mark as handed in',
            onTap: () {
              final snap = state.snapshot();
              if (task.completed) {
                state.reopenTask(task.id);
                fb.say('Back on your plan', undo: snap);
                return;
              }
              HapticFeedback.mediumImpact();
              state.completeTask(task.id);
              fb.celebrate();
              fb.say('Handed in. Nice.', undo: snap, done: true);
              Future.delayed(motion(context, 600), () {
                if (context.mounted) Navigator.maybePop(context);
              });
            },
          )),
        ],
      ),
    ]);
  }
}
