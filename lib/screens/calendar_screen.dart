
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

  List<Map<String, dynamic>> tasks =[];

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
    'December'
  ];

  @override
  void initState() {
    super.initState();
    loadTasks();
  }

  Future<void> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedTasks = prefs.getString('tasks');

    if (savedTasks != null) {
      final List decodedTasks = jsonDecode(savedTasks);

      setState(() {
        tasks = decodedTasks.map((task) {
          return Map<String, dynamic>.from(task);
        }).toList();
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    final selectedTasks = tasks.where((task) {
      if (task['date'] == null) return false;

      final taskDate = DateTime.parse(task['date']);

      return taskDate.year == selectedDate.year && 
          taskDate.month == selectedDate.month && 
          taskDate.day == selectedDate.day;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Calendar header with month navigation
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${currentMonth.month}/${currentMonth.year}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

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

                  Text(
                    '${monthNames[currentMonth.month - 1]} ${currentMonth.year}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
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
                    DateTime(currentMonth.year, currentMonth.month +1, 0).day +
                        DateTime(currentMonth.year, currentMonth.month, 1). weekday % 7,
                    (index){
                      final int firstWeekdayOffset = 
                          DateTime(currentMonth.year, currentMonth.month, 1). weekday % 7;

                          if (index < firstWeekdayOffset) {
                            return const SizedBox.shrink();
                          }
                          final int dayNumber = index - firstWeekdayOffset + 1;
                    final bool isSelected = (
                        selectedDate.year == currentMonth.year &&
                        selectedDate.month == currentMonth.month &&
                        selectedDate.day == dayNumber
                    );
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedDate = DateTime(
                            currentMonth.year,
                            currentMonth.month,
                            dayNumber,
                          );
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.35)
                              : Colors.white10,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? Colors.greenAccent
                                : Colors.transparent,
                            width: 2,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Colors.greenAccent.withValues(alpha: 0.85),
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
                                color: isSelected ? Colors.black : Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: dayNumber % 3 == 0
                                    ? Colors.greenAccent
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
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

                      if (
                          selectedDate.day == DateTime.now().day &&
                          selectedDate.month == DateTime.now().month &&
                          selectedDate.year == DateTime.now().year
                      )
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

                        ... [
                          if (selectedTasks.isEmpty)
                            const Text(
                              'No tasks for this day.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
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