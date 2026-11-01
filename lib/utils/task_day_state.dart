/// Identifies which day owns the unqualified local `tasks` cache.
/// A cloud account's last-active date does not date a newly restored cache.
String activeTaskCacheDate({
  required String today,
  required String? localLastActiveDate,
  required bool hasLocalTasks,
  required List<Map<String, dynamic>> cachedTasks,
}) {
  if (!hasLocalTasks) return today;
  if (localLastActiveDate != null && localLastActiveDate.isNotEmpty) {
    return localLastActiveDate;
  }
  final dates = cachedTasks
      .map((task) => task['date']?.toString())
      .whereType<String>()
      .where((date) => date.isNotEmpty)
      .toSet();
  return dates.length == 1 ? dates.single : today;
}

/// A series shares an ID across days, but each day's status is independent.
/// Undated legacy records are accepted because their storage key dates them.
Map<String, dynamic>? recurringOccurrenceForDate({
  required List<Map<String, dynamic>> savedTasks,
  required Object? recurringId,
  required String date,
}) {
  if (recurringId == null) return null;
  for (final task in savedTasks) {
    if (task['recurringId'] == recurringId &&
        (task['date'] == null || task['date'].toString() == date)) {
      return task;
    }
  }
  return null;
}

/// Recurring tasks are rebuilt from their schedule, not carried over as copies.
List<Map<String, dynamic>> tasksEligibleForCarryOver(
  List<Map<String, dynamic>> tasks,
) => tasks
    .where(
      (task) =>
          task['recurringId'] == null &&
          task['completed'] != true &&
          task['status'] != 'Complete',
    )
    .map((task) => Map<String, dynamic>.from(task))
    .toList();
