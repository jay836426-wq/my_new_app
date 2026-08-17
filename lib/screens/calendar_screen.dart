import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

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
    return dateKey == todayKey ? 'tasks' : 'tasks_$dateKey';
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

    final savedRecurringTasks = prefs.getString('recurringTasks');

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

  // Returns normal tasks + recurring tasks for any date.
  Future<List<Map<String, dynamic>>> getTasksForDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();

    final dateKey = getDateKey(date);
    final taskKey = getTaskStorageKey(dateKey);

    final savedTasks = prefs.getString(taskKey);

    final dayTasks = <Map<String, dynamic>>[];

    // Load tasks already saved specifically for this day.
    if (savedTasks != null) {
      final List decodedTasks = jsonDecode(savedTasks);

      dayTasks.addAll(
        decodedTasks.map((task) {
          return Map<String, dynamic>.from(task);
        }),
      );
    }

    // Add recurring tasks that belong on this day.
    final recurringTasks = await loadRecurringTasks();

    for (final recurringTask in recurringTasks) {
      if (!recurringTaskRunsOnDate(recurringTask, date)) {
        continue;
      }

      final recurringId = recurringTask['recurringId'];

      // Prevent a recurring task from appearing twice.
      final alreadyExists = dayTasks.any((task) {
        return task['recurringId'] == recurringId;
      });

      if (alreadyExists) {
        continue;
      }

      final recurringCopy = Map<String, dynamic>.from(recurringTask);

      recurringCopy['date'] = dateKey;
      recurringCopy['completed'] = false;

      dayTasks.add(recurringCopy);
    }

    return dayTasks;
  }

  Future<void> loadSelectedDateAndTasks() async {
    final prefs = await SharedPreferences.getInstance();

    final savedDateKey = prefs.getString('selectedTaskDate');

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

    final remainingCount = selectedTasks.length - completedCount;

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
                            'selectedTaskDate',
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
                            'selectedTaskDate',
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
                                  final taskCount = snapshot.data?.length ?? 0;

                                  return Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      // Green dot only when this date really has tasks.
                                      color: taskCount > 0
                                          ? Colors.greenAccent
                                          : Colors.transparent,
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
                                        color: Colors.white54,
                                        fontSize: 12,
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
                                      'Remaining',
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$remainingCount',
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
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              task['completed']
                                  ? '✅ ${task['title']}'
                                  : '⬜ ${task['title']}',
                              style: const TextStyle(
                                color: Colors.white70,
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
