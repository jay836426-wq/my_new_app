import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime selectedDate = DateTime.now();

  List<Map<String, dynamic>> tasks = [];

  DateTime currentMonth = DateTime.now();

  final List<String> monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  // Returns the Firebase UID for the currently signed-in TrakOn user.
  String get currentUserId {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError('No authenticated user is available.');
    }

    return user.uid;
  }

  // Makes SharedPreferences keys user-specific.
  String userKey(String key) {
    return '${currentUserId}_$key';
  }

  @override
  void initState() {
    super.initState();
    loadSelectedDateAndTasks();
  }

  String getDateKey(DateTime date) {
    return '${date.year}-${date.month}-${date.day}';
  }

  String getTaskStorageKey(String dateKey) {
    final todayKey = getDateKey(DateTime.now());

    return dateKey == todayKey ? userKey('tasks') : userKey('tasks_$dateKey');
  }

  DateTime parseDateKey(String dateKey) {
    final parts = dateKey.split('-');

    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  // Loads the recurring task templates saved by HomeScreen.
  Future<List<Map<String, dynamic>>> loadRecurringTasks() async {
    final prefs = await SharedPreferences.getInstance();

    final savedRecurringTasks = prefs.getString(userKey('recurringTasks'));

    if (savedRecurringTasks == null) {
      return [];
    }

    final List decodedTasks = jsonDecode(savedRecurringTasks);

    return decodedTasks.map((task) {
      return Map<String, dynamic>.from(task);
    }).toList();
  }

  // Checks whether a recurring task belongs on a specific date.
  bool recurringTaskRunsOnDate(Map<String, dynamic> task, DateTime date) {
    final repeat = task['repeat'] ?? 'Never';

    final startDateText = task['startDate'] ?? task['date'];

    if (startDateText == null) {
      return false;
    }

    final startDate = parseDateKey(startDateText);

    final selectedDateOnly = DateTime(date.year, date.month, date.day);

    final startDateOnly = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );

    // Don't show recurrence before its original start date.
    if (selectedDateOnly.isBefore(startDateOnly)) {
      return false;
    }

    switch (repeat) {
      case 'Daily':
        return true;

      case 'Weekdays':
        return date.weekday >= DateTime.monday &&
            date.weekday <= DateTime.friday;

      case 'Weekly':
        return date.weekday == startDate.weekday;

      case 'Specific Days':
        final repeatDays = List<int>.from(task['repeatDays'] ?? []);

        return repeatDays.contains(date.weekday);

      default:
        return false;
    }
  }

  // Returns the correct tasks for any date.
  // This preserves saved completion/status for recurring task occurrences.
  Future<List<Map<String, dynamic>>> getTasksForDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();

    final dateKey = getDateKey(date);
    final taskKey = getTaskStorageKey(dateKey);

    final savedTasksText = prefs.getString(taskKey);

    final savedTasks = <Map<String, dynamic>>[];

    // Load anything already saved specifically for this date.
    if (savedTasksText != null) {
      final List decodedTasks = jsonDecode(savedTasksText);

      savedTasks.addAll(
        decodedTasks.map((task) {
          return Map<String, dynamic>.from(task);
        }),
      );
    }

    // Start with normal, non-recurring tasks.
    final dayTasks = savedTasks
        .where((task) => task['recurringId'] == null)
        .map((task) {
          return Map<String, dynamic>.from(task);
        })
        .toList();

    // Load the latest recurring-task templates.
    final recurringTasks = await loadRecurringTasks();

    for (final recurringTask in recurringTasks) {
      // Skip this recurring task if it does not belong on this date.
      if (!recurringTaskRunsOnDate(recurringTask, date)) {
        continue;
      }

      final recurringId = recurringTask['recurringId'];

      // Look for an already-saved occurrence on this specific date.
      // This lets us preserve completion/status for that day.
      Map<String, dynamic>? existingOccurrence;

      for (final savedTask in savedTasks) {
        if (savedTask['recurringId'] == recurringId) {
          existingOccurrence = savedTask;
          break;
        }
      }

      // Start with the latest recurring template information.
      final recurringCopy = Map<String, dynamic>.from(recurringTask);

      // Make this copy belong specifically to the requested date.
      recurringCopy['date'] = dateKey;

      // Preserve this date's saved completion state.
      recurringCopy['completed'] = existingOccurrence?['completed'] ?? false;

      // Preserve the workflow status for this date.
      recurringCopy['status'] = existingOccurrence?['status'] ?? 'Not Started';

      // The notification ID belongs to the entire recurring series.
      recurringCopy['notificationId'] = recurringTask['notificationId'];

      dayTasks.add(recurringCopy);
    }

    return dayTasks;
  }

  Future<void> loadSelectedDateAndTasks() async {
    final prefs = await SharedPreferences.getInstance();

    final savedDateKey = prefs.getString(userKey('selectedTaskDate'));

    if (savedDateKey != null) {
      final savedDate = parseDateKey(savedDateKey);

      setState(() {
        selectedDate = savedDate;
        currentMonth = DateTime(savedDate.year, savedDate.month);
      });
    }

    await loadTasksForSelectedDate();
  }

  Future<void> loadTasksForSelectedDate() async {
    final loadedTasks = await getTasksForDate(selectedDate);

    if (!mounted) return;

    setState(() {
      tasks = loadedTasks;
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedTasks = tasks;

    final completedCount = selectedTasks
        .where((task) => task['completed'] == true)
        .length;

    final inProgressCount = selectedTasks.where((task) {
      return (task['status']?.toString() ?? 'Not Started') == 'In Progress';
    }).length;

    final notStartedCount = selectedTasks.where((task) {
      return (task['status']?.toString() ?? 'Not Started') == 'Not Started' &&
          task['completed'] != true;
    }).length;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Weekday labels
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('Sun', style: TextStyle(color: Colors.white70)),
                    Text('Mon', style: TextStyle(color: Colors.white70)),
                    Text('Tue', style: TextStyle(color: Colors.white70)),
                    Text('Wed', style: TextStyle(color: Colors.white70)),
                    Text('Thu', style: TextStyle(color: Colors.white70)),
                    Text('Fri', style: TextStyle(color: Colors.white70)),
                    Text('Sat', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Month Navigation
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        currentMonth = DateTime(
                          currentMonth.year,
                          currentMonth.month - 1,
                        );
                      });
                    },
                  ),

                  Column(
                    children: [
                      Text(
                        '${monthNames[currentMonth.month - 1]} ${currentMonth.year}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 2),

                      TextButton(
                        onPressed: () async {
                          final now = DateTime.now();

                          setState(() {
                            currentMonth = DateTime(now.year, now.month);

                            selectedDate = DateTime(
                              now.year,
                              now.month,
                              now.day,
                            );
                          });

                          final prefs = await SharedPreferences.getInstance();

                          await prefs.setString(
                            userKey('selectedTaskDate'),
                            getDateKey(selectedDate),
                          );

                          await loadTasksForSelectedDate();
                        },
                        child: const Text(
                          'Today',
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        currentMonth = DateTime(
                          currentMonth.year,
                          currentMonth.month + 1,
                        );
                      });
                    },
                  ),
                ],
              ),
              // Calendar day grid
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.count(
                  crossAxisCount: 7,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: List.generate(
                    DateTime(currentMonth.year, currentMonth.month + 1, 0).day +
                        DateTime(
                              currentMonth.year,
                              currentMonth.month,
                              1,
                            ).weekday %
                            7,
                    (index) {
                      final int firstWeekdayOffset =
                          DateTime(
                            currentMonth.year,
                            currentMonth.month,
                            1,
                          ).weekday %
                          7;

                      if (index < firstWeekdayOffset) {
                        return const SizedBox.shrink();
                      }
                      final int dayNumber = index - firstWeekdayOffset + 1;

                      final bool isSelected =
                          (selectedDate.year == currentMonth.year &&
                          selectedDate.month == currentMonth.month &&
                          selectedDate.day == dayNumber);

                      final now = DateTime.now();

                      final bool isToday =
                          now.year == currentMonth.year &&
                          now.month == currentMonth.month &&
                          now.day == dayNumber;

                      return GestureDetector(
                        onTap: () async {
                          setState(() {
                            selectedDate = DateTime(
                              currentMonth.year,
                              currentMonth.month,
                              dayNumber,
                            );
                          });

                          final prefs = await SharedPreferences.getInstance();

                          final String selectedDateKey =
                              '${selectedDate.year}-${selectedDate.month}-${selectedDate.day}';
                          await prefs.setString(
                            userKey('selectedTaskDate'),
                            selectedDateKey,
                          );

                          // Wait for the selected day's tasks to finish loading.
                          await loadTasksForSelectedDate();
                        },
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.greenAccent
                                : Colors.white10,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.greenAccent
                                  : isToday
                                  ? Colors.greenAccent.withValues(alpha: 0.65)
                                  : Colors.transparent,
                              width: isSelected ? 2 : 1.5,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: Colors.greenAccent.withValues(
                                        alpha: 0.35,
                                      ),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : [],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$dayNumber',
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.black
                                      : Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              FutureBuilder<List<Map<String, dynamic>>>(
                                future: getTasksForDate(
                                  DateTime(
                                    currentMonth.year,
                                    currentMonth.month,
                                    dayNumber,
                                  ),
                                ),
                                builder: (context, snapshot) {
                                  final dayTasks = snapshot.data ?? [];

                                  // No tasks = no dot
                                  Color dotColor = Colors.transparent;

                                  if (dayTasks.isNotEmpty) {
                                    final allCompleted = dayTasks.every((task) {
                                      final status =
                                          task['status']?.toString() ??
                                          'Not Started';

                                      return status == 'Complete' ||
                                          task['completed'] == true;
                                    });

                                    final anyInProgress = dayTasks.any((task) {
                                      final status =
                                          task['status']?.toString() ??
                                          'Not Started';

                                      return status == 'In Progress';
                                    });

                                    if (allCompleted) {
                                      dotColor = Colors.greenAccent;
                                    } else if (anyInProgress) {
                                      dotColor = Colors.amber;
                                    } else {
                                      dotColor = Colors.white38;
                                    }
                                  }

                                  return Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: dotColor,
                                      shape: BoxShape.circle,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Daily productivity summary card
              Padding(
                padding: const EdgeInsets.all(20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${selectedDate.month}/${selectedDate.day}/${selectedDate.year}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      if (selectedDate.day == DateTime.now().day &&
                          selectedDate.month == DateTime.now().month &&
                          selectedDate.year == DateTime.now().year)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(
                            'TODAY',
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),

                      const SizedBox(height: 12),

                      Text(
                        selectedDate.day == DateTime.now().day &&
                                selectedDate.month == DateTime.now().month &&
                                selectedDate.year == DateTime.now().year
                            ? 'Today\'s productivity'
                            : 'Selected day summary',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 10),

                      if (selectedTasks.isNotEmpty) ...[
                        Row(
                          children: [
                            // Completed
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Completed',
                                      style: TextStyle(
                                        color: Colors.greenAccent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$completedCount',
                                      style: const TextStyle(
                                        color: Colors.greenAccent,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(width: 10),

                            // In Progress
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'In Progress',
                                      style: TextStyle(
                                        color: Colors.amber,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$inProgressCount',
                                      style: const TextStyle(
                                        color: Colors.amber,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(width: 10),

                            // Not Started
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Not Started',
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$notStartedCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),
                      ],
                      ...[
                        if (selectedTasks.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 24,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Column(
                              children: [
                                Icon(
                                  Icons.event_available_outlined,
                                  color: Colors.greenAccent,
                                  size: 34,
                                ),
                                SizedBox(height: 10),
                                Text(
                                  'No tasks planned',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'This day is clear.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ...selectedTasks.map((task) {
                          final status =
                              task['status']?.toString() ?? 'Not Started';

                          final icon = status == 'Complete'
                              ? '✅'
                              : status == 'In Progress'
                              ? '▶️'
                              : '⬜';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              '$icon ${task['title']}',
                              style: TextStyle(
                                color: status == 'Complete'
                                    ? Colors.greenAccent
                                    : status == 'In Progress'
                                    ? Colors.amber
                                    : Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
