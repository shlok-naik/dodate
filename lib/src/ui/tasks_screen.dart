import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/dates.dart';
import '../core/models.dart';
import '../core/scheduler.dart';
import 'stage_actions.dart';
import 'theme.dart';
import 'widgets.dart';

const _limitChoices = [60, 120, 180, 240, 300];

/// All assignments with stage progress, plus the one setting (daily limit).
class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final c = context.colors;
        final tasks = [...state.tasks]
          ..sort((a, b) => '${a.dueDate}T${a.dueTime}'.compareTo('${b.dueDate}T${b.dueTime}'));
        final open = tasks.where((t) => !t.completed && remainingForTask(t, state.logs) > 0).toList();
        final finished = tasks.where((t) => !open.contains(t)).toList();

        return Scaffold(
          appBar: AppBar(title: const Text('Assignments')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(20)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Daily study limit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('Dodate won\'t plan more than this on one day.',
                      style: TextStyle(fontSize: 13, color: c.muted)),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final m in _limitChoices)
                      ChoiceChip(
                        key: Key('limit-$m'),
                        label: Text(formatMinutesLong(m)),
                        selected: state.dailyLimit == m,
                        onSelected: (_) => state.setDailyLimit(m),
                      ),
                    ChoiceChip(
                      key: const Key('change-limit'),
                      label: Text(_limitChoices.contains(state.dailyLimit)
                          ? 'Custom'
                          : formatMinutesLong(state.dailyLimit)),
                      selected: !_limitChoices.contains(state.dailyLimit),
                      onSelected: (_) async {
                        final m = await askMinutes(context, 'Daily limit', initial: state.dailyLimit);
                        if (m != null) await state.setDailyLimit(m);
                      },
                    ),
                  ]),
                ]),
              ),
              const SizedBox(height: 24),
              if (tasks.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text('No assignments yet. Add one from the week view.',
                      textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 15)),
                ),
              if (open.isNotEmpty) ...[
                const SectionLabel('Coming up'),
                const SizedBox(height: 10),
                for (final t in open) _TaskCard(state: state, task: t),
              ],
              if (finished.isNotEmpty) ...[
                const SizedBox(height: 12),
                const SectionLabel('Done'),
                const SizedBox(height: 10),
                for (final t in finished) _TaskCard(state: state, task: t),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.state, required this.task});

  final AppState state;
  final Task task;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final total = task.stages.fold(0, (a, s) => a + s.minutes);
    final left = task.completed ? 0 : remainingForTask(task, state.logs);
    final finished = left == 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 6, 10),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            TintBadge(taskId: task.id, title: task.title),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(task.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('Due ${shortDate(task.dueDate)}, ${task.dueTime} · ${task.size.label}',
                    style: TextStyle(fontSize: 13, color: c.muted)),
              ]),
            ),
            PopupMenuButton<String>(
              key: Key('menu-${task.id}'),
              icon: Icon(Icons.more_horiz_rounded, color: c.muted),
              onSelected: (v) => v == 'complete' ? state.completeTask(task.id) : state.deleteTask(task.id),
              itemBuilder: (_) => [
                if (!finished)
                  PopupMenuItem(key: Key('complete-${task.id}'), value: 'complete', child: const Text('Mark as handed in')),
                PopupMenuItem(key: Key('delete-${task.id}'), value: 'delete', child: const Text('Delete')),
              ],
            ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 10, 4),
            child: Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(value: total == 0 ? 1 : (total - left) / total),
                ),
              ),
              const SizedBox(width: 10),
              Text(finished ? 'Done' : '${formatMinutesLong(left)} left',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.muted)),
            ]),
          ),
          for (final s in task.stages)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: finished ? null : () => showStageActions(context, state, task.id, s.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  Icon(
                    remainingMinutes(s, state.logs) == 0 || task.completed
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 20,
                    color: remainingMinutes(s, state.logs) == 0 || task.completed ? c.accent : c.line,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(s.name, style: const TextStyle(fontSize: 15))),
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Text('${formatMinutes(state.loggedFor(s.id))} of ${formatMinutes(s.minutes)}',
                        style: TextStyle(
                            fontSize: 13,
                            color: c.muted,
                            fontFeatures: const [FontFeature.tabularFigures()])),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}
