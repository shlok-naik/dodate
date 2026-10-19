import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/dates.dart';
import '../core/models.dart';
import '../core/scheduler.dart';

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({super.key, required this.state});

  final AppState state;

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _StageRow {
  final name = TextEditingController();
  final minutes = TextEditingController();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _title = TextEditingController();
  late final _dueDate = TextEditingController(text: addDays(widget.state.today, 7));
  final _dueTime = TextEditingController(text: '09:00');
  TaskSize _size = TaskSize.medium;
  final List<_StageRow> _stages = [];
  String? _error;

  Future<void> _pickDate() async {
    final today = DateTime.parse(widget.state.today);
    final picked = await showDatePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      initialDate: DateTime.tryParse(_dueDate.text) ?? today,
    );
    if (picked != null) setState(() => _dueDate.text = dateOf(picked));
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
    if (picked != null) {
      setState(() => _dueTime.text =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
    }
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final date = _dueDate.text.trim();
    final time = _dueTime.text.trim();
    String? error;
    if (title.isEmpty) {
      error = 'Enter a title.';
    } else if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) || DateTime.tryParse(date) == null) {
      error = 'Due date must be YYYY-MM-DD.';
    } else if (!RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(time)) {
      error = 'Due time must be HH:MM.';
    } else if ('${date}T$time'.compareTo('${widget.state.today}T${widget.state.nowTime}') <= 0) {
      error = 'Due date is in the past.';
    } else if (_stages.any((s) =>
        s.minutes.text.trim().isNotEmpty && (int.tryParse(s.minutes.text.trim()) ?? 0) <= 0)) {
      error = 'Stage minutes must be a positive number.';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    final task = await widget.state.addTask(
      title: title,
      dueDate: date,
      dueTime: time,
      size: _size,
      stages: [for (final s in _stages) (s.name.text, int.tryParse(s.minutes.text.trim()))],
    );
    if (!mounted) return;
    // Warn straight away if the deadline can't be met.
    final warnings = widget.state.plan.warnings.where((w) => w.taskId == task.id).toList();
    if (warnings.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Warning'),
          content: Text(warnings.map((w) => w.message).join('\n\n')),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
        ),
      );
      if (!mounted) return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add assignment')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const Key('title-field'),
            controller: _title,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          Row(children: [
            Expanded(
              child: TextField(
                key: const Key('due-date-field'),
                controller: _dueDate,
                decoration: const InputDecoration(labelText: 'Due date (YYYY-MM-DD)'),
              ),
            ),
            TextButton(onPressed: _pickDate, child: const Text('Pick')),
          ]),
          Row(children: [
            Expanded(
              child: TextField(
                key: const Key('due-time-field'),
                controller: _dueTime,
                decoration: const InputDecoration(labelText: 'Due time (HH:MM)'),
              ),
            ),
            TextButton(onPressed: _pickTime, child: const Text('Pick')),
          ]),
          DropdownButton<TaskSize>(
            key: const Key('size-field'),
            value: _size,
            items: [
              for (final s in TaskSize.values)
                DropdownMenuItem(value: s, child: Text('${s.label} (about ${formatMinutes(s.minutes)})')),
            ],
            onChanged: (s) => setState(() => _size = s!),
          ),
          const Text('Stages (optional). Leave minutes blank to split the size\'s time equally.'),
          for (var i = 0; i < _stages.length; i++)
            Row(children: [
              Expanded(
                flex: 2,
                child: TextField(
                  key: Key('stage-name-$i'),
                  controller: _stages[i].name,
                  decoration: InputDecoration(labelText: 'Stage ${i + 1}'),
                ),
              ),
              Expanded(
                child: TextField(
                  key: Key('stage-minutes-$i'),
                  controller: _stages[i].minutes,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Minutes'),
                ),
              ),
              IconButton(
                tooltip: 'Remove stage',
                onPressed: () => setState(() => _stages.removeAt(i)),
                icon: const Icon(Icons.close),
              ),
            ]),
          TextButton(
            key: const Key('add-stage'),
            onPressed: () => setState(() => _stages.add(_StageRow())),
            child: const Text('Add stage'),
          ),
          if (_error != null) Text(_error!),
          ElevatedButton(key: const Key('save-task'), onPressed: _save, child: const Text('Save')),
          Text('Daily limit: ${formatMinutes(widget.state.dailyLimit)} '
              '(default ${formatMinutes(defaultDailyLimit)}, change it in Assignments)'),
        ],
      ),
    );
  }
}
