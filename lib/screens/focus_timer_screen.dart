import 'notification_service.dart';
import '../widgets/stopwatch_panel.dart';
import 'package:flutter/material.dart';
import '../services/account_planning_store.dart';
import '../services/focus_timer_controller.dart';

class FocusTimerScreen extends StatefulWidget {
  const FocusTimerScreen({
    super.key,
    this.taskTitle,
    this.initialMode,
    this.autoStart = false,
    this.stopwatchTaskId,
    this.stopwatchTaskDate,
    this.stopwatchTaskTitle,
  });
  final String? taskTitle, initialMode;
  final bool autoStart;
  final String? stopwatchTaskId, stopwatchTaskDate, stopwatchTaskTitle;
  @override
  State<FocusTimerScreen> createState() => _FocusTimerScreenState();
}

class _FocusTimerScreenState extends State<FocusTimerScreen> {
  FocusTimerController? timer;
  String? loadError;
  late bool _showStopwatch;
  bool _stopwatchLaunchConsumed = false;
  VoidCallback? _previousStopwatchOpen;
  @override
  void initState() {
    super.initState();
    _previousStopwatchOpen = NotificationService.onOpenStopwatch;
    NotificationService.onOpenStopwatch = _openStopwatchNotice;
    _showStopwatch = widget.initialMode == 'Stopwatch';
    load();
  }

  void _openStopwatchNotice() {
    final route = mounted ? ModalRoute.of(context) : null;
    if (mounted && route?.isActive == true) {
      Navigator.of(context).popUntil((candidate) => candidate == route);
      NotificationService.pendingStopwatchOpen = false;
      setState(() => _showStopwatch = true);
    } else {
      _previousStopwatchOpen?.call();
    }
  }

  @override
  void dispose() {
    if (NotificationService.onOpenStopwatch == _openStopwatchNotice) {
      NotificationService.onOpenStopwatch = _previousStopwatchOpen;
    }
    super.dispose();
  }

  Future<void> load() async {
    try {
      final store = await AccountPlanningStore.current();
      final controller = FocusTimerController.forStore(store);
      await controller.load();
      if (widget.taskTitle != null) {
        await controller.nameFromTask(widget.taskTitle!);
      }
      if (widget.initialMode != null &&
          widget.initialMode != 'Stopwatch' &&
          controller.clock?.running != true &&
          !controller.paused) {
        await controller.configure(
          widget.initialMode!,
          startImmediately: widget.autoStart,
        );
      }
      if (mounted) setState(() => timer = controller);
    } catch (_) {
      if (mounted) {
        setState(() => loadError = 'Could not open the timer. Please retry.');
      }
    }
  }

  Future<bool> confirmReset() async {
    if (timer!.clock?.running != true && !timer!.paused) return true;
    return await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Replace this session?'),
            content: const Text(
              'This will stop the current timer and start a new session setup.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Keep session'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Replace'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> configure(String mode, {int? minutes}) async {
    if (await confirmReset()) await timer!.configure(mode, minutes: minutes);
  }

  Future<void> rename() async {
    final text = TextEditingController(text: timer!.clock!.title);
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Name this session'),
        content: TextField(
          controller: text,
          autofocus: true,
          maxLength: 80,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: '5-minute rest from studying',
          ),
          onSubmitted: (v) => Navigator.pop(c, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, text.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    text.dispose();
    if (name != null) await timer!.rename(name);
  }

  Future<void> custom() async {
    final text = TextEditingController(
      text: (timer!.clock!.durationSeconds ~/ 60).toString(),
    );
    final minutes = await showDialog<int>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Session length'),
        content: TextField(
          controller: text,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Minutes (1–180)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(text.text);
              if (n != null && n >= 1 && n <= 180) Navigator.pop(c, n);
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
    text.dispose();
    if (minutes != null) await configure(timer!.clock!.mode, minutes: minutes);
  }

  Future<void> _chooseTool(String mode) async {
    if (mode == 'Stopwatch') {
      setState(() => _showStopwatch = true);
      return;
    }
    if (timer == null) return;
    if (timer!.clock?.mode != mode) {
      if (!await confirmReset()) return;
      await timer!.configure(mode);
    }
    if (mounted) setState(() => _showStopwatch = false);
  }

  Widget _tools() => Wrap(
    alignment: WrapAlignment.center,
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final mode in ['Focus', 'Break', 'Stopwatch'])
        ChoiceChip(
          label: Text(mode),
          selected: _showStopwatch
              ? mode == 'Stopwatch'
              : timer?.clock?.mode == mode,
          onSelected: timer?.busy == true ? null : (_) => _chooseTool(mode),
        ),
    ],
  );
  @override
  Widget build(BuildContext context) {
    final t = timer;
    return Scaffold(
      appBar: AppBar(title: const Text('Timers & Stopwatch')),
      body: _showStopwatch
          ? StopwatchPanel(
              header: _tools(),
              taskId: widget.stopwatchTaskId,
              taskDate: widget.stopwatchTaskDate,
              taskTitle: widget.stopwatchTaskTitle,
              autoStart: widget.autoStart && !_stopwatchLaunchConsumed,
              onLaunchConsumed: () => _stopwatchLaunchConsumed = true,
            )
          : t == null
          ? Center(
              child: loadError == null
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(loadError!),
                        TextButton(onPressed: load, child: const Text('Retry')),
                      ],
                    ),
            )
          : ListenableBuilder(
              listenable: t,
              builder: (context, _) {
                final c = t.clock;
                if (c == null) {
                  return Center(child: Text(t.error ?? 'Loading timer…'));
                }
                final accent = c.mode == 'Break'
                    ? Colors.cyanAccent
                    : Colors.greenAccent;
                return ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    _tools(),
                    const SizedBox(height: 24),
                    Semantics(
                      button: true,
                      label: 'Rename ${t.sessionName}',
                      child: InkWell(
                        onTap: t.busy ? null : rename,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  t.sessionName,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 23,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Icon(Icons.edit_outlined),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Text(
                      'Tap the name to personalize this session',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 240,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 230,
                            height: 230,
                            child: CircularProgressIndicator(
                              value: t.remaining / c.durationSeconds,
                              strokeWidth: 10,
                              color: accent,
                              backgroundColor: Colors.white12,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                t.timeLabel,
                                style: const TextStyle(
                                  fontSize: 52,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                t.complete
                                    ? 'Complete'
                                    : c.running
                                    ? '${c.mode} in progress'
                                    : t.paused
                                    ? 'Paused'
                                    : 'Ready',
                                style: TextStyle(color: accent),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    if (t.complete)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                color: accent,
                                size: 36,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${c.mode} complete',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(t.sessionName, textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                children: [
                                  FilledButton(
                                    onPressed: t.busy
                                        ? null
                                        : () => t.dismiss(),
                                    child: const Text('Stop'),
                                  ),
                                  OutlinedButton(
                                    onPressed: t.busy
                                        ? null
                                        : () => t.configure(
                                            c.mode == 'Focus'
                                                ? 'Break'
                                                : 'Focus',
                                            startImmediately: true,
                                          ),
                                    child: Text(
                                      c.mode == 'Focus'
                                          ? 'Start Break'
                                          : 'Start Focus',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      children: [
                        for (final m
                            in c.mode == 'Break'
                                ? [1, 5, 10, 15]
                                : [15, 25, 45, 60])
                          ChoiceChip(
                            label: Text('$m min'),
                            selected: c.durationSeconds == m * 60,
                            onSelected: t.busy
                                ? null
                                : (_) => configure(c.mode, minutes: m),
                          ),
                      ],
                    ),
                    TextButton(
                      onPressed: t.busy ? null : custom,
                      child: const Text('Custom length'),
                    ),
                    const SizedBox(height: 12),
                    if (!t.complete)
                      FilledButton.icon(
                        onPressed: t.busy
                            ? null
                            : () => c.running ? t.pause() : t.start(),
                        icon: Icon(c.running ? Icons.pause : Icons.play_arrow),
                        label: Text(
                          c.running
                              ? 'Pause'
                              : t.paused
                              ? 'Resume'
                              : 'Start ${c.mode}',
                        ),
                      ),
                    TextButton(
                      onPressed: t.busy
                          ? null
                          : () async {
                              if (await confirmReset()) await t.reset();
                            },
                      child: const Text('Reset timer'),
                    ),
                    Text(
                      '${c.sessions} focus sessions completed',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      t.alertMessage ??
                          'Focus and Break have different end sounds. iOS 26+ can ring a system alarm with your permission. Older iPhones use a notification sound.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    if (t.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          t.error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }
}
