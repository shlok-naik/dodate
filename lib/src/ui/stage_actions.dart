import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/dates.dart';

/// Actions on one stage: done, log time, needs more time, finish early.
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
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: Text('${task.title}: ${stage.name}'),
            subtitle: Text(
                'Done ${formatMinutes(state.loggedFor(stage.id))} of ${formatMinutes(stage.minutes)}'),
          ),
          if (plannedMinutes != null)
            ListTile(
              key: const Key('action-done'),
              title: Text('Done (log ${formatMinutes(plannedMinutes)} today)'),
              onTap: () {
                Navigator.pop(sheetContext);
                state.logWork(taskId, stageId, plannedMinutes);
              },
            ),
          ListTile(
            key: const Key('action-log'),
            title: const Text('Log time worked today...'),
            onTap: () async {
              Navigator.pop(sheetContext);
              final m = await askMinutes(context, 'Minutes worked today');
              if (m != null) await state.logWork(taskId, stageId, m);
            },
          ),
          ListTile(
            key: const Key('action-more'),
            title: const Text('Needs more time...'),
            onTap: () async {
              Navigator.pop(sheetContext);
              final m = await askMinutes(context, 'Extra minutes needed');
              if (m != null) await state.addTime(taskId, stageId, m);
            },
          ),
          ListTile(
            key: const Key('action-finish'),
            title: const Text('Stage finished'),
            onTap: () {
              Navigator.pop(sheetContext);
              state.finishStage(taskId, stageId);
            },
          ),
        ],
      ),
    ),
  );
}

Future<int?> askMinutes(BuildContext context, String label, {int? initial}) {
  final controller = TextEditingController(text: initial?.toString() ?? '');
  return showDialog<int>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      content: TextField(
        key: const Key('minutes-field'),
        controller: controller,
        keyboardType: TextInputType.number,
        autofocus: true,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
        TextButton(
          key: const Key('minutes-ok'),
          onPressed: () {
            final m = int.tryParse(controller.text.trim());
            Navigator.pop(dialogContext, m != null && m > 0 ? m : null);
          },
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
