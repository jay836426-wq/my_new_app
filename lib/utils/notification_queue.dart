/// A bounded, persistent scheduling policy; native delivery remains OS-owned.
class PlannedAlert {
  const PlannedAlert({
    required this.id,
    required this.title,
    required this.body,
    required this.at,
    this.payload,
    this.repeat,
  });
  final int id;
  final String title, body;
  final DateTime at;
  final String? payload, repeat;
  bool get isTask => payload?.startsWith('task:') ?? false;
  bool get isOptional =>
      id >= 9010000 && id <= 9010040 || id >= 9000012 && id <= 9000018;
  String? get protectedGroup {
    if (id == 9000007 || id == 9000019) return 'timer:$id';
    if (id >= 9000012 && id <= 9000018) return 'mood';
    if (payload?.startsWith('encouragement:') ?? false) return payload;
    if (repeat != null) return 'repeat:$id';
    return null;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'at': at.toUtc().toIso8601String(),
    'payload': payload,
    'repeat': repeat,
  };
  factory PlannedAlert.fromJson(Map<String, dynamic> v) => PlannedAlert(
    id: v['id'] as int,
    title: v['title'] as String,
    body: v['body'] as String,
    at: DateTime.parse(v['at'] as String),
    payload: v['payload'] as String?,
    repeat: v['repeat'] as String?,
  );
}

/// Reserve native slots for check-ins; far-future task repeats wait in storage.
/// Unknown requests from older builds are retained and count against capacity.
List<PlannedAlert> chooseQueuedAlerts(
  List<PlannedAlert> alerts,
  DateTime now, {
  int unknownCount = 0,
}) {
  final capacity = (60 - unknownCount).clamp(0, 60);
  final sorted =
      alerts.where((a) => a.repeat != null || a.at.isAfter(now)).toList()
        ..sort((a, b) {
          final c = a.at.compareTo(b.at);
          return c == 0 ? a.id.compareTo(b.id) : c;
        });
  final chosen = <PlannedAlert>[];
  var tasks = 0, optional = 0;
  void add(PlannedAlert a) {
    if (chosen.length >= capacity ||
        chosen.any((b) => b.id == a.id) ||
        a.isTask && tasks >= 32 ||
        a.isOptional && optional >= 24) {
      return;
    }
    chosen.add(a);
    if (a.isTask) tasks++;
    if (a.isOptional) optional++;
  }

  final groups = <String>{};
  for (final a in sorted) {
    final group = a.protectedGroup;
    if (group != null && groups.add(group)) add(a);
  }
  for (final a in sorted) {
    add(a);
  }
  return chosen;
}
