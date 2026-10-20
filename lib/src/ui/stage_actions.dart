import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../core/dates.dart';
import 'feedback.dart';
import 'settings_sheet.dart';
import 'task_detail_screen.dart';
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
  final fb = AppFeedback.of(context)..dismiss();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    sheetAnimationStyle: sheetMotion(context),
    builder: (sheetContext) {
      final c = sheetContext.colors;
      final tint = c.tintFor(task.id);
      final logged = state.loggedFor(stage.id);
      final left = (stage.minutes - logged).clamp(0, stage.minutes);
      final single = task.stages.length == 1;

      // Close the sheet, apply the change, and offer Undo.
      void act(String message, Future<void> Function() change) {
        final snap = state.snapshot();
        Navigator.pop(sheetContext);
        change();
        fb.say(message, undo: snap, done: true);
      }

      Widget row(Key key, String title, String hint, VoidCallback onTap) => Pressable(
            key: key,
            scale: 0.98,
            onTap: onTap,
            child: Container(
              height: 56,
              decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
              child: Row(children: [
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
                Text(hint, style: TextStyle(fontSize: 14, color: c.muted)),
              ]),
            ),
          );

      var i = 0;
      Widget s(Widget w) => Stagger(index: i++, child: w);

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            s(Align(
              alignment: Alignment.centerLeft,
              child: Pressable(
                key: const Key('action-open-task'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.of(context).push(taskDetailRoute(state, task.id));
                },
                child: SizedBox(
                  height: 40,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    TintDot(color: tint.fg),
                    const SizedBox(width: 8),
                    Text(single ? 'Due ${shortDate(task.dueDate)}, ${task.dueTime}' : task.title,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.muted)),
                    Icon(Icons.chevron_right_rounded, size: 18, color: c.muted),
                  ]),
                ),
              ),
            )),
            s(Text(single ? task.title : stage.name, style: Styles.h2(c.ink))),
            const SizedBox(height: 4),
            s(Text(
              '${formatMinutesLong(logged)} done of ${formatMinutesLong(stage.minutes)}${single ? '' : ' · due ${shortDate(task.dueDate)}'}',
              style: TextStyle(color: c.muted),
            )),
            const SizedBox(height: 16),
            s(ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: stage.minutes == 0 ? 0 : (logged / stage.minutes).clamp(0, 1)),
                duration: motion(sheetContext, 700),
                curve: smooth,
                builder: (context, v, _) => LinearProgressIndicator(value: v, minHeight: 6, color: tint.fg, backgroundColor: c.surfaceAlt),
              ),
            )),
            const SizedBox(height: 24),
            if (plannedMinutes != null)
              s(PillButton(
                key: const Key('action-done'),
                label: 'Done · ${formatMinutes(plannedMinutes)}',
                onTap: () {
                  HapticFeedback.lightImpact();
                  act('${formatMinutes(plannedMinutes)} done', () => state.logWork(taskId, stageId, plannedMinutes));
                },
              )),
            const SizedBox(height: 24),
            s(const SectionLabel('Worked a different amount today?')),
            const SizedBox(height: 8),
            s(Row(children: [
              for (final m in [15, 30, 45, 60]) ...[
                Expanded(
                  child: Pressable(
                    key: Key('log-$m'),
                    scale: 0.92,
                    onTap: () => act('${formatMinutes(m)} logged — rest replanned', () => state.logWork(taskId, stageId, m)),
                    child: Container(
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(24)),
                      child: Text(formatMinutes(m), style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
                if (m != 60) const SizedBox(width: 8),
              ],
            ])),
            const SizedBox(height: 16),
            s(Column(children: [
              row(const Key('action-log'), 'Another amount', 'type minutes', () async {
                Navigator.pop(sheetContext);
                final m = await askMinutes(context, 'Minutes worked today');
                if (m == null) return;
                final snap = state.snapshot();
                await state.logWork(taskId, stageId, m);
                fb.say('${formatMinutes(m)} logged — rest replanned', undo: snap, done: true);
              }),
              row(const Key('action-more'), 'Needs more time', 'add minutes', () async {
                Navigator.pop(sheetContext);
                final m = await askMinutes(context, 'Extra minutes needed');
                if (m == null) return;
                final snap = state.snapshot();
                await state.addTime(taskId, stageId, m);
                fb.say('+${formatMinutes(m)} added — plan updated', undo: snap);
              }),
              row(const Key('action-finish'), single ? 'Finished it early' : 'This stage is finished', left > 0 ? 'frees ${formatMinutes(left)}' : '',
                  () => act('Finished${left > 0 ? ' — ${formatMinutes(left)} freed up' : ''}', () => state.finishStage(taskId, stageId))),
            ])),
          ]),
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
