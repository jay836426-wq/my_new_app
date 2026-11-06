import 'task_export_screen.dart';
import '../services/account_planning_store.dart';

import 'package:flutter/material.dart';

import '../utils/planning_rules.dart';
import 'home_screen.dart';
import 'focus_timer_screen.dart';
import 'recently_deleted_screen.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key, this.calendarMode = false});
  final bool calendarMode;
  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  DateTime _selected = dayOnly(DateTime.now());
  late String _view;
  Map<String, List<TaskData>> _days = {};
  bool _loading = true;
  String? _error;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    _view = widget.calendarMode ? 'Month' : 'Week';
    load();
  }

  List<DateTime> get visibleDates {
    final start = _view == 'Month'
        ? DateTime(_selected.year, _selected.month, 1)
        : _view == 'Week'
        ? sundayOf(_selected)
        : _selected;
    final n = _view == 'Month'
        ? DateTime(start.year, start.month + 1, 0).day
        : _view == 'Week'
        ? 7
        : 1;
    return List.generate(
      n,
      (i) => DateTime(start.year, start.month, start.day + i),
    );
  }

  Future<void> load() async {
    final request = ++_request;
    if (mounted) setState(() => _loading = true);
    try {
      final store = await AccountPlanningStore.current();
      await store.prepareToday();
      final saved = await store.allSavedDays();
      final templates = await store.listState('recurringTasks');
      // Materialize visible days only. Empty calendar previews never overwrite history.
      final result = <String, List<TaskData>>{};
      for (final date in visibleDates) {
        final key = dayKey(date);
        result[key] = materializeDay(
          saved: saved[key] ?? [],
          templates: templates,
          date: key,
        );
      }
      if (mounted && request == _request) {
        setState(() {
          _days = result;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && request == _request) {
        setState(() {
          _error = 'Could not load the planner. Please retry.';
          _loading = false;
        });
      }
    }
  }

  void move(int delta) {
    setState(() {
      _selected = _view == 'Month'
          ? DateTime(_selected.year, _selected.month + delta, 1)
          : DateTime(
              _selected.year,
              _selected.month,
              _selected.day + (_view == 'Week' ? 7 : 1) * delta,
            );
    });
    load();
  }

  Future<void> manageDay([TaskData? task]) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HomeScreen(
          initialDate: dayKey(_selected),
          initialTaskId: task == null ? null : taskIdentity(task),
        ),
      ),
    );
    if (mounted) await load();
  }

  Future<void> exportData() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => TaskExportScreen(selected: _selected),
      ),
    );
  }

  Widget dayCell(DateTime date, {bool compact = false}) {
    final tasks = _days[dayKey(date)] ?? [];
    final done = tasks.where(isTaskComplete).length;
    final selected = dayKey(date) == dayKey(_selected);
    return InkWell(
      onTap: () => setState(() => _selected = date),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(compact ? 4 : 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF123525) : const Color(0xFF171A18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.greenAccent : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!compact)
              Text(
                const [
                  'Mon',
                  'Tue',
                  'Wed',
                  'Thu',
                  'Fri',
                  'Sat',
                  'Sun',
                ][date.weekday - 1],
                style: const TextStyle(fontSize: 11),
              ),
            Text(
              '${date.day}',
              style: TextStyle(
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: dayKey(date) == dayKey(DateTime.now())
                    ? Colors.greenAccent
                    : Colors.white,
              ),
            ),
            if (tasks.isNotEmpty)
              Icon(
                done == tasks.length ? Icons.check_circle : Icons.circle,
                size: compact ? 8 : 12,
                color: done == tasks.length ? Colors.greenAccent : Colors.amber,
              ),
            if (!compact)
              Text(
                '$done/${tasks.length}',
                style: const TextStyle(fontSize: 10),
              ),
          ],
        ),
      ),
    );
  }

  Widget _productivityCard(List<TaskData> tasks) {
    final done = tasks.where(isTaskComplete).length;
    final remaining = tasks.length - done;
    final today = dayKey(_selected) == dayKey(DateTime.now());
    Widget count(String label, int value, Color color) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF191B1A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_selected.month}/${_selected.day}/${_selected.year}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            today ? 'TODAY' : 'SELECTED DAY',
            style: const TextStyle(
              color: Colors.greenAccent,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            today ? 'Today’s productivity' : 'Daily productivity',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: count('Completed', done, Colors.greenAccent)),
              const SizedBox(width: 12),
              Expanded(child: count('Remaining', remaining, Colors.white)),
            ],
          ),
          const SizedBox(height: 18),
          LinearProgressIndicator(
            value: tasks.isEmpty ? 0 : done / tasks.length,
            color: Colors.greenAccent,
            backgroundColor: Colors.white12,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          const SizedBox(height: 8),
          Text(
            tasks.isEmpty
                ? 'No tasks planned'
                : '$done of ${tasks.length} completed',
            style: const TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 12),
          if (tasks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'A clear day. Tap “Plan this day” to add tasks.',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          for (final task in tasks)
            ListTile(
              contentPadding: EdgeInsets.zero,
              onTap: () => manageDay(task),
              leading: Icon(
                isTaskComplete(task)
                    ? Icons.check_circle
                    : task['status'] == 'In Progress'
                    ? Icons.timelapse
                    : Icons.radio_button_unchecked,
                color: isTaskComplete(task)
                    ? Colors.greenAccent
                    : task['status'] == 'In Progress'
                    ? Colors.amber
                    : Colors.white38,
              ),
              title: Text(
                task['title']?.toString() ?? 'Task',
                style: TextStyle(
                  color: isTaskComplete(task) ? Colors.white60 : Colors.white,
                ),
              ),
              subtitle: Text(
                isTaskComplete(task)
                    ? 'Completed'
                    : task['status'] == 'In Progress'
                    ? 'In progress'
                    : 'Not started',
                style: const TextStyle(color: Colors.white54),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.white38),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dates = visibleDates;
    final tasks = List<TaskData>.from(_days[dayKey(_selected)] ?? [])
      ..sort(
        (a, b) => (timeMinutes(a['startTime']) ?? 1440).compareTo(
          timeMinutes(b['startTime']) ?? 1440,
        ),
      );
    final totalMinutes = tasks.fold<int>(
      0,
      (v, t) => v + (taskDuration(t) ?? 0),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.calendarMode ? 'Calendar' : 'Planner'),
        actions: [
          IconButton(
            tooltip: 'Export tasks',
            onPressed: _loading ? null : exportData,
            icon: const Icon(Icons.ios_share),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              await Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => v == 'focus'
                      ? const FocusTimerScreen()
                      : const RecentlyDeletedScreen(),
                ),
              );
              if (mounted) load();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'focus', child: Text('Focus timer')),
              PopupMenuItem(value: 'trash', child: Text('Recently Deleted')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : () => manageDay(),
        icon: const Icon(Icons.edit_calendar),
        label: const Text('Plan this day'),
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Day', label: Text('Day')),
                ButtonSegment(value: 'Week', label: Text('Week')),
                ButtonSegment(value: 'Month', label: Text('Month')),
              ],
              selected: {_view},
              onSelectionChanged: (v) {
                setState(() => _view = v.first);
                load();
              },
            ),
            Row(
              children: [
                IconButton(
                  tooltip: 'Previous period',
                  onPressed: () => move(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _selected,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) {
                        setState(() => _selected = date);
                        load();
                      }
                    },
                    child: Text(
                      _view == 'Month'
                          ? '${_selected.month}/${_selected.year}'
                          : '${dates.first.month}/${dates.first.day} – ${dates.last.month}/${dates.last.day}',
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Next period',
                  onPressed: () => move(1),
                  icon: const Icon(Icons.chevron_right),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _selected = dayOnly(DateTime.now()));
                    load();
                  },
                  child: const Text('Today'),
                ),
              ],
            ),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) Text(_error!),
            const SizedBox(height: 12),
            if (_view == 'Week')
              SizedBox(
                height: 90,
                child: Row(
                  children: [
                    for (final d in dates)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: dayCell(d),
                        ),
                      ),
                  ],
                ),
              ),
            if (_view == 'Month') ...[
              Row(
                children: [
                  for (final name in ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                    Expanded(child: Center(child: Text(name))),
                ],
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 5,
                  crossAxisSpacing: 5,
                ),
                itemCount: dates.first.weekday % 7 + dates.length,
                itemBuilder: (_, i) {
                  final offset = i - (dates.first.weekday % 7);
                  return offset < 0
                      ? const SizedBox.shrink()
                      : dayCell(dates[offset], compact: true);
                },
              ),
            ],
            if (widget.calendarMode && !_loading && _error == null) ...[
              const SizedBox(height: 20),
              _productivityCard(tasks),
            ],
            if (!widget.calendarMode) ...[
              const SizedBox(height: 24),
              Text(
                '${_selected.month}/${_selected.day}/${_selected.year}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${tasks.length} tasks • ${totalMinutes ~/ 60}h ${totalMinutes % 60}m planned',
              ),
              const SizedBox(height: 12),
              if (tasks.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('A clear day. Tap “Plan this day” to add tasks.'),
                ),
              for (final task in tasks)
                Card(
                  child: ListTile(
                    onTap: () => manageDay(task),
                    leading: Icon(
                      isTaskComplete(task)
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: isTaskComplete(task)
                          ? Colors.greenAccent
                          : Colors.amber,
                    ),
                    title: Text(task['title']?.toString() ?? 'Task'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${task['startTime'] ?? 'Unscheduled'}${task['endTime'] == null ? '' : ' – ${task['endTime']}'}${taskDuration(task) == null ? '' : ' • ${taskDuration(task)} min'}',
                        ),
                        if (taskSubtasks(task).isNotEmpty)
                          Text(
                            '${taskSubtasks(task).where((s) => s['completed'] == true).length}/${taskSubtasks(task).length} steps',
                          ),
                        if (tasks.any(
                          (other) =>
                              !identical(other, task) &&
                              timeBlocksOverlap(task, other),
                        ))
                          const Text(
                            'Overlapping time block',
                            style: TextStyle(color: Colors.amber),
                          ),
                      ],
                    ),
                    trailing: IconButton(
                      tooltip: 'Focus on this task',
                      icon: const Icon(Icons.timer_outlined),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => FocusTimerScreen(
                            taskTitle: task['title']?.toString(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
