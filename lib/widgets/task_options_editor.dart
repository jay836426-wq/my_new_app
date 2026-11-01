import 'package:flutter/material.dart';

import '../utils/planning_rules.dart';

class TaskOptionsEditor extends StatefulWidget {
  const TaskOptionsEditor({
    super.key,
    required this.value,
    required this.repeat,
    required this.onChanged,
  });
  final TaskData value;
  final String repeat;
  final ValueChanged<TaskData> onChanged;
  @override
  State<TaskOptionsEditor> createState() => _TaskOptionsEditorState();
}

class _TaskOptionsEditorState extends State<TaskOptionsEditor> {
  final _newSubtask = TextEditingController();
  late TaskData _value;
  late final TextEditingController _duration;
  late final TextEditingController _interval;
  @override
  void initState() {
    super.initState();
    _value = copyTask(widget.value);
    _duration = TextEditingController(
      text: widget.value['durationMinutes']?.toString() ?? '',
    );
    _interval = TextEditingController(
      text: (widget.value['repeatInterval'] ?? 1).toString(),
    );
  }

  @override
  void dispose() {
    _newSubtask.dispose();
    _duration.dispose();
    _interval.dispose();
    super.dispose();
  }

  void update(TaskData changes) {
    _value = {..._value, ...changes};
    widget.onChanged(copyTask(_value));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final subs = taskSubtasks(_value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        TextField(
          controller: _duration,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Duration in minutes (optional)',
            helperText: 'With a start time, duration sets the end time.',
          ),
          onChanged: (v) => update({
            'durationMinutes': v.trim().isEmpty ? null : int.tryParse(v) ?? 0,
          }),
        ),
        if (widget.repeat == 'Every N Days' || widget.repeat == 'Every N Weeks')
          TextField(
            controller: _interval,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: widget.repeat == 'Every N Days'
                  ? 'Repeat every N days'
                  : 'Repeat every N weeks',
            ),
            onChanged: (v) => update({'repeatInterval': int.tryParse(v) ?? 0}),
          ),
        if (widget.repeat != 'Never')
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              _value['repeatUntil'] == null
                  ? 'Repeat with no end date'
                  : 'Repeat through ${_value['repeatUntil']}',
            ),
            trailing: _value['repeatUntil'] == null
                ? const Icon(Icons.event)
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => update({'repeatUntil': null}),
                  ),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (date != null && mounted) {
                update({'repeatUntil': dayKey(date)});
              }
            },
          ),
        const SizedBox(height: 12),
        const Text('Subtasks', style: TextStyle(fontWeight: FontWeight.bold)),
        for (var i = 0; i < subs.length; i++)
          Row(
            children: [
              Expanded(child: Text(subs[i]['title']?.toString() ?? '')),
              IconButton(
                tooltip: 'Remove subtask',
                icon: const Icon(Icons.close),
                onPressed: () {
                  subs.removeAt(i);
                  update({'subtasks': subs});
                },
              ),
            ],
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _newSubtask,
                decoration: const InputDecoration(labelText: 'Add a step'),
                onSubmitted: (_) => addSubtask(),
              ),
            ),
            IconButton(
              tooltip: 'Add subtask',
              icon: const Icon(Icons.add_circle_outline),
              onPressed: addSubtask,
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  void addSubtask() {
    final title = _newSubtask.text.trim();
    if (title.isEmpty) return;
    final subs = taskSubtasks(_value);
    subs.add({
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'title': title,
      'completed': false,
    });
    _newSubtask.clear();
    update({'subtasks': subs});
  }
}
