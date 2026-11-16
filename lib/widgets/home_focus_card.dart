import 'package:flutter/material.dart';
import '../services/planning_store.dart';
import '../services/focus_timer_controller.dart';
import '../services/stopwatch_controller.dart';
import '../screens/focus_timer_screen.dart';

/// Compact entry point; both clocks remain owned by their shared controllers.
class HomeFocusCard extends StatefulWidget {
  const HomeFocusCard({super.key, required this.store});
  final PlanningStore store;
  @override
  State<HomeFocusCard> createState() => _HomeFocusCardState();
}

class _HomeFocusCardState extends State<HomeFocusCard> {
  static const mint = Color(0xFF63E8AD);
  late final FocusTimerController timer;
  late final StopwatchController stopwatch;
  late final Listenable clocks;
  String? selected;

  @override
  void initState() {
    super.initState();
    timer = FocusTimerController.forStore(widget.store);
    stopwatch = StopwatchController.forStore(widget.store);
    clocks = Listenable.merge([timer, stopwatch]);
    timer.load().catchError((Object _) {});
    stopwatch.load();
  }

  Future<void> open(String mode) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FocusTimerScreen(
          initialMode:
              mode == 'Stopwatch' ||
                  !(timer.clock?.running == true ||
                      timer.paused ||
                      timer.complete)
              ? mode
              : null,
        ),
      ),
    );
  }

  Future<void> startMode(String mode) async {
    if (timer.clock?.running == true || timer.paused) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text('Start $mode instead?'),
          content: Text(
            'This will stop your current ${timer.clock!.mode.toLowerCase()} session.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Keep session'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: Text('Start $mode'),
            ),
          ],
        ),
      );
      if (replace != true || !mounted) return;
    }
    await timer.configure(mode, startImmediately: true);
  }

  Widget primary(String label, IconData icon, VoidCallback? action) =>
      FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: mint,
          foregroundColor: const Color(0xFF092A20),
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
        onPressed: action,
        icon: Icon(icon, size: 20),
        label: Text(label),
      );

  Widget secondary(String label, VoidCallback? action) => OutlinedButton(
    style: OutlinedButton.styleFrom(
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      minimumSize: const Size(0, 48),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    ),
    onPressed: action,
    child: Text(label),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: clocks,
    builder: (context, _) {
      final c = timer.clock;
      final s = stopwatch.active;
      final mode = selected ?? (s != null ? 'Stopwatch' : c?.mode ?? 'Focus');
      final isStopwatch = mode == 'Stopwatch';
      final focusActive =
          c != null && (c.running || timer.paused || timer.complete);
      final otherTimer = !isStopwatch && focusActive && c.mode != mode;
      final elapsed = s?.elapsed(DateTime.now()) ?? 0;
      final ready = s == null || (!s.running && !s.finalizing && elapsed == 0);
      final busy = isStopwatch
          ? stopwatch.busy || !stopwatch.loaded
          : timer.busy || c == null;
      final title = isStopwatch
          ? s?.title ?? 'Track your time'
          : focusActive && !otherTimer
          ? timer.sessionName
          : timer.nameFor(mode);
      final status = isStopwatch
          ? s?.finalizing == true
                ? 'Ready to save'
                : ready
                ? 'Ready'
                : s.running
                ? 'Running'
                : 'Paused'
          : otherTimer
          ? '${c.mode} is ${timer.complete
                ? 'complete'
                : c.running
                ? 'running'
                : 'paused'}'
          : focusActive
          ? timer.complete
                ? 'Complete'
                : c.running
                ? 'Running'
                : 'Paused'
          : 'Ready';
      final time = isStopwatch
          ? stopwatch.time
          : otherTimer || !focusActive
          ? '${timer.minutesFor(mode)}:00'
          : timer.timeLabel;
      final error = isStopwatch ? stopwatch.error : timer.error;
      final running = isStopwatch
          ? s?.running == true
          : c?.running == true && !otherTimer;
      return Card(
        margin: const EdgeInsets.only(bottom: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                button: true,
                label: 'Open $mode details',
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => open(mode),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.timer_outlined, color: mint, size: 22),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Timers',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    for (final tab in ['Focus', 'Break', 'Stopwatch'])
                      Expanded(
                        child: Semantics(
                          selected: mode == tab,
                          button: true,
                          child: Tooltip(
                            message: tab == 'Stopwatch' && s != null
                                ? 'Stopwatch · ${s.running
                                      ? 'Running'
                                      : s.finalizing
                                      ? 'Ready to save'
                                      : 'Paused'}'
                                : focusActive && c.mode == tab
                                ? '$tab · ${timer.complete
                                      ? 'Complete'
                                      : c.running
                                      ? 'Running'
                                      : 'Paused'}'
                                : tab,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                minimumSize: const Size(0, 44),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 10,
                                ),
                                backgroundColor: mode == tab
                                    ? mint.withValues(alpha: 0.14)
                                    : Colors.transparent,
                                foregroundColor: mode == tab
                                    ? mint
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () => setState(() => selected = tab),
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 4,
                                children: [
                                  Text(
                                    tab,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (tab == 'Stopwatch'
                                      ? s != null
                                      : focusActive && c.mode == tab)
                                    const Icon(
                                      Icons.circle,
                                      size: 5,
                                      semanticLabel: 'Active session',
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (running
                                    ? mint
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant)
                                .withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 12,
                          color: running
                              ? mint
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  time,
                  style: const TextStyle(
                    fontSize: 38,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  if (isStopwatch) ...[
                    if (s?.finalizing == true)
                      primary(
                        'Save session',
                        Icons.save_outlined,
                        busy ? null : () => stopwatch.stopAndSave(),
                      )
                    else ...[
                      primary(
                        s?.running == true
                            ? 'Pause'
                            : ready
                            ? 'Start'
                            : 'Resume',
                        s?.running == true ? Icons.pause : Icons.play_arrow,
                        busy
                            ? null
                            : () => stopwatch.run(
                                s == null
                                    ? stopwatch.repo.start
                                    : s.running
                                    ? stopwatch.repo.pause
                                    : stopwatch.repo.resume,
                              ),
                      ),
                      if (elapsed > 0)
                        secondary(
                          'Stop & Save',
                          busy ? null : () => stopwatch.stopAndSave(),
                        ),
                    ],
                  ] else if (otherTimer)
                    primary(
                      'Start $mode',
                      Icons.play_arrow,
                      busy ? null : () => startMode(mode),
                    )
                  else if (focusActive && timer.complete) ...[
                    primary(
                      'Stop',
                      Icons.stop,
                      busy ? null : () => timer.dismiss(),
                    ),
                    secondary(
                      mode == 'Focus' ? 'Start Break' : 'Start Focus',
                      busy
                          ? null
                          : () async {
                              final next = mode == 'Focus' ? 'Break' : 'Focus';
                              setState(() => selected = next);
                              await timer.configure(
                                next,
                                startImmediately: true,
                              );
                            },
                    ),
                  ] else ...[
                    primary(
                      focusActive
                          ? c.running
                                ? 'Pause'
                                : 'Resume'
                          : 'Start $mode',
                      focusActive && c.running ? Icons.pause : Icons.play_arrow,
                      busy
                          ? null
                          : () => focusActive
                                ? c.running
                                      ? timer.pause()
                                      : timer.start()
                                : timer.configure(mode, startImmediately: true),
                    ),
                    if (focusActive)
                      secondary('Stop', busy ? null : () => timer.dismiss()),
                  ],
                ],
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
