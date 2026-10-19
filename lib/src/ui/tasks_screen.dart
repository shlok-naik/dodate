import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/dates.dart';
import '../core/scheduler.dart';
import 'stage_actions.dart';

/// All assignments with stage progress, plus the one setting (daily limit).
class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final tasks = [...state.tasks]
          ..sort((a, b) => '${a.dueDate}T${a.dueTime}'.compareTo('${b.dueDate}T${b.dueTime}'));
        return Scaffold(
          appBar: AppBar(title: const Text('Assignments')),
          body: ListView(
            children: [
              ListTile(
                title: Text('Daily limit: ${formatMinutes(state.dailyLimit)}'),
                subtitle: const Text('Most study time Dodate plans for one day'),
                trailing: TextButton(
                  key: const Key('change-limit'),
                  onPressed: () async {
                    final m = await askMinutes(context, 'Daily limit in minutes',
                        initial: state.dailyLimit);
                    if (m != null) await state.setDailyLimit(m);
                  },
                  child: const Text('Change'),
                ),
              ),
              const Divider(),
              if (tasks.isEmpty) const ListTile(title: Text('No assignments yet')),
              for (final t in tasks) ...[
                ListTile(
                  title: Text(t.title),
                  subtitle: Text('Due ${dayLabel(t.dueDate)} ${t.dueTime} · ${t.size.label} · '
                      '${t.completed ? 'complete' : '${formatMinutes(remainingForTask(t, state.logs))} left'}'),
                ),
                for (final s in t.stages)
                  ListTile(
                    dense: true,
                    title: Text(s.name),
                    subtitle: Text('${formatMinutes(state.loggedFor(s.id))} done of '
                        '${formatMinutes(s.minutes)}${remainingMinutes(s, state.logs) == 0 ? ' (finished)' : ''}'),
                    onTap: t.completed ? null : () => showStageActions(context, state, t.id, s.id),
                  ),
                Row(children: [
                  if (!t.completed)
                    TextButton(
                      key: Key('complete-${t.id}'),
                      onPressed: () => state.completeTask(t.id),
                      child: const Text('Mark complete'),
                    ),
                  TextButton(
                    key: Key('delete-${t.id}'),
                    onPressed: () => state.deleteTask(t.id),
                    child: const Text('Delete'),
                  ),
                ]),
                const Divider(),
              ],
            ],
          ),
        );
      },
    );
  }
}
