import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/dates.dart';
import '../core/models.dart';
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
  late String _dueDate = addDays(widget.state.today, 7);
  String _dueTime = '09:00';
  TaskSize _size = TaskSize.medium;
  final List<_StageRow> _stages = [];
  String? _error;

  Future<void> _pickDate() async {
    final today = DateTime.parse(widget.state.today);
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
      setState(() => _dueTime =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
    }
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    String? error;
    if (title.isEmpty) {
      error = 'Give the assignment a name.';
    } else if ('${_dueDate}T$_dueTime'.compareTo('${widget.state.today}T${widget.state.nowTime}') <= 0) {
      error = 'That deadline has already passed. Pick a later day or time.';
    } else if (_stages.any((s) =>
        s.minutes.text.trim().isNotEmpty && (int.tryParse(s.minutes.text.trim()) ?? 0) <= 0)) {
      error = 'Stage minutes need to be a whole number, like 30.';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    final task = await widget.state.addTask(
      title: title,
      dueDate: _dueDate,
      dueTime: _dueTime,
      size: _size,
      stages: [for (final s in _stages) (s.name.text, int.tryParse(s.minutes.text.trim()))],
    );
    if (mounted) Navigator.pop(context, task);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final today = widget.state.today;
    final quickDays = [for (var i = 1; i <= 14; i++) addDays(today, i)];
    final pickedLater = !quickDays.contains(_dueDate);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text('New assignment', style: text.headlineSmall),
          const SizedBox(height: 16),
          TextField(
            key: const Key('title-field'),
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            decoration: const InputDecoration(hintText: 'What is it? e.g. History essay'),
          ),
          const SizedBox(height: 22),
          const SectionLabel('Due'),
          const SizedBox(height: 10),
          SizedBox(
            height: 64,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final d in quickDays)
                  _DatePill(
                    key: Key('due-$d'),
                    top: shortDate(d).split(' ').first,
                    bottom: '${dayOfMonth(d)}',
                    selected: d == _dueDate,
                    onTap: () => setState(() => _dueDate = d),
                  ),
                _DatePill(
                  key: const Key('due-later'),
                  top: pickedLater ? shortDate(_dueDate).split(' ').first : 'Later',
                  bottom: pickedLater ? '${dayOfMonth(_dueDate)}' : '…',
                  selected: pickedLater,
                  onTap: _pickDate,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in _dueTimes)
                ChoiceChip(
                  key: Key('time-$t'),
                  label: Text(t),
                  selected: _dueTime == t,
                  onSelected: (_) => setState(() => _dueTime = t),
                ),
              ChoiceChip(
                key: const Key('time-other'),
                label: Text(_dueTimes.contains(_dueTime) ? 'Other time' : _dueTime),
                selected: !_dueTimes.contains(_dueTime),
                onSelected: (_) => _pickTime(),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Due ${shortDate(_dueDate)} at $_dueTime', style: text.bodySmall),
          const SizedBox(height: 22),
          const SectionLabel('How big is it?'),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.3,
            children: [
              for (final s in TaskSize.values)
                _SizeCard(
                  key: Key('size-${s.name}'),
                  size: s,
                  selected: s == _size,
                  onTap: () => setState(() => _size = s),
                ),
            ],
          ),
          const SizedBox(height: 22),
          Row(children: [
            const Expanded(child: SectionLabel('Stages (optional)')),
            if (_stages.isEmpty)
              TextButton(
                key: const Key('stage-template'),
                onPressed: () => setState(() => _stages.addAll(_essayStages.map(_StageRow.new))),
                child: const Text('Research, Plan, Write, Edit'),
              ),
          ]),
          Text('Leave minutes blank to split the time evenly.', style: text.bodySmall),
          const SizedBox(height: 10),
          for (var i = 0; i < _stages.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    key: Key('stage-name-$i'),
                    controller: _stages[i].name,
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
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('add-stage'),
              onPressed: () => setState(() => _stages.add(_StageRow())),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Add stage'),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: c.danger, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 16),
          FilledButton(key: const Key('save-task'), onPressed: _save, child: const Text('Add to my week')),
        ],
      ),
    );
  }
}

class _DatePill extends StatelessWidget {
  const _DatePill({super.key, required this.top, required this.bottom, required this.selected, required this.onTap});

  final String top;
  final String bottom;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? c.accent : c.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            width: 52,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(top,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? c.onAccent : c.muted)),
                const SizedBox(height: 2),
                Text(bottom,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: selected ? c.onAccent : c.ink)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SizeCard extends StatelessWidget {
  const _SizeCard({super.key, required this.size, required this.selected, required this.onTap});

  final TaskSize size;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: selected ? c.accentSoft : c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: selected ? c.accent : c.line, width: selected ? 1.5 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(children: [
                Text(size.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(formatMinutesLong(size.minutes),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.muted)),
              ]),
              const SizedBox(height: 2),
              Text(_sizeHints[size]!,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: c.muted)),
            ],
          ),
        ),
      ),
    );
  }
}
