import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/dates.dart';
import 'add_task_screen.dart';
import 'stage_actions.dart';
import 'tasks_screen.dart';

/// Monday-to-Sunday view of what to do each day.
class WeekScreen extends StatefulWidget {
  const WeekScreen({super.key, required this.state});

  final AppState state;

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> {
  int _weekOffset = 0;

  AppState get state => widget.state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final today = state.today;
        final monday = addDays(mondayOf(today), 7 * _weekOffset);
        final warnings = state.plan.warnings;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Dodate'),
            actions: [
              TextButton(
                key: const Key('open-tasks'),
                onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => TasksScreen(state: state))),
                child: const Text('Assignments'),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            key: const Key('add-task'),
            tooltip: 'Add assignment',
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => AddTaskScreen(state: state))),
            child: const Icon(Icons.add),
          ),
          body: ListView(
            children: [
              for (final w in warnings) ListTile(title: Text('Warning: ${w.message}')),
              Row(
                children: [
                  TextButton(
                      key: const Key('prev-week'),
                      onPressed: () => setState(() => _weekOffset--),
                      child: const Text('Previous')),
                  TextButton(
                      onPressed: () => setState(() => _weekOffset = 0),
                      child: const Text('This week')),
                  TextButton(
                      key: const Key('next-week'),
                      onPressed: () => setState(() => _weekOffset++),
                      child: const Text('Next')),
                ],
              ),
              for (var i = 0; i < 7; i++) ..._day(context, addDays(monday, i), today),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _day(BuildContext context, String date, String today) {
    final entries = state.entriesFor(date);
    final total = entries.fold(0, (a, e) => a + e.item.minutes);
    final blocked = state.blockedDates.contains(date);
    final isPast = date.compareTo(today) < 0;
    return [
      ListTile(
        key: Key('day-$date'),
        title: Text('${dayLabel(date)}${date == today ? ' (today)' : ''}'),
        subtitle: Text(blocked ? 'Can\'t work this day' : 'Total ${formatMinutes(total)}'),
        trailing: isPast
            ? null
            : TextButton(
                key: Key('block-$date'),
                onPressed: () => state.toggleBlocked(date),
                child: Text(blocked ? 'Can work' : 'Can\'t work'),
              ),
      ),
      if (entries.isEmpty) const ListTile(dense: true, title: Text('Nothing planned')),
      for (final e in entries)
        ListTile(
          dense: true,
          title: Text('${e.item.taskTitle}: ${e.item.stageName}'),
          subtitle: Text(switch (e.status) {
            EntryStatus.planned => formatMinutes(e.item.minutes),
            EntryStatus.done => 'Done ${formatMinutes(e.loggedMinutes)}',
            EntryStatus.missed => 'Missed ${formatMinutes(e.item.minutes)}, moved to later days',
          }),
          onTap: e.status == EntryStatus.planned
              ? () => showStageActions(context, state, e.item.taskId, e.item.stageId,
                  plannedMinutes: e.item.minutes)
              : null,
        ),
      const Divider(),
    ];
  }
}
