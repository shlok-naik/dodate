import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/dates.dart';
import '../core/models.dart';
import '../core/scheduler.dart';
import 'dodo.dart';
import 'feedback.dart';
import 'settings_sheet.dart';
import 'theme.dart';
import 'widgets.dart';

const _sizeHints = {
  TaskSize.quick: 'A worksheet',
  TaskSize.medium: 'A homework set',
  TaskSize.big: 'An essay or report',
  TaskSize.huge: 'A project or coursework',
};

const _dueTimes = ['09:00', '13:00', '17:00', '23:59'];
const _essayStages = ['Research', 'Plan', 'Write', 'Edit'];

/// Opens the add-assignment sheet, then confirms or warns if it won't fit.
Future<void> showAddTaskSheet(BuildContext context, AppState state) async {
  final fb = AppFeedback.of(context)..dismiss();
  final snap = state.snapshot();
  final task = await showModalBottomSheet<Task>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    sheetAnimationStyle: sheetMotion(context),
    builder: (_) => AddTaskSheet(state: state),
  );
  if (task == null || !context.mounted) return;
  final warning = state.plan.warnings.where((w) => w.taskId == task.id).firstOrNull;
  if (warning == null) {
    final days = state.plan.days.values.where((items) => items.any((i) => i.taskId == task.id)).length;
    fb.say('${task.title} added — ${days <= 1 ? 'one go' : 'spread over $days days'}', undo: snap, done: true);
    return;
  }
  await showWontFit(context, state, task.id);
}

/// "This won't fit": offers to raise the daily limit just enough.
Future<void> showWontFit(BuildContext context, AppState state, String taskId) {
  final fb = AppFeedback.of(context);
  final warning = state.plan.warnings.firstWhere((w) => w.taskId == taskId);
  final limit = state.limitToFit(taskId);
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: context.colors.scrim,
    transitionDuration: motion(context, 380),
    transitionBuilder: (context, a, _, child) => FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.15), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)),
        child: child,
      ),
    ),
    pageBuilder: (dialogContext, a1, a2) {
      final c = dialogContext.colors;
      return SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Material(
              color: c.bg,
              borderRadius: BorderRadius.circular(32),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Align(alignment: Alignment.centerLeft, child: Dodo(mood: DodoMood.sweat, size: 96)),
                  const SizedBox(height: 8),
                  Text(warning.headline, style: Styles.h2(c.ink)),
                  const SizedBox(height: 8),
                  Text(warning.message, style: TextStyle(color: c.muted)),
                  const SizedBox(height: 24),
                  if (limit != null) ...[
                    PillButton(
                      key: const Key('wontfit-raise'),
                      label: 'Allow ${formatMinutesLong(limit)} a day',
                      onTap: () {
                        final snap = state.snapshot();
                        Navigator.pop(dialogContext);
                        state.setDailyLimit(limit);
                        fb.say('Daily limit is now ${formatMinutesLong(limit)}', undo: snap);
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                  TextButton(
                    key: const Key('wontfit-keep'),
                    style: TextButton.styleFrom(foregroundColor: c.muted, minimumSize: const Size.fromHeight(48)),
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Keep it anyway', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Bottom sheet for a new assignment. Pops with the created [Task].
class AddTaskSheet extends StatefulWidget {
  const AddTaskSheet({super.key, required this.state});

  final AppState state;

  @override
  State<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _StageRow {
  _StageRow([String name = '']) : name = TextEditingController(text: name);
  final TextEditingController name;
  final minutes = TextEditingController();
}

class _AddTaskSheetState extends State<AddTaskSheet> {
  final _title = TextEditingController();
  late String _dueDate = addDays(widget.state.today, 3);
  String _dueTime = '09:00';
  TaskSize _size = TaskSize.medium;
  final List<_StageRow> _stages = [];
  String? _error;
  int _shake = 0;

  AppState get state => widget.state;

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
  }

  Future<void> _pickDate() async {
    final today = DateTime.parse(state.today);
    final picked = await showDatePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      initialDate: DateTime.parse(_dueDate),
    );
    if (picked != null) setState(() => _dueDate = dateOf(picked));
  }

  Future<void> _pickTime() async {
    final parts = _dueTime.split(':').map(int.parse).toList();
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: parts[0], minute: parts[1]));
    if (picked != null) {
      setState(() => _dueTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
    }
  }

  List<(String, int?)> get _stageInput => [for (final s in _stages) (s.name.text, int.tryParse(s.minutes.text.trim()))];

  Future<void> _save() async {
    final title = _title.text.trim();
    String? error;
    if (title.isEmpty) {
      error = 'Give the assignment a name.';
    } else if ('${_dueDate}T$_dueTime'.compareTo('${state.today}T${state.nowTime}') <= 0) {
      error = 'That deadline has already passed. Pick a later day or time.';
    } else if (_stages.any((s) => s.minutes.text.trim().isNotEmpty && (int.tryParse(s.minutes.text.trim()) ?? 0) <= 0)) {
      error = 'Stage minutes need to be a whole number, like 30.';
    }
    if (error != null) {
      setState(() {
        _error = error;
        _shake++;
      });
      return;
    }
    final task = await state.addTask(title: title, dueDate: _dueDate, dueTime: _dueTime, size: _size, stages: _stageInput);
    if (mounted) Navigator.pop(context, task);
  }

  /// How the draft would be split, without saving it.
  (Map<String, int>, PlanWarning?) _preview() {
    final named = _stageInput.where((s) => s.$1.trim().isNotEmpty).toList();
    final minutes = splitStageMinutes(_size.minutes, [for (final s in named) s.$2]);
    final draft = Task(
      id: '__draft',
      title: _title.text.trim().isEmpty ? 'This' : _title.text.trim(),
      dueDate: _dueDate,
      dueTime: _dueTime,
      size: _size,
      stages: [
        for (var i = 0; i < minutes.length; i++) Stage(id: '__s$i', name: named.isEmpty ? 'Work' : named[i].$1, minutes: minutes[i])
      ],
      createdAt: DateTime.now().toIso8601String(),
    );
    final p = buildPlan(
      tasks: [...state.tasks, draft],
      logs: state.logs,
      today: state.today,
      nowTime: state.nowTime,
      dailyLimit: state.dailyLimit,
      blockedDates: state.blockedDates,
    );
    final per = <String, int>{};
    p.days.forEach((d, items) {
      final m = items.where((i) => i.taskId == '__draft').fold(0, (a, i) => a + i.minutes);
      if (m > 0) per[d] = m;
    });
    return (per, p.warnings.where((w) => w.taskId == '__draft').firstOrNull);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final today = state.today;
    final quickDays = [for (var i = 1; i <= 7; i++) addDays(today, i)];
    final pickedLater = !quickDays.contains(_dueDate);
    final has = _title.text.trim().isNotEmpty;
    final (per, warning) = _preview();
    final pieces = per.length;
    final barColor = c.tints[state.tasks.length % c.tints.length].fg;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 16, 0),
          child: Row(children: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: c.muted, textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            const Spacer(),
            Pressable(
              key: const Key('save-task'),
              label: 'Add',
              onTap: _save,
              child: AnimatedContainer(
                duration: motion(context, 200),
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: has ? c.accent : c.surfaceAlt, borderRadius: BorderRadius.circular(20)),
                child: Text('Add', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: has ? c.onAccent : c.muted)),
              ),
            ),
          ]),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            children: [
              TweenAnimationBuilder<double>(
                key: ValueKey(_shake),
                tween: Tween(begin: _shake == 0 ? 1 : 0, end: 1),
                duration: motion(context, 400),
                builder: (context, v, child) =>
                    Transform.translate(offset: Offset(math.sin(v * math.pi * 5) * 8 * (1 - v), 0), child: child),
                child: TextField(
                  key: const Key('title-field'),
                  controller: _title,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  cursorColor: c.accent,
                  style: Styles.h2(c.ink),
                  decoration: InputDecoration(
                    filled: false,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'What’s the homework?',
                    hintStyle: Styles.h2(c.disabled),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              _Label('Due', '${shortDate(_dueDate)}, $_dueTime'),
              const SizedBox(height: 8),
              SlidingChips<String>(
                keyPrefix: 'due',
                height: 64,
                value: pickedLater ? null : _dueDate,
                onPick: (d) => setState(() => _dueDate = d),
                options: [
                  for (final (i, d) in quickDays.indexed)
                    (
                      d,
                      Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(i == 0 ? 'Tmrw' : shortDate(d).split(' ').first,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 16 / 12)),
                        Text('${dayOfMonth(d)}'),
                      ]),
                      '${weekdayName(d)} ${dayOfMonth(d)}',
                    ),
                ],
              ),
              _RowButton(
                key: const Key('due-later'),
                on: pickedLater,
                label: 'Another date',
                value: pickedLater ? shortDate(_dueDate) : '',
                icon: Icons.calendar_today_rounded,
                onTap: _pickDate,
              ),
              const SizedBox(height: 12),
              SlidingChips<String>(
                keyPrefix: 'time',
                height: 44,
                value: _dueTimes.contains(_dueTime) ? _dueTime : 'other',
                onPick: (t) => t == 'other' ? _pickTime() : setState(() => _dueTime = t),
                options: [
                  for (final t in _dueTimes) (t, Text(t, style: const TextStyle(fontSize: 14)), 'Due at $t'),
                  ('other', Text(_dueTimes.contains(_dueTime) ? 'Other' : _dueTime, style: const TextStyle(fontSize: 14)), 'Other time'),
                ],
              ),
              const SizedBox(height: 32),
              _Label('How big is it?', _sizeHints[_size]!),
              const SizedBox(height: 8),
              SlidingChips<String>(
                keyPrefix: 'size',
                height: 64,
                value: _size.name,
                onPick: (n) => setState(() => _size = TaskSize.values.byName(n)),
                options: [
                  for (final s in TaskSize.values)
                    (
                      s.name,
                      Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(s.label),
                        Text(formatMinutes(s.minutes), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 16 / 12)),
                      ]),
                      '${s.label}, ${formatMinutesLong(s.minutes)}',
                    ),
                ],
              ),
              const SizedBox(height: 32),
              Row(children: [
                const Expanded(child: SectionLabel('Stages (optional)')),
                if (_stages.isEmpty)
                  TextButton(
                    key: const Key('stage-template'),
                    onPressed: () => setState(() => _stages.addAll(_essayStages.map(_StageRow.new))),
                    child: const Text('Research, Plan, Write, Edit'),
                  ),
              ]),
              Text('Leave minutes blank to split the time evenly.', style: TextStyle(fontSize: 14, color: c.muted)),
              const SizedBox(height: 8),
              _MaybeAnimatedSize(
                child: Column(children: [
                  for (var i = 0; i < _stages.length; i++)
                    Stagger(
                      key: ObjectKey(_stages[i]),
                      index: i,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              key: Key('stage-name-$i'),
                              controller: _stages[i].name,
                              onChanged: (_) => setState(() {}),
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(hintText: 'Stage ${i + 1}'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              key: Key('stage-minutes-$i'),
                              controller: _stages[i].minutes,
                              onChanged: (_) => setState(() {}),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(hintText: 'Auto', suffixText: 'min'),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove stage',
                            onPressed: () => setState(() => _stages.removeAt(i)),
                            icon: Icon(Icons.close_rounded, color: c.muted),
                          ),
                        ]),
                      ),
                    ),
                ]),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('add-stage'),
                  onPressed: () => setState(() => _stages.add(_StageRow())),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Add stage'),
                ),
              ),
              AnimatedSwitcher(
                duration: motion(context, 200),
                child: _error == null
                    ? const SizedBox.shrink()
                    : Padding(
                        key: ValueKey(_error),
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(_error!, style: TextStyle(color: c.danger, fontWeight: FontWeight.w600)),
                      ),
              ),
              // Live preview of how the work gets split across the days.
              Container(
                margin: const EdgeInsets.only(top: 24),
                padding: const EdgeInsets.only(top: 24),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Dodo(mood: warning != null ? DodoMood.sweat : DodoMood.write, size: 56),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        AnimatedSwitcher(
                          duration: motion(context, 180),
                          layoutBuilder: (cur, prev) => Stack(alignment: Alignment.centerLeft, children: [...prev, if (cur != null) cur]),
                          child: Text(
                            warning != null
                                ? 'Won’t fit — ${formatMinutes(warning.shortfall)} over your limit'
                                : pieces <= 1
                                    ? 'Done in one go'
                                    : 'Split over $pieces days',
                            key: ValueKey('$pieces-${warning?.shortfall}'),
                            style: TextStyle(fontWeight: FontWeight.w700, color: warning != null ? c.warn : c.ink),
                          ),
                        ),
                        Text(
                          warning != null
                              ? 'Pick a later date or a smaller size.'
                              : pieces > 1
                                  ? 'About ${formatMinutes((_size.minutes / pieces / 15).round() * 15)} a day, around your other homework.'
                                  : 'Fits around your other homework.',
                          style: TextStyle(fontSize: 14, color: c.muted),
                        ),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  _PreviewBars(state: state, per: per, dueDate: _dueDate, color: warning != null ? c.warnBar : barColor),
                ]),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _PreviewBars extends StatelessWidget {
  const _PreviewBars({required this.state, required this.per, required this.dueDate, required this.color});

  final AppState state;
  final Map<String, int> per;
  final String dueDate;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final n = math.max(1, math.min(diffDays(state.today, dueDate) + 1, 14));
    final mx = math.max(30, per.values.fold(0, math.max));
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      for (var b = 0; b < n; b++) ...[
        if (b > 0) const SizedBox(width: 4),
        Expanded(
          child: Builder(builder: (context) {
            final d = addDays(state.today, b);
            final m = per[d] ?? 0;
            return Column(children: [
              SizedBox(
                height: 48,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: AnimatedContainer(
                    duration: motion(context, 380 + b * 20),
                    curve: Curves.easeOutBack,
                    height: m > 0 ? math.max(8, m / mx * 48) : 4,
                    decoration: BoxDecoration(color: m > 0 ? color : c.line, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                b == 0
                    ? 'Tod'
                    : n > 10
                        ? weekdayInitial(d)
                        : '${weekdayInitial(d)}${dayOfMonth(d)}',
                maxLines: 1,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.muted),
              ),
            ]);
          }),
        ),
      ],
    ]);
  }
}

class _Label extends StatelessWidget {
  const _Label(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 32,
      child: Row(children: [
        Text(label.toUpperCase(), style: Styles.kicker(c.muted)),
        const Spacer(),
        RollText(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.ink)),
      ]),
    );
  }
}

class _RowButton extends StatelessWidget {
  const _RowButton({super.key, required this.on, required this.label, required this.value, required this.icon, required this.onTap});

  final bool on;
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Pressable(
        scale: 0.98,
        onTap: onTap,
        child: AnimatedContainer(
          duration: motion(context, 200),
          height: 56,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          decoration: BoxDecoration(color: on ? c.chipOn : c.surfaceAlt, borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: on ? c.chipOnInk : c.ink))),
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: on ? c.chipOnInk : c.muted)),
            const SizedBox(width: 8),
            Icon(icon, size: 18, color: on ? c.chipOnInk : c.muted),
          ]),
        ),
      ),
    );
  }
}

/// AnimatedSize, except when animations are off (it can't run at zero length).
class _MaybeAnimatedSize extends StatelessWidget {
  const _MaybeAnimatedSize({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final d = motion(context, 260);
    if (d == Duration.zero) return child;
    return AnimatedSize(duration: d, curve: smooth, alignment: Alignment.topCenter, child: child);
  }
}
