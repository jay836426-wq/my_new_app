/// A deadline survives backgrounding and process restarts; periodic ticks only
/// redraw the UI and are never the source of elapsed time.
class FocusClock {
  FocusClock({
    this.durationSeconds = 1500,
    int? remainingSeconds,
    this.deadline,
    this.sessions = 0,
    this.mode = 'Focus',
    this.title = '',
  }) : pausedSeconds = remainingSeconds ?? durationSeconds;
  int durationSeconds;
  int pausedSeconds;
  DateTime? deadline;
  int sessions;
  String mode;
  String title;
  bool get running => deadline != null;
  int remaining(DateTime now) => deadline == null
      ? pausedSeconds
      : ((deadline!.difference(now).inMilliseconds / 1000).ceil()).clamp(
          0,
          durationSeconds,
        );
  void start(DateTime now) {
    if (running) return;
    if (pausedSeconds <= 0) pausedSeconds = durationSeconds;
    deadline = now.add(Duration(seconds: pausedSeconds));
  }

  void pause(DateTime now) {
    pausedSeconds = remaining(now);
    deadline = null;
  }

  void reset() {
    deadline = null;
    pausedSeconds = durationSeconds;
  }

  bool finishIfExpired(DateTime now) {
    if (deadline == null || deadline!.isAfter(now)) return false;
    deadline = null;
    pausedSeconds = 0;
    if (mode == 'Focus') sessions++;
    return true;
  }

  Map<String, dynamic> toJson() => {
    'durationSeconds': durationSeconds,
    'remainingSeconds': pausedSeconds,
    'deadline': deadline?.toUtc().toIso8601String(),
    'sessions': sessions,
    'mode': mode,
    'title': title,
  };
  factory FocusClock.fromJson(Map<String, dynamic> json) {
    final seconds = ((json['durationSeconds'] as num?)?.toInt() ?? 1500).clamp(
      60,
      10800,
    );
    return FocusClock(
      durationSeconds: seconds,
      remainingSeconds: ((json['remainingSeconds'] as num?)?.toInt() ?? seconds)
          .clamp(0, seconds),
      deadline: DateTime.tryParse(json['deadline']?.toString() ?? ''),
      sessions: (json['sessions'] as num?)?.toInt() ?? 0,
      mode: json['mode'] == 'Break' ? 'Break' : 'Focus',
      title: json['title']?.toString() ?? '',
    );
  }
}
