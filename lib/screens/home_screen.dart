import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';
import 'package:flutter/cupertino.dart';

// ---------------------------
// Home Screen
// ---------------------------
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // List to store tasks
  List<Map<String, dynamic>> tasks = [];

  // Controller to get input text
  final TextEditingController taskController = TextEditingController();

  // Controller for optional task description
  final TextEditingController descriptionController = TextEditingController();

  // Store the category selected in the dropdown
  String selectedCategory = '🏠 Personal';

  // Store the priority level is currently selected
  String? selectedPriority;

  // Stores which category filter is currently selected
  String selectedFilter = 'All';

  // List of daily motivational quotes
  final List<String> motivationalQuotes = [
    'Small progress is still progress.',
    'Stay focused. Your goals are worth it.',
    'Discipline today creates freedom tomorrow.',
    'You do not have to be perfect. Just keep moving.',
    'Success starts with showing up.',
    'One task at a time. One day at a time.',
    'Your future is built by what you do today.',
    'Keep going. You are closer than you think.',
    'Consistency beats motivation.',
    'Focus on progress, not perfection.',
    'Dream big. Start small. Act now.',
    'Every task completed is a step forward.',
    'The hardest part is getting started.',
    'Great things take time.',
    'You are stronger than yesterday.',
    'Win the day.',
    'Progress compounds over time.',
    'Your habits shape your future.',
    'Keep promises to yourself.',
    'Action beats intention.',
    'Believe in your ability to grow.',
    'Do something today your future self will thank you for.',
    'A little progress every day adds up.',
    'Stay patient and trust the process.',
    'Success is built on consistency.',
    'The only bad workout is the one you did not do.',
    'Start where you are. Use what you have.',
    'Momentum starts with one step.',
    'Hard work always leaves a mark.',
    'Be better than yesterday.',
    'Success comes from daily discipline.',
    'Done is better than perfect.',
    'Every accomplishment begins with a decision to try.',
    'Focus creates results.',
    'You are capable of amazing things.',
    'Do not stop until you are proud.',
    'Your only competition is who you were yesterday.',
    'Keep your eyes on the goal.',
    'Little victories lead to big wins.',
    'Every day is a new opportunity.',
    'Build the life you want one task at a time.',
    'The effort you make today pays off tomorrow.',
    'Stay committed even when motivation fades.',
    'Progress requires patience.',
    'Your consistency will become your success.',
    'Take the next step. Then another.',
    'Success is earned, not given.',
    'Finish what you started.',
    'Keep moving forward.',
    'To learn to succeed, you must learn how to fail.',
    'The moment you give up is the moment you let someone else win.',
    'Don’t count the days, make the days count.',
    'Success begins with one decision.',
    'Stay hungry for improvement.',
    'Every step forward matters.',
    'Discipline outlasts motivation.',
    'Make today count.',
    'Growth happens outside your comfort zone.',
    'The best investment is in yourself.',
    'Choose progress over excuses.',
    'Your dreams deserve your effort.',
    'One more rep. One more task. One more win.',
    'Build habits that build your future.',
    'The grind is temporary. The results are lasting.',
    'Turn your goals into daily actions.',
    'Stay consistent when no one is watching.',
    'Nothing changes if nothing changes.',
    'Show up even on the hard days.',
    'You become what you repeatedly do.',
    'Small victories create big transformations.',
    'Keep your standards high.',
    'The work you avoid is often the work you need most.',
    'Progress starts with action.',
    'Your future self is counting on you.',
    'Every day is another chance to improve.',
    'Keep building, even if it is one brick at a time.',
    'Greatness is earned daily.',
    'Trust your journey.',
    'Make discipline your superpower.',
    'Push through the discomfort.',
    'Stay committed to your vision.',
    "Today's effort becomes tomorrow's success.",
    'The only shortcut is consistency.',
    'Be proud of every step you take.',
    'Focus on what you can control.',
    'Hard work compounds over time.',
    'Do something today that scares you.',
    'Winners master the basics.',
    'Every challenge is an opportunity to grow.',
    'Stay patient. Progress is happening.',
    'Outwork your excuses.',
    'Success is a collection of small wins.',
    'Keep climbing. The view is worth it.',
    'Believe in your potential.',
    'Turn setbacks into comebacks.',
    'One disciplined day leads to another.',
    'Do the work even when you do not feel like it.',
    'Nothing worthwhile comes easy.',
    'Keep improving your best.',
    'Momentum comes from action.',
    'Do not let fear make your decisions.',
    'Success rewards consistency.',
    'The first step changes everything.',
    'Train your mind to stay focused.',
    'Keep chasing excellence.',
    'You are capable of more than you realize.',
    'The strongest habits create the strongest future.',
    'Make progress impossible to ignore.',
    'Keep your promises to yourself.',
    'Your goals deserve your best effort.',
    'Every day is Day One.',
    'Stay focused on your purpose.',
    'The process creates the outcome.',
    'Discipline wins when motivation disappears.',
    'Keep learning. Keep growing.',
    'Success favors those who prepare.',
    'Never settle for average.',
    'The best time to start is now.',
    'Your effort is never wasted.',
    'One positive choice changes your day.',
    'The climb builds your character.',
    'Push yourself because no one else can do it for you.',
    'Stay strong through the struggle.',
    'Growth is built one decision at a time.',
    'Keep aiming higher.',
    'The finish line belongs to those who keep moving.',
    'Every task completed builds confidence.',
    'Be relentless in your pursuit of improvement.',
    'Take pride in your discipline.',
    'Your consistency is your competitive advantage.',
    'The goal is progress, not perfection.',
    'Every accomplishment starts with belief.',
    'You are writing your future today.',
    'Focus creates momentum.',
    'Hard days build stronger people.',
    'Keep your eyes on the bigger picture.',
    'Your actions define your future.',
    'Be the person your goals require.',
    'Keep earning your confidence.',
    'You are stronger than your excuses.',
    'Every hour invested matters.',
    'Stay committed to becoming better.',
    'Do not fear slow progress.',
    "The next level demands today's effort.",
    'Consistency creates confidence.',
    'Win your morning, win your day.',
    'Take action before you feel ready.',
    'Every challenge strengthens your character.',
    'Keep moving even when progress feels slow.',
    'Great achievements start with small actions.',
    'Success follows preparation.',
    'You are one decision away from a better future.',
    'Finish strong every day.',
    "Today's discipline creates tomorrow's opportunities.",
  ];

  // Stores dynamic username for login
  String userName = 'User';

  // Store selected Reminder Time
  TimeOfDay? selectedReminderTime;

  // Loads saved username/full name from local storage
  Future<void> loadUserName() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      userName = 
          prefs.getString('fullName') ??
          prefs.getString('username') ??
          'User';
    });
  }
  // List of available task categories
  final List<String> categories = [
    '🏋️ Fitness',
    '📚 School',
    '💼 Work',
    '🏠 Personal',
    '🛍️ Shopping',
    '👨‍👩‍👧‍👦 Family',
    '🏦 Finance',
    '❤️‍🩹 Health',
    '🥘 Food',
    '✈️ Travel',
    '✨ Other',
    '🙌 Religious',
  ];

  // Listt of available task priority levels
    final List<String> priorities = [
    '🔴 High',
    '🟡 Medium',
    '🟢 Low',
  ];
  // Tracks the user's current streak
  int streakCounter = 0;

  // Tracks whether today's tasks have been completed
  bool dayCompleted = false;

  // Stores the date when the user last completed a day
  String lastCompletedDate = '';

  // Stores the last date the app was opened/used
  String lastActiveDate = '';

  // Stores the previous day's task
  String selectedTaskDate = '';

  // Calculates how much of today's tasks are completed
  double getProgress() {
    // If there are no tasks, progress is 0%
    if (tasks.isEmpty) return 0;

    // Count how many tasks are marked as completed
    int completed = tasks.where((task) => task['completed'] == true).length;

    // Return progress as a value between 0.0 and 1.0
    return completed / tasks.length;
  }

  // Marks the day completed and updates the user's streak
  Future<void> completeDay() async {
    final prefs = await SharedPreferences.getInstance();

    if (!isViewingToday()) return;

    final DateTime today = DateTime.now();

    final String todayString =
        '${today.year}-${today.month}-${today.day}';

    final DateTime yesterday = today.subtract(const Duration(days: 1));

    final String yesterdayString =
        '${yesterday.year}-${yesterday.month}-${yesterday.day}';

    setState(() {
      dayCompleted = true;

      if (lastCompletedDate == todayString) {
        // Already completed today, do not increase streak again
      } else if (lastCompletedDate == yesterdayString) {
        // Completed yesterday, continue streak
        streakCounter += 1;
      } else {
        // Missed a day, reset streak
        streakCounter = 1;
      }

      lastCompletedDate = todayString;
    });

    await prefs.setBool('dayCompleted_$todayString', dayCompleted);
    await prefs.setInt('streakCounter', streakCounter);
    await prefs.setString('lastCompletedDate', lastCompletedDate);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Day completed! Streak updated 🔥'),
      ),
    );
  }

  // Reverses the completed day status and lowers the streak if needed
  Future<void> undoCompleteDay() async {
    final prefs = await SharedPreferences.getInstance();

    if (!isViewingToday()) return;

    final DateTime today = DateTime.now();

    final String todayString =
    '${today.year}-${today.month}-${today.day}';

    setState(() {
      dayCompleted = false;

      if (streakCounter > 0) {
        streakCounter -= 1;
      }

      lastCompletedDate = '';
    });

    await prefs.setBool('dayCompleted_$todayString', dayCompleted);
    await prefs.setInt('streakCounter', streakCounter);
    await prefs.setString('lastCompletedDate', lastCompletedDate);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Day status updated.'),
      ),
    );
  }

  // Runs when Home screen is first opened and loads the saved username
  @override
  void initState() {
    super.initState();
    initializeHomeScreen();
    loadUserName();
  }

  Future<void> initializeHomeScreen() async {
    await loadTasks();
    await checkForNewDay();
    await checkStreakReset();
  }


  // Calculates the user's current streak
  int getCurrentStreak() {

    // If there are no tasks, streak is 0
    if (tasks.isEmpty) return 0;

    // Check if every task is completed
    final bool allTasksComplete = tasks.every((task) => task['completed'] == true);

    // Return 1 if all tasks are complete, otherwise 0
    return allTasksComplete ? 1 : 0;
  }

  // Returns tasks based on selected category filter
  List<Map<String, dynamic>> getFilteredTasks() {
    if (selectedFilter == 'All') {
      return tasks;
    }

    return tasks.where((task) {
      return task['category'] == selectedFilter;
    }).toList();
  }

  // Smoothly transitions color based on progress
  Color getProgressColor(double progress) {
    if (progress <= 0.5) {
      // From red → orange
      return Color.lerp(Colors.redAccent, Colors.orangeAccent, progress * 2)!;
    } else {
      // From orange → green
      return Color.lerp(
        Colors.orangeAccent,
        Colors.greenAccent,
        (progress - 0.5) * 2,
      )!;
    }
  }

  String getMotivationMessage(double progress) {
    if (tasks.isEmpty) {
      return "Plan your day and start strong 🚀 ";
    }
    if (progress == 0) {
      return "Let’s get started 💪";
    }
    if (progress < 0.25) {
      return "One task at a time 🔥";
    }
    if (progress < 0.5) {
      return "Good start — keep going!";
    }
    if (progress < 0.75) {
      return "Halfway there 👏";
    }
    if (progress < 1) {
      return "You’re on a roll 🔥";
    }
    return "Tasks complete for the day! 🎉";
  }

  // Returns one motivational quote for the selected day
  String getDailyQuote() {
    final dateParts = selectedTaskDate.split('-');

    final selectedDate = DateTime(
      int.parse(dateParts[0]),
      int.parse(dateParts[1]),
      int.parse(dateParts[2]),
    );

    final dayNumber = selectedDate.difference(
      DateTime(selectedDate.year, 1, 1),
    ).inDays;

    final quoteIndex = dayNumber % motivationalQuotes.length;

    return motivationalQuotes[quoteIndex];
  }

  @override
  void dispose() {
    taskController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  // Saves the task list to local phone storage
  Future<void> saveTasks() async {
    final prefs = await SharedPreferences.getInstance();

    // Convert tasks list into a JSON string
    final String encodedTasks = jsonEncode(tasks);

    final String todayKey =
    '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}';

    final String taskKey =
        (selectedTaskDate.isEmpty || selectedTaskDate == todayKey)
            ? 'tasks'
            : 'tasks_$selectedTaskDate';

    await prefs.setString(taskKey, encodedTasks);

    if (selectedTaskDate.isNotEmpty) {
      await prefs.setBool(
        'dayCompleted_$selectedTaskDate',
        dayCompleted,
      );
    }
    await prefs.setInt('streakCounter', streakCounter);
    await prefs.setString('lastCompletedDate', lastCompletedDate);
    await prefs.setString('lastActiveDate', lastActiveDate);
    await prefs.setString('selectedTaskDate', selectedTaskDate);
  }

  // Loads saved tasks from local phone storage
  Future<void> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();

    final DateTime today = DateTime.now();

    final String todayKey = '${today.year}-${today.month}-${today.day}';

    // Load selected date, defaulting to today
    selectedTaskDate = prefs.getString('selectedTaskDate') ?? todayKey;

    final String taskKey =
        (selectedTaskDate.isEmpty || selectedTaskDate == todayKey)
            ? 'tasks'
            : 'tasks_$selectedTaskDate';

    final String? savedTasks = prefs.getString(taskKey);

    if (savedTasks != null) {
      final List decodedTasks = jsonDecode(savedTasks);

      setState(() {
        tasks = decodedTasks.map((task) {
          return Map<String, dynamic>.from(task);
        }).toList();

        final String completedKey = 'dayCompleted_$todayKey';
        dayCompleted = prefs.getBool(completedKey) ?? false;
        streakCounter = prefs.getInt('streakCounter') ?? 0;
        lastCompletedDate = prefs.getString('lastCompletedDate') ?? '';
        lastActiveDate = prefs.getString('lastActiveDate') ?? '';
      });
    } else{
      setState(() {
        final String completedKey = 'dayCompleted_$todayKey';
        dayCompleted = prefs.getBool(completedKey) ?? false;
        streakCounter = prefs.getInt('streakCounter') ?? 0;
        lastCompletedDate = prefs.getString('lastCompletedDate') ?? '';
        lastActiveDate = prefs.getString('lastActiveDate') ?? '';
      });
    }
  }

  Future<void> checkForNewDay() async {
    final prefs = await SharedPreferences.getInstance();

    // Get the current date
    final today = DateTime.now();
    final todayString = getDateKey(today);

    if (lastActiveDate.isEmpty) {
      lastActiveDate = todayString;
      await prefs.setString('lastActiveDate', lastActiveDate);
      return;
    }

    if (lastActiveDate == todayString) return;

    // Preserve the previous day's tasks in its history
    final previousDayTasks = tasks
        .map((task) => Map<String, dynamic>.from(task))
        .toList();

    if (previousDayTasks.isNotEmpty) {
      await prefs.setString(
        'tasks_$lastActiveDate',
        jsonEncode(previousDayTasks),
      );
    }

    // Keep only unfinished tasks
    final incompleteTasks = previousDayTasks.where((task) {
      return task['completed'] != true;
    }).map((task) {
      return Map<String, dynamic>.from(task);
    }).toList();

    setState(() {
      dayCompleted = false;
      lastActiveDate = todayString;
      selectedTaskDate = todayString;
    });

    await prefs.setString('lastActiveDate', todayString);
    await prefs.setString('selectedTaskDate', todayString);
    await prefs.setBool('dayCompleted_$todayString', false);

    // Check whether tasks were already planned for today
    final plannedTodayTasks = prefs.getString('tasks_$todayString');

    if (plannedTodayTasks != null) {
      // Move today's previously planned tasks into the main current-day key
      await prefs.setString('tasks', plannedTodayTasks);

      // Remove the dated copy after moving it
      await prefs.remove('tasks_$todayString');
    } else {
      // Prevent yesterday's tasks from appearing as today's tasks
      await prefs.remove('tasks');
    }

    // Load the correct tasks for the new current day
    await loadTasksForSelectedDate();

    if (!mounted || incompleteTasks.isEmpty) return;

    final shouldCarryOver = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Carry Over Tasks?'),
          content: Text(
            'You have ${incompleteTasks.length} unfinished '
            '${incompleteTasks.length == 1 ? 'task' : 'tasks'} from yesterday.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Skip'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Carry Over'),
            ),
          ],
        );
      },
    );

    if (shouldCarryOver == true) {
      await carryOverIncompleteTasks(incompleteTasks);
    }
  }
  // Carries unfinished tasks from the previous day into today
  Future<void> carryOverIncompleteTasks(
    List<Map<String, dynamic>> incompleteTasks,
  ) async {
    if (incompleteTasks.isEmpty) return;

    setState(() {
      for (final task in incompleteTasks) {
        tasks.add({
          ...task,
          'completed': false,
          'date': selectedTaskDate,
        });
      }
    });

    await saveTasks();
  }

  // Resets the streak if the user missed a day
  Future<void> checkStreakReset() async {
    final prefs = await SharedPreferences.getInstance();

    final DateTime today = DateTime.now();
    final String todayString = '${today.year}-${today.month}-${today.day}';

    final DateTime yesterday = today.subtract(const Duration(days: 1));
    final String yesterdayString =
        '${yesterday.year}-${yesterday.month}-${yesterday.day}';

    if (lastCompletedDate.isNotEmpty &&
        lastCompletedDate != todayString &&
        lastCompletedDate != yesterdayString) {
      setState(() {
        streakCounter = 0;
        dayCompleted = false;
      });

      await prefs.setInt('streakCounter', streakCounter);
      await prefs.setBool(
        'dayCompleted_$todayString',
        dayCompleted,
      );
    }
  }

  // Check if the user is currently viewing today's tasks
  bool isViewingToday() {
    final todayString = getDateKey(DateTime.now());
    return selectedTaskDate == todayString;
  }

  // Returns a date as a unique string key
  String getDateKey(DateTime date) {
    return '${date.year}-${date.month}-${date.day}';
  }

  // Returns the full month and year (e.g. July 2026)
  String getMonthYearLabel(DateTime date) {
    const months = [
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

    return '${months[date.month - 1]} ${date.year}';
  }

  // Returns the correct storage key for the selected date
  String getTaskStorageKey(String dateKey) {
    final today = DateTime.now();
    final todayKey = getDateKey(today);

    return dateKey == todayKey ? 'tasks' : 'tasks_$dateKey';
  }

  // Loads tasks for the selected date from local storage
  Future<void> loadTasksForSelectedDate() async {
    final prefs = await SharedPreferences.getInstance();

    final taskKey = getTaskStorageKey(selectedTaskDate);
    final savedTasks = prefs.getString(taskKey);

    setState(() {
      if (savedTasks != null) {
        final List decodedTasks = jsonDecode(savedTasks);
        tasks = decodedTasks.map((task) {
          return Map<String, dynamic>.from(task);
        }).toList();
      } else {
        tasks = [];
      }

      dayCompleted = prefs.getBool('dayCompleted_$selectedTaskDate') ?? false;
      selectedFilter = 'All';
    });
  }

  // Loads the selected date shared between Home and Calendar
  Future<void> loadSelectedTaskDateFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    final savedDate = prefs.getString('selectedTaskDate');

    if (savedDate != null && savedDate != selectedTaskDate) {
      setState(() {
        selectedTaskDate = savedDate;
      });

      await loadTasksForSelectedDate();
    }
  }



  // Calculates completion progress for a specific day
  Future<double> getProgressForDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();

    final dateKey = getDateKey(date);
    final taskKey = getTaskStorageKey(dateKey);
    final savedTasks = prefs.getString(taskKey);

    if (savedTasks == null) return 0;

    final List decodedTasks = jsonDecode(savedTasks);

    if (decodedTasks.isEmpty) return 0;

    // Count completed tasks for that day
    final completed = decodedTasks.where((task) {
      return task['completed'] == true;
    }).length;

    return completed / decodedTasks.length;
  }

  Future<int> getTaskCountForDate(DateTime date) async {
  final prefs = await SharedPreferences.getInstance();

  final dateKey = getDateKey(date);
  final taskKey = getTaskStorageKey(dateKey);
  final savedTasks = prefs.getString(taskKey);

  if (savedTasks == null) return 0;

  final List decodedTasks = jsonDecode(savedTasks);

  return decodedTasks.length;
}


  // Creates a stable base notification ID for a task.
  int createNotificationId() {
    return DateTime.now().microsecondsSinceEpoch.remainder(1000000000);
  }

  // Converts the saved selected date and reminder time into one DateTime.
  DateTime buildReminderDateTime({
    required String dateKey,
    required TimeOfDay reminderTime,
  }) {
    final selectedDate = DateTime.parse(dateKey);

    return DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      reminderTime.hour,
      reminderTime.minute,
    );
  }

  // Schedules the main reminder and priority-based follow-up reminders.
  Future<void> scheduleSmartReminders({
    required int notificationId,
    required String taskTitle,
    required String? priority,
    required DateTime reminderDateTime,
  }) async {
    if (reminderDateTime.isBefore(DateTime.now())) {
      return;
    }

    // Main reminder.
    await NotificationService.scheduleNotification(
      id: notificationId,
      title: 'Task Reminder',
      body: taskTitle,
      scheduledTime: reminderDateTime,
    );

    // High-priority tasks receive two additional reminders.
    if (priority == '🔴 High') {
      await NotificationService.scheduleNotification(
        id: notificationId + 1,
        title: 'High Priority Task',
        body: '$taskTitle is still waiting.',
        scheduledTime: reminderDateTime.add(
          const Duration(minutes: 30),
        ),
      );

      await NotificationService.scheduleNotification(
        id: notificationId + 2,
        title: 'High Priority Task',
        body: 'Do not forget to complete: $taskTitle',
        scheduledTime: reminderDateTime.add(
          const Duration(minutes: 60),
        ),
      );
    }

    // Medium-priority tasks receive one follow-up.
    if (priority == '🟡 Medium') {
      await NotificationService.scheduleNotification(
        id: notificationId + 1,
        title: 'Task Follow-Up',
        body: 'Remember to complete: $taskTitle',
        scheduledTime: reminderDateTime.add(
          const Duration(minutes: 60),
        ),
      );
    }
  }

  // Cancels every notification that may belong to a task.
  Future<void> cancelTaskReminders(Map<String, dynamic> task) async {
    final notificationId = task['notificationId'];

    if (notificationId is! int) return;

    await NotificationService.cancelNotification(notificationId);
    await NotificationService.cancelNotification(notificationId + 1);
    await NotificationService.cancelNotification(notificationId + 2);
  }

  // Converts a saved reminder time (ex: "2:30 PM") back into a TimeOfDay object
  TimeOfDay? parseReminderTime(String? reminderText) {

    // If no reminder exists, return nothing
    if (reminderText == null || reminderText.trim().isEmpty) {
      return null;
    }

    // Extract the hour, minute, and AM/PM using a regular expression
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(reminderText.trim());

    // If the reminder format is invalid, return nothing
    if (match == null) {
      return null;
    }

    // Read the hour and minute from the saved reminder
    int hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);

    // Store whether the reminder is AM or PM
    final period = match.group(3)!.toUpperCase();

    // Convert PM time into 24-hour format (except for 12 PM)
    if (period == 'PM' && hour != 12) {
      hour += 12;
    }

    // Convert 12 AM into midnight (0:00)
    if (period == 'AM' && hour == 12) {
      hour = 0;
    }

    // Return the converted reminder time
    return TimeOfDay(
      hour: hour,
      minute: minute,
    );
  }


  void showAddTaskPopup() {

    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.black,
              title: const Text('Add Task', style: TextStyle(color: Colors.white)),
              content: SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                      TextField(
                        controller: taskController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Task name',
                          labelStyle: TextStyle(color: Colors.white),
                        ),
                      ),

                      const SizedBox(height: 16),

                      TextField(
                        controller: descriptionController,
                        style: const TextStyle(color: Colors.white),
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description (Optional)',
                          labelStyle: TextStyle(color: Colors.white70),
                          alignLabelWithHint: true,
                        ),
                      ),

                      const SizedBox(height: 20),
 
                    DropdownButton<String>(
                        value: selectedCategory,
                        dropdownColor: Colors.black,
                        isExpanded: true,
                        style: const TextStyle(color: Colors.white),

                        items: categories.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),

                        onChanged: (value) {
                          setDialogState(() {
                            selectedCategory = value!;
                          });
                        },
                      ),
                      DropdownButton<String>(
                        value: selectedPriority,
                        hint: const Text(
                          'Optional Priority',
                          style: TextStyle(color: Colors.white70),
                        ),
                        dropdownColor: Colors.black,
                        isExpanded: true,
                        style: const TextStyle(color: Colors.white),

                        items: priorities.map((priority) {
                          return DropdownMenuItem(
                            value: priority,
                            child: Text(priority),
                          );
                        }).toList(),

                        onChanged: (value) {
                          setDialogState(() {
                            selectedPriority = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      ListTile(
                        title: Text(
                          selectedReminderTime == null
                              ? 'Set Reminder'
                              : 'Reminder: ${selectedReminderTime!.format(context)}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        trailing: const Icon(
                          Icons.notifications,
                          color: Colors.white,
                        ),
                        onTap: () async {
                          TimeOfDay tempReminderTime =
                              selectedReminderTime ?? TimeOfDay.now();

                          await showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.black,
                            builder: (context) {
                              return SizedBox(
                                height: 300,
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text(
                                              'Cancel',
                                              style: TextStyle(color: Colors.white),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              setDialogState(() {
                                                selectedReminderTime = tempReminderTime;
                                              });

                                              Navigator.pop(context);
                                            },
                                            child: const Text(
                                              'Done',
                                              style: TextStyle(color: Colors.white),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    const Divider(color: Colors.white24),

                                    Expanded(
                                      child: CupertinoTheme(
                                        data: const CupertinoThemeData(
                                          brightness: Brightness.dark,
                                        ),
                                        child: CupertinoDatePicker(
                                          mode: CupertinoDatePickerMode.time,
                                          use24hFormat: false,
                                          initialDateTime: DateTime(
                                            2026,
                                            1,
                                            1,
                                            tempReminderTime.hour,
                                            tempReminderTime.minute,
                                          ),
                                          onDateTimeChanged: (newTime) {
                                            tempReminderTime = TimeOfDay(
                                              hour: newTime.hour,
                                              minute: newTime.minute,
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                        onPressed: () {
                          setDialogState(() {
                            selectedReminderTime = null;
                          });
                        },
                        child: const Text(
                          'Clear Reminder',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ),
                ],
              )
            ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                taskController.clear();
                descriptionController.clear();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newTaskTitle = taskController.text.trim();

                if (newTaskTitle.isEmpty) {
                  return;
                }

                final reminderToSchedule = selectedReminderTime;
                final notificationId = createNotificationId();

                final newTask = <String, dynamic>{
                  'title': newTaskTitle,
                  'description': descriptionController.text.trim(),
                  'completed': false,
                  'category': selectedCategory,
                  'priority': selectedPriority,
                  'reminderTime': selectedReminderTime?.format(context),
                  'notificationId': notificationId,
                  'date': selectedTaskDate,
                };

                setState(() {
                  tasks.add(newTask);
                });

                if (reminderToSchedule != null) {
                  final reminderDateTime = buildReminderDateTime(
                    dateKey: selectedTaskDate,
                    reminderTime: reminderToSchedule,
                  );

                  await scheduleSmartReminders(
                    notificationId: notificationId,
                    taskTitle: newTaskTitle,
                    priority: selectedPriority,
                    reminderDateTime: reminderDateTime,
                  );
                }

                await saveTasks();

                if (!mounted) return;

                Navigator.pop(context);

                taskController.clear();
                descriptionController.clear();

                setState(() {
                  selectedPriority = null;
                  selectedReminderTime = null;
                });
              },
              child: const Text('Add'),
            ),
          ],
        );
      });
    });
  }

  Widget taskTile({
    required String title,
    required bool completed,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Icon(
          completed
              ? Icons.check_circle
              : Icons.radio_button_unchecked,
          color:
              completed
                  ? Colors.greenAccent
                  : Colors.white54,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: Colors.white,
            decoration:
                completed
                    ? TextDecoration.lineThrough
                    : null,
          ),
        ),
      ),
    );
  }


  void showEditTaskPopup(Map<String, dynamic> task) {
    final editController = TextEditingController(text: task['title']);
    final editDescriptionController = TextEditingController(
    text: task['description'] ?? '',);
    String editCategory = task['category'] ?? selectedCategory;
    String? editPriority = task['priority'];
    String? editReminderTime = task['reminderTime'];



    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.black,
              title: const Text(
                'Edit Task',
                style: TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: editController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Task name',
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: editDescriptionController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                        labelStyle: TextStyle(color: Colors.white70),
                        alignLabelWithHint: true,
                      ),
                    ),

                    const SizedBox(height: 16),

                    DropdownButton<String>(
                      value: editCategory,
                      dropdownColor: Colors.black,
                      isExpanded: true,
                      style: const TextStyle(color: Colors.white),
                      items: categories.map((category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          editCategory = value!;
                        });
                      },
                    ),

                    const SizedBox(height: 16),

                    DropdownButton<String>(
                      value: editPriority,
                      hint: const Text(
                        'Optional Priority',
                        style: TextStyle(color: Colors.white70),
                      ),
                      dropdownColor: Colors.black,
                      isExpanded: true,
                      style: const TextStyle(color: Colors.white),
                      items: priorities.map((priority) {
                        return DropdownMenuItem<String>(
                          value: priority,
                          child: Text(priority),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          editPriority = value!;
                        });
                      },
                    ),

                    Align(
                      alignment: Alignment.centerLeft,
                        child: TextButton(
                        onPressed: () {
                          setDialogState(() {
                            editPriority = null;
                          });
                        },
                        child: const Text(
                          'Clear Priority',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    ListTile(
                      title: Text(
                        editReminderTime == null
                            ? 'Set Reminder'
                            : 'Reminder: $editReminderTime',
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: const Icon(
                        Icons.notifications,
                        color: Colors.white,
                      ),
                      onTap: () async {
                        TimeOfDay tempReminderTime = TimeOfDay.now();

                        // If a reminder already exists, use it as the initial picker value
                        if (editReminderTime != null) {
                          final parts = editReminderTime!.split(':');

                          if (parts.length == 2) {
                            int hour = int.parse(parts[0]);
                            final minuteAndPeriod = parts[1].split(' ');

                            int minute = int.parse(minuteAndPeriod[0]);

                            if (minuteAndPeriod.length == 2) {
                              final period = minuteAndPeriod[1];

                              if (period == 'PM' && hour != 12) {
                                hour += 12;
                              }

                              if (period == 'AM' && hour == 12) {
                                hour = 0;
                              }
                            }

                            tempReminderTime = TimeOfDay(
                              hour: hour,
                              minute: minute,
                            );
                          }
                        }

                        await showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.black,
                          builder: (context) {
                            return SizedBox(
                              height: 300,
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text(
                                            'Cancel',
                                            style: TextStyle(color: Colors.white),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            setDialogState(() {
                                              editReminderTime =
                                                  tempReminderTime.format(context);
                                            });

                                            Navigator.pop(context);
                                          },
                                          child: const Text(
                                            'Done',
                                            style: TextStyle(color: Colors.white),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const Divider(color: Colors.white24),

                                  Expanded(
                                    child: CupertinoTheme(
                                      data: const CupertinoThemeData(
                                        brightness: Brightness.dark,
                                      ),
                                      child: CupertinoDatePicker(
                                        mode: CupertinoDatePickerMode.time,
                                        use24hFormat: false,
                                        initialDateTime: DateTime(
                                          2026,
                                          1,
                                          1,
                                          tempReminderTime.hour,
                                          tempReminderTime.minute,
                                        ),
                                        onDateTimeChanged: (newTime) {
                                          tempReminderTime = TimeOfDay(
                                            hour: newTime.hour,
                                            minute: newTime.minute,
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),


                    TextButton(
                      onPressed: () {
                        setDialogState(() {
                          editReminderTime = null;
                        });
                      },
                      child: const Text(
                        'Clear Reminder',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [

                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),

                ElevatedButton(
                  onPressed: () async {

                    // Get the updated task name and remove extra spaces
                    final updatedTitle = editController.text.trim();

                    // Do not save if the task name is empty
                    if (updatedTitle.isEmpty) {
                      return;
                    }

                    // Cancel all notifications connected to the task's old reminder settings
                    await cancelTaskReminders(task);

                    // Reuse the task's existing notification ID if it already has one
                    final existingNotificationId = task['notificationId'];

                    // Create a notification ID for older tasks that do not have one yet
                    final int notificationId = existingNotificationId is int
                        ? existingNotificationId
                        : createNotificationId();

                    // Update the task information
                    setState(() {
                      task['title'] = updatedTitle;
                      task['description'] =
                          editDescriptionController.text.trim();
                      task['category'] = editCategory;
                      task['priority'] = editPriority;
                      task['reminderTime'] = editReminderTime;
                      task['notificationId'] = notificationId;
                    });

                    // Convert the saved reminder text back into a TimeOfDay object
                    final editedTime = parseReminderTime(editReminderTime);

                    // Only schedule new reminders if:
                    // 1. A reminder time exists
                    // 2. The task is not already completed
                    if (editedTime != null && task['completed'] != true) {

                      // Build the full date and time for the edited reminder
                      final reminderDateTime = buildReminderDateTime(
                        dateKey: task['date'] ?? selectedTaskDate,
                        reminderTime: editedTime,
                      );

                      // Schedule the updated smart reminders
                      await scheduleSmartReminders(
                        notificationId: notificationId,
                        taskTitle: updatedTitle,
                        priority: editPriority,
                        reminderDateTime: reminderDateTime,
                      );
                    }

                    // Save the updated task list to local storage
                    await saveTasks();

                    // Stop if the screen was closed while awaiting
                    if (!mounted) return;

                    // Close the Edit Task popup
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadSelectedTaskDateFromPrefs();
    });
    final int completedTasks = tasks.where((task) => task['completed'] == true).length;
    final double progress = tasks.isEmpty ? 0: completedTasks / tasks.length;

    final List<Map<String, dynamic>> filteredTasks = getFilteredTasks();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('TrakOn'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      DateTime.now().hour < 12
                          ? 'Good Morning, $userName 👋'
                          : DateTime.now().hour < 17
                              ? 'Good Afternoon, $userName 👋'
                              : 'Good Evening, $userName 👋',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      children: [
                        const Text('🔥', style: TextStyle(fontSize: 28)),
                        Text(
                          '$streakCounter',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'Day Streak',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              const Text(
                'Welcome back to TrakOn!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              
              const Text(
                'Track. Focus. Achieve.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 24),

              // Daily motivational quote card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white12,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '💡 Daily Motivation',
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      getDailyQuote(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Progress Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Today’s Progress',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // BIG custom progress bar
                    Container(
                      height: 30, // 👈 adjust this (20–30 looks great)
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progress, // fills based on progress
                        child: Container(
                          decoration: BoxDecoration(
                            color: getProgressColor(progress),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                  
                  // Motivational messages
                  const SizedBox(height: 10),

                  Text(
                    getMotivationMessage(progress),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w500
                    ),
                  ),

                  const SizedBox(height: 15),
                  
              // Complete Task Button
                ElevatedButton(
                  onPressed: isViewingToday() ? () async {
                    if (dayCompleted) {
                      await undoCompleteDay();
                    } else{
                      final bool? confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Complete Day'),
                          content: const Text(
                            'Are you sure you completed your day?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('No'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Yes'),
                            ),
                          ],
                        ),
                      );

                        if (confirm == true) {
                          completeDay();
                        }
                    }
                  }
                  : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  child: Text(
                    dayCompleted
                    ? '✅ Day Complete'
                    : '⭕ Mark Day Complete',
                  ),
                ),

                const SizedBox(height: 20),

                const SizedBox(height: 8),

                    Text(
                      '${(progress * 100).toInt()}% complete',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      getMonthYearLabel(DateTime.now()),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 14),

                    SizedBox(
                      height: 110,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(7, (index) {
                          final date = DateTime.now().add(Duration(days: index));
                          final dateKey = getDateKey(date);
                          final todayKey = getDateKey(DateTime.now());

                          final isSelected = selectedTaskDate == dateKey;
                          final isToday = dateKey == todayKey;

                          final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

                          return FutureBuilder<double>(
                            future: getProgressForDate(date),
                            builder: (context, progressSnapshot) {
                              final dayProgress = progressSnapshot.data ?? 0;

                              final ringColor = dayProgress == 0
                                  ? Colors.white24
                                  : getProgressColor(dayProgress);

                              return FutureBuilder<int>(
                                future: getTaskCountForDate(date),
                                builder: (context, countSnapshot) {
                                  final taskCount = countSnapshot.data ?? 0;

                                  return GestureDetector(
                                    onTap: () async {
                                      await saveTasks();

                                      final prefs = await SharedPreferences.getInstance();

                                      setState(() {
                                        selectedTaskDate = dateKey;
                                      });

                                      await prefs.setString('selectedTaskDate', selectedTaskDate);

                                      await loadTasksForSelectedDate();
                                    },
                                    child: Container(
                                      width: 48,
                                      decoration: BoxDecoration(
                                        color: isSelected ? Colors.white12 : Colors.transparent,
                                        borderRadius: BorderRadius.circular(18),
                                        border: isSelected
                                            ? Border.all(color: ringColor, width: 1.5)
                                            : isToday
                                                ? Border.all(color: Colors.white54, width: 1)
                                                : null,
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            dayNames[date.weekday - 1],
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                          ),

                                          const SizedBox(height: 8),

                                          CustomPaint(
                                            painter: DayProgressPainter(
                                              progress: dayProgress,
                                              color: ringColor,
                                            ),
                                            child: SizedBox(
                                              width: 42,
                                              height: 42,
                                              child: Center(
                                                child: Text(
                                                  '${date.day}',
                                                  style: TextStyle(
                                                    color: isSelected
                                                        ? ringColor
                                                        : isToday
                                                            ? Colors.white
                                                            : Colors.white70,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),

                                          const SizedBox(height: 6),

                                          Text(
                                            taskCount == 1 ? '1 task' : '$taskCount tasks',
                                            style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),

              // Category filter buttons
              DropdownButton<String>(
                value: selectedFilter,
                dropdownColor: Colors.grey[900],
                isExpanded: true,
                style: const TextStyle(color: Colors.white),
                items: ['All', ... categories].map((filter) {
                  return DropdownMenuItem<String>(
                    value: filter,
                    child: Text(filter),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedFilter = value!;
                  });
                },
              ),

              const SizedBox(height: 24),

              // TASK LIST
              filteredTasks.isEmpty
                  ? const Center(
                      child: Text(
                        'No tasks yet. Add your first task below.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 16,
                          height: 1.4,
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredTasks.length,
                        itemBuilder: (context, index) {
                          return Card(
                            color: Colors.white10,
                            child: ListTile(
                              leading: GestureDetector(
                                onTap: () async {

                                  // Get the task that the user tapped
                                  final task = filteredTasks[index];

                                  // Determine the task's new completion status
                                  final bool isNowCompleted = task['completed'] != true;

                                  // Update the task's completed value
                                  setState(() {
                                    task['completed'] = isNowCompleted;
                                  });

                                  // If the task was just completed, cancel all remaining reminders
                                  if (isNowCompleted) {
                                    await cancelTaskReminders(task);
                                  } else {

                                    // If the task was marked incomplete again,
                                    // try to restore its reminders
                                    final reminderTime = parseReminderTime(
                                      task['reminderTime'],
                                    );

                                    // Only continue if the task has a reminder time
                                    if (reminderTime != null) {

                                      // Get the task's saved notification ID
                                      final notificationId = task['notificationId'];

                                      // Only reschedule if the notification ID is valid
                                      if (notificationId is int) {

                                        // Build the task's full reminder date and time
                                        final reminderDateTime = buildReminderDateTime(
                                          dateKey: task['date'] ?? selectedTaskDate,
                                          reminderTime: reminderTime,
                                        );

                                        // Schedule the reminders again based on priority
                                        await scheduleSmartReminders(
                                          notificationId: notificationId,
                                          taskTitle: task['title'].toString(),
                                          priority: task['priority']?.toString(),
                                          reminderDateTime: reminderDateTime,
                                        );
                                      }
                                    }
                                  }

                                  // Save the updated task list
                                  await saveTasks();
                                },
                                child: CustomPaint(
                                  painter: DayProgressPainter(
                                    progress: filteredTasks[index]['completed'] == true ? 1.0 : 0.0,
                                  ),
                                  child: SizedBox(
                                    width: 34,
                                    height: 34,
                                    child: Center(
                                      child: filteredTasks[index]['completed'] == true
                                          ? const Icon(
                                              Icons.check,
                                              color: Colors.greenAccent,
                                              size: 20,
                                            )
                                          : const SizedBox(),
                                    ),
                                  ),
                                ),
                              ),
                              title: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                  '${filteredTasks[index]['category'] ?? '🏠 Personal'} • ${filteredTasks[index]['title']}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    decoration: filteredTasks[index]['completed']
                                        ? TextDecoration.lineThrough
                                        : TextDecoration.none,
                                  ),
                                  ),

                                  if ((filteredTasks[index]['description'] ?? '').toString().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        filteredTasks[index]['description'],
                                        style: const TextStyle(
                                          color: Colors.white60,
                                          fontSize: 13,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),

                                  if(filteredTasks[index]['priority'] != null)
                                    Text(
                                      filteredTasks[index]['priority'],
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                  ),
                                  if (filteredTasks[index]['reminderTime'] != null)
                                    Text(
                                      '🔔 ${filteredTasks[index]['reminderTime']}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      color: Colors.greenAccent,
                                    ),
                                    onPressed: () {
                                      // edit task code here
                                      showEditTaskPopup(filteredTasks[index]);
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                    Icons.delete,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () async {

                                    // Get the task the user wants to delete
                                    final taskToDelete = filteredTasks[index];

                                    // Cancel all scheduled reminders connected to this task
                                    await cancelTaskReminders(taskToDelete);

                                    // Remove the task from the task list
                                    setState(() {
                                      tasks.remove(taskToDelete);
                                    });

                                    // Save the updated task list
                                    await saveTasks();
                                  },
                                ),
                                ],
                            ),
                            ),
                          );
                        },
                      ),

              const SizedBox(height: 24),

              // ADD TASK BUTTON
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: showAddTaskPopup,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Task'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),




              if (getProgress() == 1 && tasks.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Center(
                    child: Text(
                      'Tasks complete for the day! 🎉',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
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

class DayProgressPainter extends CustomPainter {
  final double progress;
  final Color color;

  DayProgressPainter({
    required this.progress,
    this.color = Colors.greenAccent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final backgroundPaint = Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(DayProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}