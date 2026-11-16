import 'package:flutter/material.dart';
import '../services/account_planning_store.dart';
import '../services/stopwatch_controller.dart';
import '../services/planning_store.dart';
import '../utils/stopwatch_session.dart';

Future<bool> startTaskStopwatch(
  BuildContext context,
  StopwatchController c, {
  required String title,
  String? taskId,
  String? taskDate,
  String? taskTitle,
}) async {
  final old = c.active;
  if (old != null) {
    final same = taskId == null || old.matchesTask(taskId, taskDate ?? '');
    if (same && !old.finalizing) {
      return old.running ? true : c.run(c.repo.resume);
    }
    final replace = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('A stopwatch is already open'),
        content: Text(
          'Save “${old.title}” before starting “$title”? Your current time will be kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Keep current'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Save & start new'),
          ),
        ],
      ),
    );
    if (replace != true || !await c.stopAndSave()) return false;
  }
  return c.run(
    () => c.repo.start(
      title: title,
      taskId: taskId,
      taskDate: taskDate,
      taskTitle: taskTitle,
    ),
  );
}

class StopwatchPanel extends StatefulWidget {
  const StopwatchPanel({
    super.key,
    required this.header,
    this.taskId,
    this.taskDate,
    this.taskTitle,
    this.autoStart = false,
    this.onLaunchConsumed,
  });
  final Widget header;
  final String? taskId, taskDate, taskTitle;
  final bool autoStart;
  final VoidCallback? onLaunchConsumed;
  @override
  State<StopwatchPanel> createState() => _StopwatchPanelState();
}

class _StopwatchPanelState extends State<StopwatchPanel> {
  StopwatchController? timer;
  String? error;
  late String nextTitle;
  @override
  void initState() {
    super.initState();
    nextTitle = widget.taskTitle ?? 'Stopwatch';
    load();
  }

  Future<void> load() async {
    try {
      final store = await AccountPlanningStore.current();
      final c = StopwatchController.forStore(store);
      await c.load();
      if (!mounted) return;
      setState(() => timer = c);
      if (widget.autoStart) {
        widget.onLaunchConsumed?.call();
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (mounted) {
            await startTaskStopwatch(
              context,
              c,
              title: nextTitle,
              taskId: widget.taskId,
              taskDate: widget.taskDate,
              taskTitle: widget.taskTitle,
            );
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not open your stopwatch. Please retry.');
      }
    }
  }

  Future<void> rename() async {
    final text = TextEditingController(text: timer!.active?.title ?? nextTitle);
    final value = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Name this session'),
        content: TextField(
          controller: text,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(hintText: 'Gym workout'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, text.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    text.dispose();
    if (value == null || value.trim().isEmpty) return;
    if (timer!.active != null) {
      await timer!.run(() => timer!.repo.rename(value));
    } else if (mounted) {
      setState(() => nextTitle = value.trim());
    }
  }

  Future<void> reset() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Reset stopwatch?'),
        content: const Text(
          'This discards the current unsaved time and laps. Previously saved sessions stay in history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Keep timing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (yes == true) await timer!.run(timer!.repo.reset);
  }

  @override
  Widget build(BuildContext context) {
    final c = timer;
    if (c == null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          widget.header,
          const SizedBox(height: 32),
          if (error == null)
            const Center(child: CircularProgressIndicator())
          else
            Text(error!),
          if (error != null)
            TextButton(onPressed: load, child: const Text('Retry')),
        ],
      );
    }
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final s = c.active;
        final finalizing = s?.finalizing ?? false;
        final reminderChoices = <int>{
          0,
          1,
          15,
          30,
          60,
          90,
          120,
          if (s?.reminderMinutes != null) s!.reminderMinutes!,
        }.toList()..sort();
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            widget.header,
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: c.busy || finalizing ? null : rename,
              icon: const Icon(Icons.edit_outlined),
              label: Text(
                s?.title ?? nextTitle,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (s?.taskId != null)
              Text(
                'Task: ${s!.taskTitle ?? s.title} · ${s.taskDate}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            const SizedBox(height: 24),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                c.preciseTime,
                style: const TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.bold,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              finalizing
                  ? 'Ready to save'
                  : s == null
                  ? 'Ready'
                  : s.running
                  ? 'Stopwatch running'
                  : 'Paused',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.greenAccent),
            ),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                if (!finalizing)
                  FilledButton.icon(
                    onPressed: c.busy || !c.loaded
                        ? null
                        : () => s == null
                              ? startTaskStopwatch(
                                  context,
                                  c,
                                  title: nextTitle,
                                  taskId: widget.taskId,
                                  taskDate: widget.taskDate,
                                  taskTitle: widget.taskTitle,
                                )
                              : c.run(s.running ? c.repo.pause : c.repo.resume),
                    icon: Icon(
                      s?.running == true ? Icons.pause : Icons.play_arrow,
                    ),
                    label: Text(
                      s?.running == true
                          ? 'Pause'
                          : s == null
                          ? 'Start Stopwatch'
                          : 'Resume',
                    ),
                  ),
                if (s != null)
                  FilledButton.icon(
                    onPressed: c.busy ? null : () => c.stopAndSave(),
                    icon: const Icon(Icons.save_outlined),
                    label: Text(
                      finalizing ? 'Retry Stop & Save' : 'Stop & Save',
                    ),
                  ),
                if (s?.running == true)
                  OutlinedButton(
                    onPressed: c.busy ? null : () => c.run(c.repo.lap),
                    child: const Text('Lap'),
                  ),
              ],
            ),
            if (s != null && !finalizing)
              TextButton(
                onPressed: c.busy ? null : reset,
                child: const Text('Reset'),
              ),
            const SizedBox(height: 20),
            if (s != null)
              DropdownButtonFormField<int>(
                initialValue: s.reminderMinutes ?? 0,
                key: ValueKey('${s.id}:${s.reminderMinutes}'),
                decoration: const InputDecoration(
                  labelText: 'Remind me to stop',
                ),
                items: [
                  for (final n in reminderChoices)
                    DropdownMenuItem(
                      value: n,
                      child: Text(
                        n == 0
                            ? 'Off'
                            : 'Every $n active minute${n == 1 ? '' : 's'}',
                      ),
                    ),
                ],
                onChanged: c.busy || finalizing
                    ? null
                    : (n) => c.run(() => c.repo.setReminder(n == 0 ? null : n)),
              ),
            const SizedBox(height: 12),
            const Text(
              'Check-ins don’t stop the stopwatch. Up to three reminders can arrive while you’re away; saving or pausing cancels them.',
              style: TextStyle(color: Colors.white70),
            ),
            if (c.repo.reminderNotice != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(c.repo.reminderNotice!),
              ),
            if (c.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  c.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (s != null && s.laps.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                'Laps',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              for (var i = s.laps.length - 1; i >= 0; i--)
                ListTile(
                  title: Text('Lap ${i + 1}'),
                  subtitle: Text(
                    'Total ${stopwatchTime(s.laps[i], centiseconds: true)}',
                  ),
                  trailing: Text(
                    stopwatchTime(
                      s.laps[i] - (i == 0 ? 0 : s.laps[i - 1]),
                      centiseconds: true,
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => StopwatchHistoryScreen(store: c.store),
                ),
              ),
              icon: const Icon(Icons.history),
              label: const Text('View saved sessions'),
            ),
          ],
        );
      },
    );
  }
}

class TaskStopwatchCard extends StatefulWidget {
  const TaskStopwatchCard({
    super.key,
    required this.store,
    required this.taskId,
    required this.taskDate,
    required this.onOpen,
  });
  final PlanningStore store;
  final String taskId, taskDate;
  final VoidCallback onOpen;
  @override
  State<TaskStopwatchCard> createState() => _TaskStopwatchCardState();
}

class _TaskStopwatchCardState extends State<TaskStopwatchCard> {
  late final StopwatchController c;
  @override
  void initState() {
    super.initState();
    c = StopwatchController.forStore(widget.store);
    c.load();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final records = c.repo.forTask(widget.taskId, widget.taskDate);
      final active =
          c.active?.matchesTask(widget.taskId, widget.taskDate) == true;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Time logged',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                '${stopwatchTime(c.repo.totalForTask(widget.taskId, widget.taskDate))} · ${records.length} saved sessions',
              ),
              if (active)
                Text(
                  'Current session: ${c.time} · ${c.active!.running ? 'Running' : 'Paused'}',
                ),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: !c.loaded || c.busy ? null : widget.onOpen,
                    icon: const Icon(Icons.av_timer),
                    label: Text(
                      active
                          ? (c.active!.finalizing
                                ? 'Finish saving'
                                : c.active!.running
                                ? 'Open Stopwatch'
                                : 'Resume Stopwatch')
                          : 'Start Stopwatch',
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => StopwatchHistoryScreen(
                          store: widget.store,
                          taskId: widget.taskId,
                          taskDate: widget.taskDate,
                        ),
                      ),
                    ),
                    child: const Text('View history'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class StopwatchHistoryScreen extends StatefulWidget {
  const StopwatchHistoryScreen({
    super.key,
    required this.store,
    this.taskId,
    this.taskDate,
  });
  final PlanningStore store;
  final String? taskId, taskDate;
  @override
  State<StopwatchHistoryScreen> createState() => _StopwatchHistoryState();
}

class _StopwatchHistoryState extends State<StopwatchHistoryScreen> {
  late final StopwatchController c;
  @override
  void initState() {
    super.initState();
    c = StopwatchController.forStore(widget.store);
    c.load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Saved stopwatch sessions')),
    body: ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        if (!c.loaded) {
          return Center(
            child: c.error == null
                ? const CircularProgressIndicator()
                : Text(c.error!),
          );
        }
        final records =
            (widget.taskId == null
                    ? c.repo.history
                    : c.repo.forTask(widget.taskId!, widget.taskDate!))
                .reversed
                .toList();
        if (records.isEmpty) {
          return const Center(
            child: Text('Stop & Save a session to see it here.'),
          );
        }
        return ListView.builder(
          itemCount: records.length,
          itemBuilder: (context, index) {
            final r = records[index];
            final laps = (r['laps'] as List? ?? [])
                .map((n) => (n as num).toInt())
                .toList();
            final at = DateTime.tryParse(
              r['endedAt']?.toString() ?? '',
            )?.toLocal();
            final date = at == null
                ? ''
                : MaterialLocalizations.of(context).formatMediumDate(at);
            return ExpansionTile(
              key: ValueKey(r['id']),
              title: Text(
                '${r['title']} · ${stopwatchTime((r['elapsedMs'] as num?)?.toInt() ?? 0)}',
              ),
              subtitle: Text(
                '$date${at == null ? '' : ' · ${TimeOfDay.fromDateTime(at).format(context)}'}${r['taskTitle'] == null ? '' : '\nTask: ${r['taskTitle']}'}',
              ),
              children: [
                if (laps.isEmpty)
                  const ListTile(title: Text('No laps recorded.')),
                for (var i = 0; i < laps.length; i++)
                  ListTile(
                    title: Text('Lap ${i + 1}'),
                    subtitle: Text(
                      'Total ${stopwatchTime(laps[i], centiseconds: true)}',
                    ),
                    trailing: Text(
                      stopwatchTime(
                        laps[i] - (i == 0 ? 0 : laps[i - 1]),
                        centiseconds: true,
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    ),
  );
}
