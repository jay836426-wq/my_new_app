import 'package:flutter/material.dart';
import '../services/planning_store.dart';
import '../services/focus_timer_controller.dart';
import '../screens/focus_timer_screen.dart';

class HomeFocusCard extends StatefulWidget {
  const HomeFocusCard({super.key, required this.store});
  final PlanningStore store;
  @override
  State<HomeFocusCard> createState() => _HomeFocusCardState();
}

class _HomeFocusCardState extends State<HomeFocusCard> {
  late final FocusTimerController timer;
  @override
  void initState() {
    super.initState();
    timer = FocusTimerController.forStore(widget.store);
    timer.load().catchError((Object _) {});
  }

  Future<void> open([String? mode]) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FocusTimerScreen(
          initialMode: mode,
          autoStart: mode != null && mode != 'Stopwatch',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: timer,
    builder: (context, _) {
      final c = timer.clock;
      final active = c?.running == true || timer.paused || timer.complete;
      return Card(
        margin: const EdgeInsets.only(bottom: 20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.timer_outlined, color: Colors.greenAccent),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Focus & Break',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Open Focus & Break',
                    onPressed: () => open(),
                    icon: const Icon(Icons.open_in_full),
                  ),
                ],
              ),
              if (active) ...[
                Text(
                  timer.sessionName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  timer.complete
                      ? '${c!.mode} complete'
                      : '${c!.mode} · ${timer.paused ? 'Paused' : 'Running'}',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                Text(
                  timer.timeLabel,
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    if (timer.complete) ...[
                      FilledButton(
                        onPressed: timer.busy ? null : () => timer.dismiss(),
                        child: const Text('Stop'),
                      ),
                      OutlinedButton(
                        onPressed: timer.busy
                            ? null
                            : () => timer.configure(
                                c.mode == 'Focus' ? 'Break' : 'Focus',
                                startImmediately: true,
                              ),
                        child: Text(
                          c.mode == 'Focus' ? 'Start Break' : 'Start Focus',
                        ),
                      ),
                    ] else
                      FilledButton.icon(
                        onPressed: timer.busy
                            ? null
                            : () => c.running ? timer.pause() : timer.start(),
                        icon: Icon(c.running ? Icons.pause : Icons.play_arrow),
                        label: Text(c.running ? 'Pause' : 'Resume'),
                      ),
                    TextButton(
                      onPressed: () => open(),
                      child: const Text('Open timer'),
                    ),
                  ],
                ),
              ] else ...[
                const Text(
                  'Make room to concentrate—and recharge.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: c == null || timer.busy
                          ? null
                          : () => open('Focus'),
                      icon: const Icon(Icons.play_arrow),
                      label: Text(
                        'Start Focus · ${timer.minutesFor('Focus')} min',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: c == null || timer.busy
                          ? null
                          : () => open('Break'),
                      icon: const Icon(Icons.coffee_outlined),
                      label: Text(
                        'Take a Break · ${timer.minutesFor('Break')} min',
                      ),
                    ),
                  ],
                ),
              ],
              TextButton.icon(
                onPressed: () => open('Stopwatch'),
                icon: const Icon(Icons.av_timer),
                label: const Text('Open Stopwatch'),
              ),
              if (timer.error != null)
                Text(
                  timer.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      );
    },
  );
}
