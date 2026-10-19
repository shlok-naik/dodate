import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../core/dates.dart';
import 'theme.dart';
import 'widgets.dart';

/// Actions on one stage: done, log time, needs more time, finished early.
/// [plannedMinutes] is the session length when opened from a planned item.
Future<void> showStageActions(
  BuildContext context,
  AppState state,
  String taskId,
  String stageId, {
  int? plannedMinutes,
}) async {
  final task = state.taskById(taskId);
  final stage = state.stageById(taskId, stageId);
  if (task == null || stage == null) return;

  await showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) {
      final c = sheetContext.colors;
      final logged = state.loggedFor(stage.id);
      Widget option(Key key, IconData icon, String title, String subtitle, VoidCallback onTap) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: c.surface,
              borderRadius: BorderRadius.circular(16),
              child: ListTile(
                key: key,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                leading: Icon(icon, color: c.accent),
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(subtitle, style: TextStyle(color: c.muted)),
                onTap: onTap,
              ),
            ),
          );

      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          children: [
            Row(children: [
              TintBadge(taskId: task.id, title: task.title, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(task.title, style: TextStyle(fontSize: 14, color: c.muted)),
                  Text(stage.name, style: Theme.of(sheetContext).textTheme.headlineSmall),
                ]),
              ),
            ]),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: stage.minutes == 0 ? 0 : (logged / stage.minutes).clamp(0, 1)),
            ),
            const SizedBox(height: 6),
            Text('${formatMinutesLong(logged)} done of ${formatMinutesLong(stage.minutes)}',
                style: TextStyle(fontSize: 13, color: c.muted)),
            const SizedBox(height: 16),
            if (plannedMinutes != null)
              option(const Key('action-done'), Icons.check_circle_outline_rounded, 'Done',
                  'Log ${formatMinutesLong(plannedMinutes)} for today', () {
                HapticFeedback.lightImpact();
                Navigator.pop(sheetContext);
                state.logWork(taskId, stageId, plannedMinutes);
              }),
            option(const Key('action-log'), Icons.timer_outlined, 'I did some of it',
                'Log the minutes you worked today', () async {
              Navigator.pop(sheetContext);
              final m = await askMinutes(context, 'Minutes worked today');
              if (m != null) await state.logWork(taskId, stageId, m);
            }),
            option(const Key('action-more'), Icons.more_time_rounded, 'It needs more time',
                'Add time and rebalance the week', () async {
              Navigator.pop(sheetContext);
              final m = await askMinutes(context, 'Extra minutes needed');
              if (m != null) await state.addTime(taskId, stageId, m);
            }),
            option(const Key('action-finish'), Icons.done_all_rounded, 'This stage is finished',
                'Even if it took less time than planned', () {
              Navigator.pop(sheetContext);
              state.finishStage(taskId, stageId);
            }),
          ],
        ),
      );
    },
  );
}

Future<int?> askMinutes(BuildContext context, String label, {int? initial}) {
  final controller = TextEditingController(text: initial?.toString() ?? '');
  return showDialog<int>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(label),
      content: TextField(
        key: const Key('minutes-field'),
        controller: controller,
        keyboardType: TextInputType.number,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'e.g. 30', suffixText: 'min'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
        TextButton(
          key: const Key('minutes-ok'),
          onPressed: () {
            final m = int.tryParse(controller.text.trim());
            Navigator.pop(dialogContext, m != null && m > 0 ? m : null);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
