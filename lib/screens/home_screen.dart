import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';

import 'package:flutter/cupertino.dart';

import 'notification_preferences.dart';
import 'task_search_screen.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/recurring_reminder_plan.dart';

// ---------------------------
// Home Screen
// ---------------------------
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _homeReady = false;
  Future<void> _recurringReminderUpdates = Future<void>.value();
  // List to store tasks
  List<Map<String, dynamic>> tasks = [];

  // Controller to get input text
  final TextEditingController taskController = TextEditingController();

  // Controller for optional task description
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController searchController = TextEditingController();
  String searchQuery = '';
  List<Map<String, dynamic>> availableGoals = [];
  String? selectedGoalId;
  final TextEditingController tagsController = TextEditingController();

  // Store the category selected in the dropdown
  String selectedCategory = '🏠 Personal';

  // Store the priority level is currently selected
  String? selectedPriority;

  // Stores the selected repeat option for a task
  String selectedRepeat = 'Never';

  // Stores selected weekdays for "Specific Days"
  Set<int> selectedRepeatDays = {};

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
    'A clear next step is more useful than a perfect plan.',
    'Give your most important task a place in your day.',
    'Start with five minutes and see where it takes you.',
    'You can begin again without starting from zero.',
    'A focused minute is a minute well spent.',
    'Leave room in your day for what matters to you.',
    'Make the next step small enough to take today.',
    'Your pace can change while your direction stays steady.',
    'A plan becomes useful when you put it into practice.',
    'Let a small win set the tone for your day.',
    'Write it down, then take one step toward it.',
    'Return to your goal as often as you need to.',
    'A fresh start can happen in the middle of the day.',
    'Choose one thing to finish before choosing the next.',
    'Give yourself credit for the work you actually did.',
    'A quieter day can still be a productive day.',
    'Make time for the habits you want to keep.',
    'You can do meaningful work in small pockets of time.',
    'Let your calendar reflect your priorities.',
    'Checking in with yourself is part of making progress.',
    'Your next action does not need to be a big one.',
    'Protect a little time for your biggest goal.',
    'Keep your plan simple enough to follow.',
    'Getting back on track is a skill you can practice.',
    'The task in front of you deserves your attention.',
    'Build a routine that fits the life you have.',
    'A realistic plan is a strong foundation.',
    'Celebrate the steps you used to put off.',
    'Set a direction, then give yourself time to move.',
    'You do not need a perfect morning to have a good day.',
    'One finished task can clear space in your mind.',
    'Let your next choice support what matters most.',
    'Make a little room for learning today.',
    'A thoughtful pause can help you choose your next step.',
    'Keep going at a pace you can sustain.',
    'Let a clear priority guide a busy day.',
    'You are allowed to adjust the plan and keep the goal.',
    'A useful habit starts with something repeatable.',
    'There is value in finishing the simple things.',
    'Turn one someday into something you do today.',
    'You can be ambitious and patient at the same time.',
    'Give your attention to the step you can take now.',
    'Make your goals easier to act on, one detail at a time.',
    'A small promise kept can strengthen your confidence.',
    'You have permission to start before everything is ready.',
    'Look for the next useful action, not the perfect moment.',
    'Good routines leave space for real life.',
    'A little preparation can make tomorrow easier.',
    'Choose a task that moves your day forward.',
    'Take a breath, check your plan, and begin.',
    'Time spent practicing is time spent growing.',
    'Let completed tasks remind you of what you can do.',
    'You can make progress without doing everything at once.',
    'A steady rhythm is built one day at a time.',
    'Work toward a day you can feel good about.',
    'Focus is something you can return to.',
    'Make the important things easier to remember.',
    'Break a big goal into a step you can finish.',
    'The next chapter begins with the next action.',
    'Leave yourself a clear starting point for tomorrow.',
    'You can learn from a missed day and move forward.',
    'A manageable task is an invitation to begin.',
    'Give your ideas a chance by taking action.',
    'Let your effort match your priorities.',
    'Keep a little space for the unexpected.',
    'Build confidence through promises you can keep.',
    'Make today a little easier for your future self.',
    'A clear list can turn worry into a next step.',
    'Your progress deserves attention, even when it is quiet.',
    'Finish one thing with care today.',
    'Create a routine you can return to after a busy week.',
    'Your goals can grow as you learn.',
    'Small steps are easier to repeat than giant leaps.',
    'Bring your attention back to what you chose to do.',
    'A new day is a chance to practice again.',
    'Plan for the energy you have, then take a useful step.',
    'You can change your approach without giving up.',
    'A good system helps you show up on ordinary days.',
    'Notice what worked and do a little more of it.',
    'Progress includes learning how to begin again.',
    'Give yourself a task you can complete with confidence.',
    'Keep your next step visible.',
    'Choose a little action over a little more hesitation.',
    'You can simplify the plan and still move forward.',
    'Your attention is worth protecting.',
    'Set aside a moment to recognize a win.',
    'Make room for both effort and recovery.',
    'A useful day begins with an intentional choice.',
    'Let your goals guide you without rushing you.',
    'You can make a difference in the time you have.',
    'Move one important task from planned to done.',
    'A flexible plan is easier to keep using.',
    'Create momentum with something you can finish now.',
    'Start again with what you have learned.',
    'The work you finish today gives tomorrow a clearer start.',
    'Give your day one clear intention.',
    'A little order can make space for a little creativity.',
    'Keep making choices that support the life you want.',
    'You are building something with every thoughtful step.',
    'Your next small win is worth starting.',
  ];

  // Stores dynamic username for login
  String userName = 'User';

  // Store selected Reminder Time
  TimeOfDay? selectedReminderTime;

  // Optional scheduled time window for a task.
  // These remain null when the user does not want
  // to assign a specific start or end time.
  TimeOfDay? selectedStartTime;
  TimeOfDay? selectedEndTime;

  // Tracks the task's current workflow status.
  // New tasks begin as "Not Started".
  String selectedStatus = 'Not Started';

  // ---------------------------------------------------------------------------
  // USER-SPECIFIC LOCAL STORAGE
  // ---------------------------------------------------------------------------

  // Returns the Firebase UID for the currently signed-in TrakOn user.
  // Every user's local data is stored under their own UID so accounts
  // on the same device can never read each other's tasks.
  String get currentUserId {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError('No authenticated user is available.');
    }

    return user.uid;
  }

  // Creates a SharedPreferences key that belongs only to the
  // currently authenticated Firebase user.
  String userKey(String key) {
    return '${currentUserId}_$key';
  }

  // ---------------------------------------------------------------------------
  // FIRESTORE CLOUD BACKUP / RESTORE
  // ---------------------------------------------------------------------------

  // Points to the signed-in user's Firestore profile document. Task data is
  // stored in a taskDays subcollection so it stays separate from profile fields.
  DocumentReference<Map<String, dynamic>> get userCloudDocument {
    return FirebaseFirestore.instance.collection('users').doc(currentUserId);
  }

  // Saves one day's complete task list to Firestore. Local SharedPreferences
  // remains the fast/offline cache, while Firestore protects data across
  // reinstalls and devices.
  Future<void> saveTaskDayToCloud(
    String dateKey,
    List<Map<String, dynamic>> taskList,
  ) async {
    try {
      await userCloudDocument.collection('taskDays').doc(dateKey).set({
        'tasks': taskList,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error) {
      debugPrint('Could not save tasks to Firestore: $error');
    }
  }

  // Loads one day's task list from Firestore. Returns null when no cloud backup
  // exists yet, allowing the caller to fall back to local storage.
  Future<List<Map<String, dynamic>>?> loadTaskDayFromCloud(
    String dateKey,
  ) async {
    try {
      final snapshot = await userCloudDocument
          .collection('taskDays')
          .doc(dateKey)
          .get();

      if (!snapshot.exists) return null;

      final data = snapshot.data();
      final cloudTasks = data?['tasks'];

      if (cloudTasks is! List) return null;

      return cloudTasks
          .map((task) => Map<String, dynamic>.from(task as Map))
          .toList();
    } catch (error) {
      debugPrint('Could not load tasks from Firestore: $error');
      return null;
    }
  }


  // Stores cloud-backed app state that is not tied to one task date.
  DocumentReference<Map<String, dynamic>> get userAppStateDocument {
    return userCloudDocument.collection('appData').doc('state');
  }

  Future<Map<String, dynamic>?> loadAppStateFromCloud() async {
    try {
      final snapshot = await userAppStateDocument.get();
      return snapshot.data();
    } catch (error) {
      debugPrint('Could not load app state from Firestore: $error');
      return null;
    }
  }

  Future<void> saveAppStateFieldsToCloud(
    Map<String, dynamic> fields,
  ) async {
    try {
      await userAppStateDocument.set({
        ...fields,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error) {
      debugPrint('Could not save app state to Firestore: $error');
    }
  }

  Future<void> saveDayCompletionToCloud(
    String dateKey,
    bool completed,
  ) async {
    try {
      await userCloudDocument.collection('taskDays').doc(dateKey).set({
        'dayCompleted': completed,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error) {
      debugPrint('Could not save day completion to Firestore: $error');
    }
  }

  Future<bool?> loadDayCompletionFromCloud(String dateKey) async {
    try {
      final snapshot =
          await userCloudDocument.collection('taskDays').doc(dateKey).get();

      if (!snapshot.exists) return null;

      final value = snapshot.data()?['dayCompleted'];
      return value is bool ? value : null;
    } catch (error) {
      debugPrint('Could not load day completion from Firestore: $error');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // TASK STATUS OPTIONS
  // ---------------------------------------------------------------------------

  // Status options used throughout TrakOn.
  // Each status has a label and matching visual icon.
  final List<Map<String, dynamic>> taskStatuses = [
    {'label': 'Not Started', 'icon': Icons.radio_button_unchecked},
    {'label': 'In Progress', 'icon': Icons.play_circle_outline},
    {'label': 'Complete', 'icon': Icons.check_circle_outline},
  ];

  // Loads saved username/full name from local storage
  Future<void> loadUserName() async {
    final user = FirebaseAuth.instance.currentUser;

    if (!mounted) return;

    setState(() {
      userName = user?.displayName?.trim().isNotEmpty == true
          ? user!.displayName!.trim()
          : 'User';
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
  final List<String> priorities = ['🔴 High', '🟡 Medium', '🟢 Low'];
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

  // Controls which week is displayed in the weekly calendar preview
  DateTime displayedWeekStart = DateTime.now();

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

    final String todayString = '${today.year}-${today.month}-${today.day}';

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

    await prefs.setBool(userKey('dayCompleted_$todayString'), dayCompleted);
    await prefs.setInt(userKey('streakCounter'), streakCounter);
    await prefs.setString(userKey('lastCompletedDate'), lastCompletedDate);

    await saveDayCompletionToCloud(todayString, dayCompleted);
    await saveAppStateFieldsToCloud({
      'streakCounter': streakCounter,
      'lastCompletedDate': lastCompletedDate,
      'lastActiveDate': lastActiveDate,
    });

    final notificationsEnabled =
        await NotificationPreferences.notificationsEnabled();

    final streakNotificationsEnabled =
        await NotificationPreferences.streakNotificationsEnabled();

    if (notificationsEnabled && streakNotificationsEnabled) {
      await NotificationService.showDayCompletedNotification();

      await NotificationService.showStreakNotification(
        streakCount: streakCounter,
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Day completed! Streak updated 🔥')),
    );
  }

  // Reverses the completed day status and lowers the streak if needed
  Future<void> undoCompleteDay() async {
    final prefs = await SharedPreferences.getInstance();

    if (!isViewingToday()) return;

    final DateTime today = DateTime.now();

    final String todayString = '${today.year}-${today.month}-${today.day}';

    setState(() {
      dayCompleted = false;

      if (streakCounter > 0) {
        streakCounter -= 1;
      }

      lastCompletedDate = '';
    });

    await prefs.setBool(userKey('dayCompleted_$todayString'), dayCompleted);
    await prefs.setInt(userKey('streakCounter'), streakCounter);
    await prefs.setString(userKey('lastCompletedDate'), lastCompletedDate);

    await saveDayCompletionToCloud(todayString, dayCompleted);
    await saveAppStateFieldsToCloud({
      'streakCounter': streakCounter,
      'lastCompletedDate': lastCompletedDate,
      'lastActiveDate': lastActiveDate,
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Day status updated.')));
  }

  // Runs when Home screen is first opened and loads the saved username
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final now = DateTime.now();

    // Starts the weekly preview on the most recent Sunday
    displayedWeekStart = now.subtract(Duration(days: now.weekday % 7));
    initializeHomeScreen();
    loadGoals();
    loadUserName();
  }

  Future<void> loadGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(userKey('goals'));

    var loadedGoals = <Map<String, dynamic>>[];

    if (saved != null) {
      try {
        loadedGoals = (jsonDecode(saved) as List)
            .map((goal) => Map<String, dynamic>.from(goal as Map))
            .toList();

        await saveAppStateFieldsToCloud({'goals': loadedGoals});
      } catch (_) {
        loadedGoals = [];
      }
    } else {
      final cloudState = await loadAppStateFromCloud();
      final cloudGoals = cloudState?['goals'];

      if (cloudGoals is List) {
        loadedGoals = cloudGoals
            .map((goal) => Map<String, dynamic>.from(goal as Map))
            .toList();

        await prefs.setString(userKey('goals'), jsonEncode(loadedGoals));
      }
    }

    if (!mounted) return;

    setState(() {
      availableGoals = loadedGoals;
    });
  }

  Future<void> openTaskSearch() async {
    await saveTasks();
    if (!mounted) return;
    final result = await Navigator.of(context).push<TaskSearchResult>(
      MaterialPageRoute(builder: (_) => const TaskSearchScreen()),
    );
    if (result == null || !mounted) return;
    setState(() {
      selectedTaskDate = result.date;
      final date = parseDateKey(result.date);
      displayedWeekStart = date.subtract(Duration(days: date.weekday % 7));
      searchController.clear();
      searchQuery = '';
    });
    await loadTasksForSelectedDate();
    if (!mounted) return;
    final matching = tasks.where(
      (task) =>
          task['notificationId'] == result.notificationId &&
          task['title']?.toString() == result.title,
    );
    if (matching.isNotEmpty) showTaskDetails(matching.first);
  }

  Future<void> initializeHomeScreen() async {
    await loadTasks();
    await checkForNewDay();
    await checkStreakReset();
    await refreshAllRecurringReminders();
    _homeReady = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _homeReady) {
      refreshRemindersOnResume();
    }
  }

  Future<void> refreshRemindersOnResume() async {
    await checkForNewDay();
    if (!mounted) return;
    await refreshAllRecurringReminders();
    await refreshDailyTaskNotifications();
  }

  // Calculates the user's current streak
  int getCurrentStreak() {
    // If there are no tasks, streak is 0
    if (tasks.isEmpty) return 0;

    // Check if every task is completed
    final bool allTasksComplete = tasks.every(
      (task) => task['completed'] == true,
    );

    // Return 1 if all tasks are complete, otherwise 0
    return allTasksComplete ? 1 : 0;
  }

  // Returns tasks based on selected category filter
  List<Map<String, dynamic>> getFilteredTasks() {
    return tasks.where((task) {
      final matchesCategory =
          selectedFilter == 'All' || task['category'] == selectedFilter;
      final query = searchQuery.trim().toLowerCase();
      final matchesSearch =
          query.isEmpty ||
          (task['title']?.toString() ?? '').toLowerCase().contains(query) ||
          (task['description']?.toString() ?? '').toLowerCase().contains(
            query,
          ) ||
          (task['tags'] is List &&
              (task['tags'] as List).any(
                (tag) => tag.toString().toLowerCase().contains(query),
              ));
      return matchesCategory && matchesSearch;
    }).toList();
  }

  void offerUndoStatus(
    Map<String, dynamic> task,
    String previousStatus,
    String date,
  ) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Task status updated'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            if (selectedTaskDate != date || !tasks.contains(task)) return;
            setState(() {
              task['status'] = previousStatus;
              task['completed'] = previousStatus == 'Complete';
            });
            await saveTasks();
            await handleTaskStatusNotifications(task);
          },
        ),
      ),
    );
  }

  bool _deletingTask = false;

  Future<void> deleteTaskWithUndo(Map<String, dynamic> task) async {
    if (_deletingTask || !tasks.contains(task)) return;
    _deletingTask = true;
    final deletedDate = selectedTaskDate;
    final ownerId = currentUserId;
    final originalIndex = tasks.indexOf(task);
    // Retain the complete task, including its ID, status, tags and times.
    final deletedTask = Map<String, dynamic>.from(task);
    final recurringId = task['recurringId'];
    try {
      final templates = await loadRecurringTasks();
      final removedTemplates = recurringId == null
          ? <Map<String, dynamic>>[]
          : templates
                .where((item) => item['recurringId'] == recurringId)
                .map((item) => Map<String, dynamic>.from(item))
                .toList();
      if (!mounted || selectedTaskDate != deletedDate) return;
      setState(() => tasks.remove(task));
      // Persist deletion before any refresh can rebuild this series.
      if (recurringId != null) {
        templates.removeWhere((item) => item['recurringId'] == recurringId);
        await saveRecurringTasks(templates);
        await _recurringReminderUpdates;
        await cancelRecurringReminders(deletedTask);
      } else {
        await cancelTaskReminders(deletedTask);
      }
      final prefs = await SharedPreferences.getInstance();
      // Anchor the write to the deleted date, even if the user navigates away.
      // Read its current list if navigation has already saved that date.
      if (selectedTaskDate == deletedDate) {
        await prefs.setString(
          getTaskStorageKey(deletedDate),
          jsonEncode(tasks),
        );
        await refreshDailyTaskNotifications();
      } else {
        final saved =
            (jsonDecode(prefs.getString(getTaskStorageKey(deletedDate)) ?? '[]')
                    as List)
                .map((value) => Map<String, dynamic>.from(value as Map))
                .toList();
        saved.removeWhere(
          (value) => value['notificationId'] == deletedTask['notificationId'],
        );
        await prefs.setString(
          getTaskStorageKey(deletedDate),
          jsonEncode(saved),
        );
      }
      if (!mounted) return;
      var restored = false;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Text('Deleted "${deletedTask['title']}"'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              if (restored || !mounted || currentUserId != ownerId) return;
              restored = true;
              final restoredTemplates = await loadRecurringTasks();
              for (final template in removedTemplates) {
                if (!restoredTemplates.any(
                  (item) => item['recurringId'] == template['recurringId'],
                )) {
                  restoredTemplates.add(template);
                }
              }
              if (removedTemplates.isNotEmpty)
                await saveRecurringTasks(restoredTemplates);
              final prefs = await SharedPreferences.getInstance();
              final stored = selectedTaskDate == deletedDate
                  ? List<Map<String, dynamic>>.from(tasks)
                  : (jsonDecode(
                          prefs.getString(getTaskStorageKey(deletedDate)) ??
                              '[]',
                        ) as List)
                        .map((value) => Map<String, dynamic>.from(value as Map))
                        .toList();
              if (!stored.any(
                (item) =>
                    item['notificationId'] == deletedTask['notificationId'],
              )) {
                stored.insert(
                  originalIndex.clamp(0, stored.length).toInt(),
                  deletedTask,
                );
              }
              await prefs.setString(
                getTaskStorageKey(deletedDate),
                jsonEncode(stored),
              );
              if (!mounted) return;
              if (selectedTaskDate == deletedDate) {
                setState(() => tasks = stored);
              } else if (removedTemplates.isNotEmpty) {
                // Regenerate the visible occurrence after restoring its series.
                await loadTasksForSelectedDate();
              }
              await handleTaskStatusNotifications(deletedTask);
              await refreshDailyTaskNotifications();
              if (!mounted) return;
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Task restored')));
            },
          ),
        ),
      );
    } finally {
      _deletingTask = false;
    }
  }

  void showTaskDetails(Map<String, dynamic> task) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF202020),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task['title']?.toString() ?? 'Task',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                if ((task['description']?.toString() ?? '').isNotEmpty) ...[
                  Text(
                    task['description'].toString(),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  'Status: ${task['status'] ?? 'Not Started'}',
                  style: const TextStyle(color: Colors.white70),
                ),
                Text(
                  'Category: ${task['category'] ?? 'Personal'}',
                  style: const TextStyle(color: Colors.white70),
                ),
                if (task['priority'] != null)
                  Text(
                    'Priority: ${task['priority']}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                if (task['tags'] is List && (task['tags'] as List).isNotEmpty)
                  Text(
                    'Tags: ${(task['tags'] as List).join(', ')}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                if (task['goalId'] != null)
                  Text(
                    'Goal: ${goalTitleFor(task['goalId'])}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                if (task['startTime'] != null || task['endTime'] != null)
                  Text(
                    'Time: ${task['startTime'] ?? '—'} – ${task['endTime'] ?? '—'}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                if (task['reminderTime'] != null)
                  Text(
                    'Reminder: ${task['reminderTime']}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    showEditTaskPopup(task);
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit task'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String goalTitleFor(Object? id) {
    for (final goal in availableGoals) {
      if (goal['id'] == id) return goal['title']?.toString() ?? 'Goal';
    }
    return 'Removed goal';
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
    final selectedDate = selectedTaskDate.isEmpty
        ? DateTime.now()
        : parseDateKey(selectedTaskDate);

    final dayNumber = DateTime.utc(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    ).difference(DateTime.utc(2020, 1, 1)).inDays;

    final quoteIndex = dayNumber % motivationalQuotes.length;

    return motivationalQuotes[quoteIndex];
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    taskController.dispose();
    descriptionController.dispose();
    searchController.dispose();
    tagsController.dispose();
    super.dispose();
  }

  // Loads all saved recurring-task templates.
  Future<List<Map<String, dynamic>>> loadRecurringTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final savedRecurringTasks = prefs.getString(userKey('recurringTasks'));

    if (savedRecurringTasks != null) {
      try {
        final List decodedTasks = jsonDecode(savedRecurringTasks);

        final recurring = decodedTasks
            .map((task) => Map<String, dynamic>.from(task as Map))
            .toList();

        await saveAppStateFieldsToCloud({'recurringTasks': recurring});
        return recurring;
      } catch (_) {
        // Fall through to cloud restore.
      }
    }

    final cloudState = await loadAppStateFromCloud();
    final cloudRecurring = cloudState?['recurringTasks'];

    if (cloudRecurring is List) {
      final recurring = cloudRecurring
          .map((task) => Map<String, dynamic>.from(task as Map))
          .toList();

      await prefs.setString(
        userKey('recurringTasks'),
        jsonEncode(recurring),
      );

      return recurring;
    }

    return [];
  }

  // Saves the recurring-task template list.
  Future<void> saveRecurringTasks(
    List<Map<String, dynamic>> recurringTasks,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      userKey('recurringTasks'),
      jsonEncode(recurringTasks),
    );

    await saveAppStateFieldsToCloud({
      'recurringTasks': recurringTasks,
    });
  }

  // Saves a newly created recurring task as a reusable template.
  Future<void> addRecurringTaskTemplate(Map<String, dynamic> task) async {
    // "Never" tasks do not need a recurring template.
    if (task['repeat'] == null || task['repeat'] == 'Never') {
      return;
    }

    final recurringTasks = await loadRecurringTasks();

    // Give the recurring series its own stable ID.
    final recurringId = DateTime.now().microsecondsSinceEpoch.toString();

    final recurringTask = Map<String, dynamic>.from(task);

    recurringTask['recurringId'] = recurringId;

    // A template should not stay marked completed.
    recurringTask['completed'] = false;

    // Recurring templates should always begin future
    // occurrences in the Not Started state.
    recurringTask['status'] = 'Not Started';

    recurringTasks.add(recurringTask);

    await saveRecurringTasks(recurringTasks);

    // Also attach the recurring ID to today's copy.
    task['recurringId'] = recurringId;
  }

  // Updates, creates, or removes the recurring template
  // when a task's repeat settings are edited.
  Future<void> updateRecurringTaskTemplate(Map<String, dynamic> task) async {
    final recurringTasks = await loadRecurringTasks();
    final recurringId = task['recurringId'];
    final repeat = task['repeat'] ?? 'Never';

    // If recurrence was turned off, remove the old template.
    if (repeat == 'Never') {
      if (recurringId != null) {
        await cancelRecurringReminders(task);
        recurringTasks.removeWhere(
          (item) => item['recurringId'] == recurringId,
        );

        await saveRecurringTasks(recurringTasks);

        task.remove('recurringId');
      }

      return;
    }

    // If this used to be a normal task but is now recurring,
    // create a new recurring template for it.
    if (recurringId == null) {
      await addRecurringTaskTemplate(task);
      return;
    }

    // Update the existing recurring template.
    final index = recurringTasks.indexWhere(
      (item) => item['recurringId'] == recurringId,
    );

    if (index != -1) {
      final updatedTemplate = Map<String, dynamic>.from(task);

      updatedTemplate['completed'] = false;

      // Future recurring occurrences should not inherit
      // the current occurrence's completed/in-progress state.
      updatedTemplate['status'] = 'Not Started';

      recurringTasks[index] = updatedTemplate;

      await saveRecurringTasks(recurringTasks);
    }
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
        ? userKey('tasks')
        : userKey('tasks_$selectedTaskDate');

    await prefs.setString(taskKey, encodedTasks);

    // Mirror the same day's tasks to Firestore so they can be restored after
    // reinstalling the app or signing in on another device.
    final String cloudDateKey =
        selectedTaskDate.isEmpty ? todayKey : selectedTaskDate;
    await saveTaskDayToCloud(
      cloudDateKey,
      List<Map<String, dynamic>>.from(tasks),
    );

    if (selectedTaskDate.isNotEmpty) {
      await prefs.setBool(
        userKey('dayCompleted_$selectedTaskDate'),
        dayCompleted,
      );
    }

    await prefs.setInt(userKey('streakCounter'), streakCounter);
    await prefs.setString(userKey('lastCompletedDate'), lastCompletedDate);
    await prefs.setString(userKey('lastActiveDate'), lastActiveDate);
    await prefs.setString(userKey('selectedTaskDate'), selectedTaskDate);

    await saveDayCompletionToCloud(cloudDateKey, dayCompleted);
    await saveAppStateFieldsToCloud({
      'streakCounter': streakCounter,
      'lastCompletedDate': lastCompletedDate,
      'lastActiveDate': lastActiveDate,
      'selectedTaskDate': selectedTaskDate,
    });

    if (isViewingToday()) {
      await refreshDailyTaskNotifications();
    }
  }

  // Loads today's/current task storage and app settings
  Future<void> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();

    final todayKey = getDateKey(DateTime.now());

    // Always begin the Home screen on today's date.
    // Do not restore a previously viewed past or future date here.
    selectedTaskDate = todayKey;

    // The main "tasks" key contains the active day's tasks.
    final String? savedTasks = prefs.getString(userKey('tasks'));

    final loadedTasks = <Map<String, dynamic>>[];

    if (savedTasks != null) {
      final List decodedTasks = jsonDecode(savedTasks);

      loadedTasks.addAll(
        decodedTasks.map((task) {
          return Map<String, dynamic>.from(task);
        }),
      );

      // Existing users already have local data from earlier TrakOn versions.
      // Back it up as soon as Home loads so they are protected even before
      // making their next task change.
      await saveTaskDayToCloud(
        todayKey,
        List<Map<String, dynamic>>.from(loadedTasks),
      );
    } else {
      // A reinstall clears SharedPreferences. Restore today's task data from
      // Firestore when a cloud backup exists, then rebuild the local cache.
      final cloudTasks = await loadTaskDayFromCloud(todayKey);

      if (cloudTasks != null) {
        loadedTasks.addAll(cloudTasks);
        await prefs.setString(userKey('tasks'), jsonEncode(cloudTasks));
      }
    }

    final cloudState = await loadAppStateFromCloud();
    final cloudDayCompleted = await loadDayCompletionFromCloud(todayKey);

    final localDayCompleted = prefs.getBool(userKey('dayCompleted_$todayKey'));
    final localStreak = prefs.getInt(userKey('streakCounter'));
    final localLastCompletedDate = prefs.getString(userKey('lastCompletedDate'));
    final localLastActiveDate = prefs.getString(userKey('lastActiveDate'));

    final restoredDayCompleted =
        localDayCompleted ?? cloudDayCompleted ?? false;

    final restoredStreak =
        localStreak ?? (cloudState?['streakCounter'] as num?)?.toInt() ?? 0;

    final restoredLastCompletedDate =
        localLastCompletedDate ??
        cloudState?['lastCompletedDate']?.toString() ??
        '';

    final restoredLastActiveDate =
        localLastActiveDate ??
        cloudState?['lastActiveDate']?.toString() ??
        '';

    await prefs.setBool(
      userKey('dayCompleted_$todayKey'),
      restoredDayCompleted,
    );
    await prefs.setInt(userKey('streakCounter'), restoredStreak);
    await prefs.setString(
      userKey('lastCompletedDate'),
      restoredLastCompletedDate,
    );
    await prefs.setString(
      userKey('lastActiveDate'),
      restoredLastActiveDate,
    );

    if (!mounted) return;

    setState(() {
      tasks = loadedTasks;
      dayCompleted = restoredDayCompleted;
      streakCounter = restoredStreak;
      lastCompletedDate = restoredLastCompletedDate;
      lastActiveDate = restoredLastActiveDate;
      selectedFilter = 'All';
    });

    await prefs.setString(userKey('selectedTaskDate'), todayKey);

    await saveAppStateFieldsToCloud({
      'streakCounter': streakCounter,
      'lastCompletedDate': lastCompletedDate,
      'lastActiveDate': lastActiveDate,
      'selectedTaskDate': todayKey,
    });

    await saveDayCompletionToCloud(todayKey, dayCompleted);
  }

  Future<void> checkForNewDay() async {
    final prefs = await SharedPreferences.getInstance();

    // Get the current date
    final today = DateTime.now();
    final todayString = getDateKey(today);

    if (lastActiveDate.isEmpty) {
      lastActiveDate = todayString;
      await prefs.setString(userKey('lastActiveDate'), lastActiveDate);
      await saveAppStateFieldsToCloud({'lastActiveDate': lastActiveDate});
      return;
    }

    if (lastActiveDate == todayString) return;

    // Read the active day's tasks directly from storage.
    // Do not rely on whichever calendar date happens to be displayed.
    final savedPreviousTasks = prefs.getString(userKey('tasks'));

    final previousDayTasks = <Map<String, dynamic>>[];

    if (savedPreviousTasks != null) {
      final List decodedTasks = jsonDecode(savedPreviousTasks);

      previousDayTasks.addAll(
        decodedTasks.map((task) {
          return Map<String, dynamic>.from(task);
        }),
      );
    }

    if (previousDayTasks.isNotEmpty) {
      await prefs.setString(
        userKey('tasks_$lastActiveDate'),
        jsonEncode(previousDayTasks),
      );

      await saveTaskDayToCloud(
        lastActiveDate,
        List<Map<String, dynamic>>.from(previousDayTasks),
      );
    }

    // Keep only unfinished tasks
    final incompleteTasks = previousDayTasks
        .where((task) {
          return task['completed'] != true;
        })
        .map((task) {
          return Map<String, dynamic>.from(task);
        })
        .toList();

    setState(() {
      dayCompleted = false;
      lastActiveDate = todayString;
      selectedTaskDate = todayString;
    });
    await prefs.setString(userKey('lastActiveDate'), todayString);

    await prefs.setString(userKey('selectedTaskDate'), todayString);

    await saveAppStateFieldsToCloud({
      'lastActiveDate': todayString,
      'selectedTaskDate': todayString,
    });

    await prefs.setBool(userKey('dayCompleted_$todayString'), false);

    // Check whether tasks were already planned for today
    final plannedTodayTasks = prefs.getString(userKey('tasks_$todayString'));

    if (plannedTodayTasks != null) {
      // Move today's previously planned tasks into the main current-day key
      await prefs.setString(userKey('tasks'), plannedTodayTasks);

      // Remove the dated copy after moving it
      await prefs.remove(userKey('tasks_$todayString'));
    } else {
      // Prevent yesterday's tasks from appearing as today's tasks
      await prefs.remove(userKey('tasks'));
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
        tasks.add({...task, 'completed': false, 'date': selectedTaskDate});
      }
    });

    await saveTasks();

    final notificationsEnabled =
        await NotificationPreferences.notificationsEnabled();

    final carryOverNotificationsEnabled =
        await NotificationPreferences.carryOverNotificationsEnabled();

    if (notificationsEnabled && carryOverNotificationsEnabled) {
      await NotificationService.showCarryOverNotification(
        carriedTaskCount: incompleteTasks.length,
      );
    }
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

      await prefs.setInt(userKey('streakCounter'), streakCounter);

      await prefs.setBool(userKey('dayCompleted_$todayString'), dayCompleted);
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

  // Converts a stored TrakOn date key back into DateTime.
  DateTime parseDateKey(String dateKey) {
    final parts = dateKey.split('-');

    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
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

    // Recurring tasks should never appear before
    // the date on which the series began.
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
        // Repeat on the same weekday as the original task.
        return date.weekday == startDate.weekday;

      case 'Specific Days':
        final repeatDays = List<int>.from(task['repeatDays'] ?? []);

        return repeatDays.contains(date.weekday);

      default:
        return false;
    }
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

    return dateKey == todayKey ? userKey('tasks') : userKey('tasks_$dateKey');
  }

  // Loads the selected day's normal tasks and rebuilds
  // recurring occurrences from the latest recurring templates.
  Future<void> loadTasksForSelectedDate() async {
    final prefs = await SharedPreferences.getInstance();

    final taskKey = getTaskStorageKey(selectedTaskDate);

    final savedTasksText = prefs.getString(taskKey);

    final savedTasks = <Map<String, dynamic>>[];

    if (savedTasksText != null) {
      final List decoded = jsonDecode(savedTasksText);

      savedTasks.addAll(
        decoded.map((task) {
          return Map<String, dynamic>.from(task);
        }),
      );
    } else {
      final cloudTasks = await loadTaskDayFromCloud(selectedTaskDate);

      if (cloudTasks != null) {
        savedTasks.addAll(cloudTasks);
        await prefs.setString(taskKey, jsonEncode(cloudTasks));
      }
    }

    final selectedDate = parseDateKey(selectedTaskDate);

    final recurringTemplates = await loadRecurringTasks();

    // Keep normal, non-recurring tasks exactly as they are.
    final rebuiltTasks = savedTasks
        .where((task) {
          return task['recurringId'] == null;
        })
        .map((task) {
          return Map<String, dynamic>.from(task);
        })
        .toList();

    for (final template in recurringTemplates) {
      // Only generate the task if its CURRENT repeat
      // rules say it belongs on this date.
      if (!recurringTaskRunsOnDate(template, selectedDate)) {
        continue;
      }

      final recurringId = template['recurringId'];

      // Look for a previously saved occurrence so we can
      // preserve things such as completion status.
      Map<String, dynamic>? existingOccurrence;

      for (final savedTask in savedTasks) {
        if (savedTask['recurringId'] == recurringId) {
          existingOccurrence = savedTask;
          break;
        }
      }

      // Start with the newest series/template information.
      final occurrence = Map<String, dynamic>.from(template);

      occurrence['date'] = selectedTaskDate;

      // Keep the description only on the original task.
      // Future recurring copies keep the task name but start
      // with a blank description.
      final recurringStartDate =
          template['startDate']?.toString() ?? template['date']?.toString();

      if (selectedTaskDate != recurringStartDate) {
        occurrence['description'] = '';
      }

      // Preserve completion status for this specific day.
      occurrence['completed'] = existingOccurrence?['completed'] ?? false;

      // Preserve this day's saved workflow status when one exists.
      // Otherwise, a new recurring occurrence begins as Not Started.
      occurrence['status'] = existingOccurrence?['status'] ?? 'Not Started';

      // All occurrences use the series ID so edits and deletion can cancel
      // every repeating reminder for that series.
      occurrence['notificationId'] = template['notificationId'];

      rebuiltTasks.add(occurrence);
    }

    if (!mounted) return;

    final cloudDayCompleted =
        await loadDayCompletionFromCloud(selectedTaskDate);

    final restoredDayCompleted =
        prefs.getBool(userKey('dayCompleted_$selectedTaskDate')) ??
        cloudDayCompleted ??
        false;

    if (!mounted) return;

    setState(() {
      tasks = rebuiltTasks;
      dayCompleted = restoredDayCompleted;
      selectedFilter = 'All';
    });

    await prefs.setString(taskKey, jsonEncode(rebuiltTasks));
    await prefs.setBool(
      userKey('dayCompleted_$selectedTaskDate'),
      restoredDayCompleted,
    );

    await saveTaskDayToCloud(
      selectedTaskDate,
      List<Map<String, dynamic>>.from(rebuiltTasks),
    );

    await saveDayCompletionToCloud(
      selectedTaskDate,
      restoredDayCompleted,
    );
  }

  // Loads the selected date shared between Home and Calendar
  Future<void> loadSelectedTaskDateFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    final savedDate = prefs.getString(userKey('selectedTaskDate'));

    if (savedDate != null && savedDate != selectedTaskDate) {
      setState(() {
        selectedTaskDate = savedDate;
      });

      await loadTasksForSelectedDate();
    }
  }

  // Calculates progress for a date while also
  // accounting for recurring tasks.
  Future<double> getProgressForDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();

    final dateKey = getDateKey(date);
    final taskKey = getTaskStorageKey(dateKey);

    final savedTasks = prefs.getString(taskKey);

    final dayTasks = <Map<String, dynamic>>[];

    if (savedTasks != null) {
      final List decodedTasks = jsonDecode(savedTasks);

      dayTasks.addAll(
        decodedTasks.map((task) {
          return Map<String, dynamic>.from(task);
        }),
      );
    }

    // Add recurring tasks that belong on this date.
    final recurringTasks = await loadRecurringTasks();

    for (final recurringTask in recurringTasks) {
      if (!recurringTaskRunsOnDate(recurringTask, date)) {
        continue;
      }

      final recurringId = recurringTask['recurringId'];

      final alreadyExists = dayTasks.any((task) {
        return task['recurringId'] == recurringId;
      });

      if (!alreadyExists) {
        final recurringCopy = Map<String, dynamic>.from(recurringTask);

        recurringCopy['completed'] = false;

        dayTasks.add(recurringCopy);
      }
    }

    if (dayTasks.isEmpty) {
      return 0;
    }

    // Give each task a progress value based on its workflow status.
    // Not Started = 0%
    // In Progress = 50%
    // Complete = 100%
    double totalProgress = 0;

    for (final task in dayTasks) {
      final status = task['status']?.toString() ?? 'Not Started';

      if (status == 'Complete' || task['completed'] == true) {
        totalProgress += 1.0;
      } else if (status == 'In Progress') {
        totalProgress += 0.5;
      }
    }

    return totalProgress / dayTasks.length;
  }

  // Returns the correct task count for a date,
  // including recurring tasks that belong on that day.
  Future<int> getTaskCountForDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();

    final dateKey = getDateKey(date);
    final taskKey = getTaskStorageKey(dateKey);

    final savedTasks = prefs.getString(taskKey);

    final dayTasks = <Map<String, dynamic>>[];

    // Load tasks already saved directly for this date.
    if (savedTasks != null) {
      final List decodedTasks = jsonDecode(savedTasks);

      dayTasks.addAll(
        decodedTasks.map((task) {
          return Map<String, dynamic>.from(task);
        }),
      );
    }

    // Check every recurring task template.
    final recurringTasks = await loadRecurringTasks();

    for (final recurringTask in recurringTasks) {
      if (!recurringTaskRunsOnDate(recurringTask, date)) {
        continue;
      }

      final recurringId = recurringTask['recurringId'];

      // Do not count a recurring task twice if an occurrence
      // has already been saved for this date.
      final alreadyExists = dayTasks.any((task) {
        return task['recurringId'] == recurringId;
      });

      if (!alreadyExists) {
        dayTasks.add(recurringTask);
      }
    }

    return dayTasks.length;
  }

  DateTime getNextDailyNotificationTime({
    required int hour,
    required int minute,
  }) {
    final now = DateTime.now();

    DateTime scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (!scheduledTime.isAfter(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    return scheduledTime;
  }

  Future<void> refreshDailyTaskNotifications() async {
    if (!isViewingToday()) return;

    final notificationsEnabled =
        await NotificationPreferences.notificationsEnabled();

    if (!notificationsEnabled) {
      await NotificationService.cancelNotification(
        NotificationService.dailySummaryNotificationId,
      );

      await NotificationService.cancelNotification(
        NotificationService.endOfDayNotificationId,
      );

      return;
    }

    final remainingTaskCount = tasks.where((task) {
      return task['completed'] != true;
    }).length;

    final dailySummaryEnabled =
        await NotificationPreferences.dailySummaryEnabled();

    if (dailySummaryEnabled) {
      final summaryHour = await NotificationPreferences.dailySummaryHour();

      final summaryMinute = await NotificationPreferences.dailySummaryMinute();

      await NotificationService.scheduleDailyTaskSummary(
        scheduledTime: getNextDailyNotificationTime(
          hour: summaryHour,
          minute: summaryMinute,
        ),
        remainingTaskCount: remainingTaskCount,
      );
    } else {
      await NotificationService.cancelNotification(
        NotificationService.dailySummaryNotificationId,
      );
    }

    final endOfDayEnabled = await NotificationPreferences.endOfDayEnabled();

    if (endOfDayEnabled) {
      final endHour = await NotificationPreferences.endOfDayHour();

      final endMinute = await NotificationPreferences.endOfDayMinute();

      await NotificationService.scheduleEndOfDayNotification(
        scheduledTime: getNextDailyNotificationTime(
          hour: endHour,
          minute: endMinute,
        ),
        remainingTaskCount: remainingTaskCount,
      );
    } else {
      await NotificationService.cancelNotification(
        NotificationService.endOfDayNotificationId,
      );
    }
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
    final dateParts = dateKey.split('-');

    if (dateParts.length != 3) {
      throw FormatException('Invalid task date: $dateKey');
    }

    final year = int.tryParse(dateParts[0]);
    final month = int.tryParse(dateParts[1]);
    final day = int.tryParse(dateParts[2]);

    if (year == null || month == null || day == null) {
      throw FormatException('Invalid task date: $dateKey');
    }

    return DateTime(year, month, day, reminderTime.hour, reminderTime.minute);
  }

  // Clear all 29 IDs used by both the previous repeating plan and the new
  // seven-occurrence plan, including the legacy end-time notification.
  Future<void> cancelRecurringReminders(Map<String, dynamic> task) async {
    final base = task['notificationId'];
    if (base is! int) return;
    for (var offset = 0; offset <= 28; offset++) {
      await NotificationService.cancelNotification(base + offset);
    }
  }

  Future<void> refreshRecurringTaskReminders(String recurringId) async {
    final templates = await loadRecurringTasks();
    for (final template in templates) {
      if (template['recurringId'] == recurringId) {
        await scheduleRecurringReminders(template);
        return;
      }
    }
  }

  Future<void> refreshAllRecurringReminders() async {
    for (final template in await loadRecurringTasks()) {
      await scheduleRecurringReminders(template);
    }
  }

  Future<void> scheduleRecurringReminders(Map<String, dynamic> template) {
    // Serialize rebuilds so a stale refresh cannot re-add cancelled reminders.
    final update = _recurringReminderUpdates.then((_) async {
      final recurringId = template['recurringId'];
      final currentTemplates = await loadRecurringTasks();
      final matches = currentTemplates.where(
        (item) => item['recurringId'] == recurringId,
      );
      await cancelRecurringReminders(template);
      if (matches.isEmpty) return; // The series may have just been deleted.
      await rebuildRecurringReminders(matches.first);
    });
    _recurringReminderUpdates = update.catchError((Object error) {
      debugPrint('Unable to refresh recurring reminders: $error');
    });
    return update;
  }

  Future<void> rebuildRecurringReminders(Map<String, dynamic> template) async {
    if (!await NotificationPreferences.notificationsEnabled() ||
        !await NotificationPreferences.taskRemindersEnabled())
      return;
    final base = template['notificationId'];
    if (base is! int) return;
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startText = template['startDate'] ?? template['date'];
    if (startText is! String) return;
    final start = parseDateKey(startText);
    final first = start.isAfter(today) ? start : today;
    final occurrences = <String, Map<String, dynamic>>{};
    // Read persisted status for future dates as well as today.
    for (var day = 0; day < 49; day++) {
      final date = DateTime(first.year, first.month, first.day + day);
      final key = getDateKey(date);
      final saved =
          jsonDecode(prefs.getString(getTaskStorageKey(key)) ?? '[]') as List;
      for (final value in saved) {
        if (value is Map && value['recurringId'] == template['recurringId']) {
          occurrences[key] = Map<String, dynamic>.from(value);
          break;
        }
      }
    }
    final plan = buildRecurringReminderPlan(
      template: template,
      occurrences: occurrences,
      now: now,
      followUpsEnabled:
          await NotificationPreferences.highPriorityRemindersEnabled(),
    );
    final priority = template['priority']?.toString();
    final title = priority == '🔴 High'
        ? '🔴 High Priority Task'
        : priority == '🟡 Medium'
        ? '🟡 Medium Priority Task'
        : priority == '🟢 Low'
        ? '🟢 Low Priority Task'
        : 'Task Reminder';
    for (final reminder in plan) {
      await NotificationService.scheduleNotification(
        id: base + reminder.offset,
        title: reminder.isEndTime
            ? '$title Ending'
            : reminder.isFollowUp
            ? '$title Follow-Up'
            : title,
        body: template['title']?.toString() ?? 'Your task',
        scheduledTime: reminder.time,
        payload: 'task:$base',
      );
    }
  }

  // Schedules the main reminder and priority-based follow-up reminders.
  Future<void> scheduleSmartReminders({
    required int notificationId,
    required String taskTitle,
    required String? priority,
    required DateTime reminderDateTime,
  }) async {
    // The notification service skips each expired request individually,
    // preserving future follow-ups when a task is restored after its start.

    // Respect the master notification setting.
    final notificationsEnabled =
        await NotificationPreferences.notificationsEnabled();

    if (!notificationsEnabled) {
      return;
    }

    // Respect the task reminder setting.
    final taskRemindersEnabled =
        await NotificationPreferences.taskRemindersEnabled();

    if (!taskRemindersEnabled) {
      return;
    }

    // Main notification for every task.
    String mainTitle = 'Task Reminder';

    if (priority == '🔴 High') {
      mainTitle = '🔴 High Priority Task';
    } else if (priority == '🟡 Medium') {
      mainTitle = '🟡 Medium Priority Task';
    } else if (priority == '🟢 Low') {
      mainTitle = '🟢 Low Priority Task';
    }

    await NotificationService.scheduleNotification(
      id: notificationId,
      title: mainTitle,
      body: taskTitle,
      scheduledTime: reminderDateTime,
    );

    // Check whether stronger priority-based follow-ups are enabled.
    final priorityRemindersEnabled =
        await NotificationPreferences.highPriorityRemindersEnabled();

    if (!priorityRemindersEnabled) {
      return;
    }

    // ----------------------------------------------------------
    // HIGH PRIORITY
    // Main reminder + 15 min + 30 min + 60 min
    // ----------------------------------------------------------
    if (priority == '🔴 High') {
      await NotificationService.scheduleNotification(
        id: notificationId + 1,
        title: '🔴 High Priority Task Still Waiting',
        body: '$taskTitle still needs your attention.',
        scheduledTime: reminderDateTime.add(const Duration(minutes: 15)),
      );

      await NotificationService.scheduleNotification(
        id: notificationId + 2,
        title: '🔴 Stay Focused',
        body: 'Do not forget to complete: $taskTitle',
        scheduledTime: reminderDateTime.add(const Duration(minutes: 30)),
      );

      await NotificationService.scheduleNotification(
        id: notificationId + 3,
        title: '🔴 Final High Priority Reminder',
        body: '$taskTitle is still unfinished.',
        scheduledTime: reminderDateTime.add(const Duration(minutes: 60)),
      );
    }
    // ----------------------------------------------------------
    // MEDIUM PRIORITY
    // Main reminder + one follow-up after 30 minutes
    // ----------------------------------------------------------
    else if (priority == '🟡 Medium') {
      await NotificationService.scheduleNotification(
        id: notificationId + 1,
        title: '🟡 Task Follow-Up',
        body: 'Remember to complete: $taskTitle',
        scheduledTime: reminderDateTime.add(const Duration(minutes: 30)),
      );
    }
    // ----------------------------------------------------------
    // LOW PRIORITY
    // Only receives the original scheduled reminder.
    // ----------------------------------------------------------
    else if (priority == '🟢 Low') {
      // No additional reminders needed.
    }
  }

  // Cancels every notification that may belong to a task.
  Future<void> cancelTaskReminders(Map<String, dynamic> task) async {
    final notificationId = task['notificationId'];

    if (notificationId is! int) {
      return;
    }

    await NotificationService.cancelNotification(notificationId);

    await NotificationService.cancelNotification(notificationId + 1);

    await NotificationService.cancelNotification(notificationId + 2);

    await NotificationService.cancelNotification(notificationId + 3);

    await NotificationService.cancelNotification(notificationId + 4);
  }

  // ---------------------------------------------------------------------------
  // TASK STATUS NOTIFICATION HANDLER
  // ---------------------------------------------------------------------------

  // Updates notifications when a task moves between
  // Not Started, In Progress, and Complete.
  Future<void> handleTaskStatusNotifications(Map<String, dynamic> task) async {
    final status = task['status']?.toString() ?? 'Not Started';

    final recurringId = task['recurringId'];
    if (recurringId is String && task['repeat'] != 'Never') {
      await refreshRecurringTaskReminders(recurringId);
      return;
    }

    // Always clear the old notification chain first
    // so outdated status reminders do not keep firing.
    await cancelTaskReminders(task);

    // Complete tasks should receive no further reminders.
    if (status == 'Complete' || task['completed'] == true) {
      return;
    }

    if (!await NotificationPreferences.notificationsEnabled() ||
        !await NotificationPreferences.taskRemindersEnabled())
      return;

    final notificationId = task['notificationId'];

    if (notificationId is! int) {
      return;
    }

    final priority = task['priority']?.toString();

    final dateKey = task['date']?.toString() ?? selectedTaskDate;

    // ------------------------------------------------------------
    // NOT STARTED
    // ------------------------------------------------------------
    if (status == 'Not Started') {
      // Prefer the task's Start Time when one exists.
      // Otherwise, fall back to the user's normal reminder.
      final startTime = parseReminderTime(task['startTime']);

      final normalReminder = parseReminderTime(task['reminderTime']);

      final timeToUse = startTime ?? normalReminder;

      if (timeToUse == null) {
        return;
      }

      final scheduledTime = buildReminderDateTime(
        dateKey: dateKey,
        reminderTime: timeToUse,
      );

      await scheduleSmartReminders(
        notificationId: notificationId,
        taskTitle: task['title'].toString(),
        priority: priority,
        reminderDateTime: scheduledTime,
      );

      return;
    }

    // ------------------------------------------------------------
    // IN PROGRESS
    // ------------------------------------------------------------
    if (status == 'In Progress') {
      final endTime = parseReminderTime(task['endTime']);

      // If there is no End Time, there is nothing
      // additional to schedule for the active task.
      if (endTime == null) {
        return;
      }

      final endDateTime = buildReminderDateTime(
        dateKey: dateKey,
        reminderTime: endTime,
      );

      if (!endDateTime.isAfter(DateTime.now())) {
        return;
      }

      String title = 'Task Time Ending';

      String body =
          '${task['title']} is reaching the end of its scheduled time.';

      // Give higher-priority tasks stronger wording.
      if (priority == '🔴 High') {
        title = '🔴 High Priority Task Ending';
        body =
            '${task['title']} is reaching the end of its scheduled time. Finish strong.';
      } else if (priority == '🟡 Medium') {
        title = '🟡 Task Time Ending';
      }

      await NotificationService.scheduleNotification(
        id: notificationId + 4,
        title: title,
        body: body,
        scheduledTime: endDateTime,
        payload: 'task:$notificationId',
      );
    }
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
    return TimeOfDay(hour: hour, minute: minute);
  }

  void showAddTaskPopup() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.black,
              title: const Text(
                'Add Task',
                style: TextStyle(color: Colors.white),
              ),
              content: SizedBox(
                width: 300,
                child: SingleChildScrollView(
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

                      const SizedBox(height: 16),
                      TextField(
                        controller: tagsController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Tags (comma separated)',
                          labelStyle: TextStyle(color: Colors.white70),
                        ),
                      ),

                      if (availableGoals.isNotEmpty)
                        DropdownButton<String>(
                          value:
                              availableGoals.any(
                                (goal) => goal['id'] == selectedGoalId,
                              )
                              ? selectedGoalId
                              : null,
                          hint: const Text(
                            'Link to a goal (optional)',
                            style: TextStyle(color: Colors.white70),
                          ),
                          dropdownColor: Colors.black,
                          isExpanded: true,
                          style: const TextStyle(color: Colors.white),
                          items: [
                            const DropdownMenuItem<String>(
                              value: '',
                              child: Text('No goal'),
                            ),
                            ...availableGoals.map(
                              (goal) => DropdownMenuItem<String>(
                                value: goal['id'].toString(),
                                child: Text(goal['title'].toString()),
                              ),
                            ),
                          ],
                          onChanged: (value) => setDialogState(
                            () => selectedGoalId = value == '' ? null : value,
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

                      DropdownButton<String>(
                        value: selectedRepeat,
                        dropdownColor: Colors.black,
                        isExpanded: true,
                        style: const TextStyle(color: Colors.white),

                        items: const [
                          DropdownMenuItem(
                            value: 'Never',
                            child: Text('Repeat: Never'),
                          ),
                          DropdownMenuItem(
                            value: 'Daily',
                            child: Text('Repeat: Daily'),
                          ),
                          DropdownMenuItem(
                            value: 'Weekdays',
                            child: Text('Repeat: Weekdays'),
                          ),
                          DropdownMenuItem(
                            value: 'Weekly',
                            child: Text('Repeat: Weekly'),
                          ),
                          DropdownMenuItem(
                            value: 'Specific Days',
                            child: Text('Repeat: Specific Days'),
                          ),
                        ],

                        onChanged: (value) {
                          if (value == null) return;

                          setDialogState(() {
                            selectedRepeat = value;

                            if (selectedRepeat != 'Specific Days') {
                              selectedRepeatDays.clear();
                            }
                          });
                        },
                      ),

                      if (selectedRepeat == 'Specific Days') ...[
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Choose days',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final day in const [
                              {'label': 'M', 'value': 1},
                              {'label': 'T', 'value': 2},
                              {'label': 'W', 'value': 3},
                              {'label': 'T', 'value': 4},
                              {'label': 'F', 'value': 5},
                              {'label': 'S', 'value': 6},
                              {'label': 'S', 'value': 7},
                            ])
                              ChoiceChip(
                                label: Text(day['label'] as String),
                                selected: selectedRepeatDays.contains(
                                  day['value'] as int,
                                ),
                                onSelected: (selected) {
                                  setDialogState(() {
                                    final value = day['value'] as int;

                                    if (selected) {
                                      selectedRepeatDays.add(value);
                                    } else {
                                      selectedRepeatDays.remove(value);
                                    }
                                  });
                                },
                              ),
                          ],
                        ),

                        const SizedBox(height: 12),
                      ],

                      const SizedBox(height: 12),

                      const SizedBox(height: 16),

                      // ---------------------------------------------------------------------------
                      // OPTIONAL START TIME
                      // ---------------------------------------------------------------------------
                      ListTile(
                        title: Text(
                          selectedStartTime == null
                              ? 'Start Time (Optional)'
                              : 'Start: ${selectedStartTime!.format(context)}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        trailing: const Icon(
                          Icons.play_arrow,
                          color: Colors.greenAccent,
                        ),
                        onTap: () async {
                          TimeOfDay tempStartTime =
                              selectedStartTime ?? TimeOfDay.now();

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
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text(
                                              'Cancel',
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              setDialogState(() {
                                                selectedStartTime =
                                                    tempStartTime;
                                              });

                                              Navigator.pop(context);
                                            },
                                            child: const Text(
                                              'Done',
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
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
                                            tempStartTime.hour,
                                            tempStartTime.minute,
                                          ),
                                          onDateTimeChanged: (newTime) {
                                            tempStartTime = TimeOfDay(
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

                      if (selectedStartTime != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () {
                              setDialogState(() {
                                selectedStartTime = null;
                              });
                            },
                            child: const Text(
                              'Clear Start Time',
                              style: TextStyle(color: Colors.redAccent),
                            ),
                          ),
                        ),

                      // ---------------------------------------------------------------------------
                      // OPTIONAL END TIME
                      // ---------------------------------------------------------------------------
                      ListTile(
                        title: Text(
                          selectedEndTime == null
                              ? 'End Time (Optional)'
                              : 'End: ${selectedEndTime!.format(context)}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        trailing: const Icon(
                          Icons.stop_circle_outlined,
                          color: Colors.redAccent,
                        ),
                        onTap: () async {
                          TimeOfDay tempEndTime =
                              selectedEndTime ??
                              selectedStartTime ??
                              TimeOfDay.now();

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
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text(
                                              'Cancel',
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              setDialogState(() {
                                                selectedEndTime = tempEndTime;
                                              });

                                              Navigator.pop(context);
                                            },
                                            child: const Text(
                                              'Done',
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
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
                                            tempEndTime.hour,
                                            tempEndTime.minute,
                                          ),
                                          onDateTimeChanged: (newTime) {
                                            tempEndTime = TimeOfDay(
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

                      if (selectedEndTime != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () {
                              setDialogState(() {
                                selectedEndTime = null;
                              });
                            },
                            child: const Text(
                              'Clear End Time',
                              style: TextStyle(color: Colors.redAccent),
                            ),
                          ),
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
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text(
                                              'Cancel',
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              setDialogState(() {
                                                selectedReminderTime =
                                                    tempReminderTime;
                                              });

                                              Navigator.pop(context);
                                            },
                                            child: const Text(
                                              'Done',
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
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
                  ),
                ),
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

                    // Validate the optional scheduled time window.
                    // If both times are set, End Time must be after Start Time.
                    if (selectedStartTime != null && selectedEndTime != null) {
                      final startMinutes =
                          selectedStartTime!.hour * 60 +
                          selectedStartTime!.minute;

                      final endMinutes =
                          selectedEndTime!.hour * 60 + selectedEndTime!.minute;

                      if (endMinutes <= startMinutes) {
                        if (!mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'End Time must be later than Start Time.',
                            ),
                          ),
                        );

                        return;
                      }
                    }

                    // Create one stable notification ID for this task.
                    final notificationId = createNotificationId();

                    final newTask = <String, dynamic>{
                      'title': newTaskTitle,
                      'description': descriptionController.text.trim(),
                      'completed': false,
                      'category': selectedCategory,
                      'tags': tagsController.text
                          .split(',')
                          .map((tag) => tag.trim())
                          .where((tag) => tag.isNotEmpty)
                          .toSet()
                          .toList(),
                      'goalId': selectedGoalId,

                      // Optional priority level.
                      'priority': selectedPriority,

                      // Optional scheduled time window.
                      'startTime': selectedStartTime?.format(context),
                      'endTime': selectedEndTime?.format(context),

                      // New tasks begin as Not Started.
                      'status': selectedStatus,

                      // Optional normal reminder.
                      'reminderTime': selectedReminderTime?.format(context),

                      // Stable notification ID for this task.
                      'notificationId': notificationId,

                      // Date for this specific task occurrence.
                      'date': selectedTaskDate,

                      // Original date the recurring series begins.
                      'startDate': selectedTaskDate,

                      // Repeat settings.
                      'repeat': selectedRepeat,
                      'repeatDays': selectedRepeatDays.toList(),
                    };

                    setState(() {
                      tasks.add(newTask);
                    });

                    // Close the popup immediately after the task is added.
                    Navigator.of(context).pop();

                    taskController.clear();
                    descriptionController.clear();
                    tagsController.clear();

                    // Reset the Add Task fields for next time.
                    setState(() {
                      selectedPriority = null;
                      selectedGoalId = null;
                      selectedReminderTime = null;

                      selectedStartTime = null;
                      selectedEndTime = null;
                      selectedStatus = 'Not Started';

                      selectedRepeat = 'Never';
                      selectedRepeatDays.clear();
                    });

                    // If this task repeats, save a reusable recurring template
                    // for future matching dates.
                    await addRecurringTaskTemplate(newTask);

                    // Build the correct notification plan for the new task.
                    //
                    // If the task has a Start Time, TrakOn uses that as the
                    // beginning of the scheduled task window.
                    //
                    // If there is no Start Time, the normal Reminder Time
                    // is used instead.
                    //
                    // If neither exists, no notification is scheduled.
                    await saveTasks();
                    await handleTaskStatusNotifications(newTask);
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget taskTile({required String title, required bool completed}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Icon(
          completed ? Icons.check_circle : Icons.radio_button_unchecked,
          color: completed ? Colors.greenAccent : Colors.white54,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: Colors.white,
            decoration: completed ? TextDecoration.lineThrough : null,
          ),
        ),
      ),
    );
  }

  void showEditTaskPopup(Map<String, dynamic> task) {
    final editController = TextEditingController(text: task['title']);
    final editDescriptionController = TextEditingController(
      text: task['description'] ?? '',
    );
    final editTagsController = TextEditingController(
      text: task['tags'] is List ? (task['tags'] as List).join(', ') : '',
    );
    String? editGoalId = task['goalId']?.toString();
    String editCategory = task['category'] ?? selectedCategory;
    String? editPriority = task['priority'];
    String? editReminderTime = task['reminderTime'];

    // Load the task's optional scheduled time window.
    String? editStartTime = task['startTime'];
    String? editEndTime = task['endTime'];

    // Load the current workflow status.
    // Older tasks that do not have a status yet
    // should behave as Not Started.
    String editStatus = task['status']?.toString() ?? 'Not Started';

    // Load the task's existing repeat settings.
    String editRepeat = task['repeat'] ?? 'Never';

    Set<int> editRepeatDays = Set<int>.from(task['repeatDays'] ?? []);

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
              content: SizedBox(
                width: 300,
                child: SingleChildScrollView(
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
                      TextField(
                        controller: editTagsController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Tags (comma separated)',
                          labelStyle: TextStyle(color: Colors.white70),
                        ),
                      ),

                      if (availableGoals.isNotEmpty)
                        DropdownButton<String>(
                          value:
                              availableGoals.any(
                                (goal) => goal['id'] == editGoalId,
                              )
                              ? editGoalId
                              : null,
                          hint: const Text(
                            'Link to a goal (optional)',
                            style: TextStyle(color: Colors.white70),
                          ),
                          dropdownColor: Colors.black,
                          isExpanded: true,
                          style: const TextStyle(color: Colors.white),
                          items: [
                            const DropdownMenuItem<String>(
                              value: '',
                              child: Text('No goal'),
                            ),
                            ...availableGoals.map(
                              (goal) => DropdownMenuItem<String>(
                                value: goal['id'].toString(),
                                child: Text(goal['title'].toString()),
                              ),
                            ),
                          ],
                          onChanged: (value) => setDialogState(
                            () => editGoalId = value == '' ? null : value,
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

                      DropdownButton<String>(
                        value: editRepeat,
                        dropdownColor: Colors.black,
                        isExpanded: true,
                        style: const TextStyle(color: Colors.white),

                        items: const [
                          DropdownMenuItem(
                            value: 'Never',
                            child: Text('Repeat: Never'),
                          ),
                          DropdownMenuItem(
                            value: 'Daily',
                            child: Text('Repeat: Daily'),
                          ),
                          DropdownMenuItem(
                            value: 'Weekdays',
                            child: Text('Repeat: Weekdays'),
                          ),
                          DropdownMenuItem(
                            value: 'Weekly',
                            child: Text('Repeat: Weekly'),
                          ),
                          DropdownMenuItem(
                            value: 'Specific Days',
                            child: Text('Repeat: Specific Days'),
                          ),
                        ],

                        onChanged: (value) {
                          if (value == null) return;

                          setDialogState(() {
                            editRepeat = value;

                            // Clear selected days if Specific Days is no longer used.
                            if (editRepeat != 'Specific Days') {
                              editRepeatDays.clear();
                            }
                          });
                        },
                      ),

                      // Show weekday choices only for Specific Days.
                      if (editRepeat == 'Specific Days') ...[
                        const SizedBox(height: 8),

                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final day in const [
                              {'label': 'M', 'value': 1},
                              {'label': 'T', 'value': 2},
                              {'label': 'W', 'value': 3},
                              {'label': 'T', 'value': 4},
                              {'label': 'F', 'value': 5},
                              {'label': 'S', 'value': 6},
                              {'label': 'S', 'value': 7},
                            ])
                              ChoiceChip(
                                label: Text(day['label'] as String),
                                selected: editRepeatDays.contains(
                                  day['value'] as int,
                                ),
                                onSelected: (selected) {
                                  setDialogState(() {
                                    final value = day['value'] as int;

                                    if (selected) {
                                      editRepeatDays.add(value);
                                    } else {
                                      editRepeatDays.remove(value);
                                    }
                                  });
                                },
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),

                      // ---------------------------------------------------------------------------
                      // EDIT OPTIONAL TASK SCHEDULE
                      // ---------------------------------------------------------------------------

                      // START TIME
                      ListTile(
                        title: Text(
                          editStartTime == null
                              ? 'Start Time (Optional)'
                              : 'Start: $editStartTime',
                          style: const TextStyle(color: Colors.white),
                        ),
                        trailing: const Icon(
                          Icons.play_arrow,
                          color: Colors.greenAccent,
                        ),
                        onTap: () async {
                          // Start the Apple-style picker at the task's current
                          // start time. If there isn't one yet, use the current time.
                          TimeOfDay tempStartTime =
                              parseReminderTime(editStartTime) ??
                              TimeOfDay.now();

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
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text(
                                              'Cancel',
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              setDialogState(() {
                                                editStartTime = tempStartTime
                                                    .format(context);
                                              });

                                              Navigator.pop(context);
                                            },
                                            child: const Text(
                                              'Done',
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
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
                                            tempStartTime.hour,
                                            tempStartTime.minute,
                                          ),
                                          onDateTimeChanged: (newTime) {
                                            tempStartTime = TimeOfDay(
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

                      // END TIME
                      ListTile(
                        title: Text(
                          editEndTime == null
                              ? 'End Time (Optional)'
                              : 'End: $editEndTime',
                          style: const TextStyle(color: Colors.white),
                        ),
                        trailing: const Icon(
                          Icons.stop_circle_outlined,
                          color: Colors.redAccent,
                        ),
                        onTap: () async {
                          // Start at the existing end time. If there isn't one,
                          // use the start time, then fall back to the current time.
                          TimeOfDay tempEndTime =
                              parseReminderTime(editEndTime) ??
                              parseReminderTime(editStartTime) ??
                              TimeOfDay.now();

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
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text(
                                              'Cancel',
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              setDialogState(() {
                                                editEndTime = tempEndTime
                                                    .format(context);
                                              });

                                              Navigator.pop(context);
                                            },
                                            child: const Text(
                                              'Done',
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
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
                                            tempEndTime.hour,
                                            tempEndTime.minute,
                                          ),
                                          onDateTimeChanged: (newTime) {
                                            tempEndTime = TimeOfDay(
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

                      if (editStartTime != null || editEndTime != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () {
                              setDialogState(() {
                                editStartTime = null;
                                editEndTime = null;
                              });
                            },
                            child: const Text(
                              'Clear Schedule',
                              style: TextStyle(color: Colors.redAccent),
                            ),
                          ),
                        ),

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
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text(
                                              'Cancel',
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              setDialogState(() {
                                                editReminderTime =
                                                    tempReminderTime.format(
                                                      context,
                                                    );
                                              });

                                              Navigator.pop(context);
                                            },
                                            child: const Text(
                                              'Done',
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
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
              ),
              actionsOverflowDirection: VerticalDirection.down,
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
                    final updatedTitle = editController.text.trim();
                    // Validate the edited scheduled time window.
                    final parsedStartTime = parseReminderTime(editStartTime);

                    final parsedEndTime = parseReminderTime(editEndTime);

                    if (parsedStartTime != null && parsedEndTime != null) {
                      final startMinutes =
                          parsedStartTime.hour * 60 + parsedStartTime.minute;

                      final endMinutes =
                          parsedEndTime.hour * 60 + parsedEndTime.minute;

                      if (endMinutes <= startMinutes) {
                        if (!mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'End Time must be later than Start Time.',
                            ),
                          ),
                        );

                        return;
                      }
                    }

                    // Keep the existing notification ID when possible.
                    final existingNotificationId = task['notificationId'];

                    final int notificationId = existingNotificationId is int
                        ? existingNotificationId
                        : createNotificationId();

                    // Update the task immediately.
                    setState(() {
                      task['title'] = updatedTitle;
                      task['description'] = editDescriptionController.text
                          .trim();
                      task['category'] = editCategory;
                      task['tags'] = editTagsController.text
                          .split(',')
                          .map((tag) => tag.trim())
                          .where((tag) => tag.isNotEmpty)
                          .toSet()
                          .toList();
                      task['goalId'] = editGoalId;
                      task['priority'] = editPriority;
                      task['reminderTime'] = editReminderTime;
                      task['notificationId'] = notificationId;

                      // Save the task's optional scheduled window.
                      task['startTime'] = editStartTime;
                      task['endTime'] = editEndTime;

                      // Keep the task's existing workflow status.
                      task['status'] = editStatus;
                      task['repeat'] = editRepeat;
                      task['repeatDays'] = editRepeatDays.toList();
                    });

                    // Close the Edit popup immediately.
                    Navigator.of(context).pop();

                    // Update the recurring-task template so future
                    // occurrences use the latest task settings.
                    await updateRecurringTaskTemplate(task);

                    // Rebuild the task's notification plan based on
                    // its current status, schedule, reminder, and priority.
                    await saveTasks();
                    await handleTaskStatusNotifications(task);
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

  // Rearranges tasks and saves the updated order
  Future<void> reorderTasks(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    setState(() {
      // Reordering while viewing every task
      if (selectedFilter == 'All' && searchQuery.trim().isEmpty) {
        final movedTask = tasks.removeAt(oldIndex);
        tasks.insert(newIndex, movedTask);
        return;
      }

      // Create a reordered copy of only the currently filtered tasks
      final filteredTasks = getFilteredTasks();
      final movedTask = filteredTasks.removeAt(oldIndex);
      filteredTasks.insert(newIndex, movedTask);

      // Find where filtered tasks appear inside the full task list
      final filteredIndexes = <int>[];

      for (int index = 0; index < tasks.length; index++) {
        if (filteredTasks.any((task) => identical(task, tasks[index]))) {
          filteredIndexes.add(index);
        }
      }

      // Replace only those positions, preserving hidden categories
      for (int index = 0; index < filteredIndexes.length; index++) {
        tasks[filteredIndexes[index]] = filteredTasks[index];
      }
    });

    await saveTasks();
  }

  @override
  Widget build(BuildContext context) {
    final int completedTasks = tasks
        .where((task) => task['completed'] == true)
        .length;

    final int inProgressTasks = tasks.where((task) {
      return (task['status']?.toString() ?? 'Not Started') == 'In Progress';
    }).length;

    final double progress = tasks.isEmpty ? 0 : completedTasks / tasks.length;

    final List<Map<String, dynamic>> filteredTasks = getFilteredTasks();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('TrakOn'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: openTaskSearch,
            icon: const Icon(Icons.search),
            tooltip: 'Search all tasks',
          ),
        ],
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
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

              const SizedBox(height: 18),

              const Text(
                'Welcome back to TrakOn!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              const Text(
                'Track. Focus. Achieve.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),

              const SizedBox(height: 32),

              // Daily motivational quote card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white12),
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
                padding: const EdgeInsets.all(22),
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
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 15),

                    // Complete Task Button
                    ElevatedButton(
                      onPressed: isViewingToday()
                          ? () async {
                              if (dayCompleted) {
                                await undoCompleteDay();
                              } else {
                                final bool? confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Complete Day'),
                                    content: const Text(
                                      'Are you sure you completed your day?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('No'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
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
                        dayCompleted ? '✅ Day Complete' : '⭕ Mark Day Complete',
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

              const SizedBox(height: 32),

              Container(
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          getMonthYearLabel(displayedWeekStart),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$completedTasks out of ${tasks.length} completed',
                              style: const TextStyle(
                                color: Colors.greenAccent, // Matches Complete
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '$inProgressTasks in progress',
                              style: const TextStyle(
                                color: Colors.amber, // Matches In Progress
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () {
                            setState(() {
                              displayedWeekStart = displayedWeekStart.subtract(
                                const Duration(days: 7),
                              );
                            });
                          },
                          icon: const Icon(
                            Icons.chevron_left,
                            color: Colors.white,
                          ),
                        ),

                        Text(
                          '${displayedWeekStart.month}/${displayedWeekStart.day}'
                          ' - '
                          '${displayedWeekStart.add(const Duration(days: 6)).month}/'
                          '${displayedWeekStart.add(const Duration(days: 6)).day}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        IconButton(
                          onPressed: () {
                            setState(() {
                              displayedWeekStart = displayedWeekStart.add(
                                const Duration(days: 7),
                              );
                            });
                          },
                          icon: const Icon(
                            Icons.chevron_right,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    SizedBox(
                      height: 110,
                      child: Row(
                        children: List.generate(7, (index) {
                          final date = displayedWeekStart.add(
                            Duration(days: index),
                          );
                          final dateKey = getDateKey(date);
                          final todayKey = getDateKey(DateTime.now());

                          final isSelected = selectedTaskDate == dateKey;
                          final isToday = dateKey == todayKey;

                          final dayNames = [
                            'Sun',
                            'Mon',
                            'Tues',
                            'Wed',
                            'Thurs',
                            'Fri',
                            'Sat',
                          ];

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

                                  return Expanded(
                                    child: GestureDetector(
                                      onTap: () async {
                                        await saveTasks();

                                        final prefs =
                                            await SharedPreferences.getInstance();

                                        setState(() {
                                          selectedTaskDate = dateKey;
                                        });

                                        await prefs.setString(
                                          userKey('selectedTaskDate'),
                                          selectedTaskDate,
                                        );

                                        await loadTasksForSelectedDate();
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        curve: Curves.easeOut,
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              dayNames[date.weekday % 7],
                                              style: TextStyle(
                                                color: isSelected
                                                    ? Colors.white
                                                    : Colors.white70,
                                                fontSize: 12,
                                                fontWeight: isSelected
                                                    ? FontWeight.w600
                                                    : FontWeight.normal,
                                              ),
                                            ),

                                            const SizedBox(height: 8),

                                            AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 200,
                                              ),
                                              curve: Curves.easeOut,
                                              padding: EdgeInsets.all(
                                                isSelected ? 3 : 0,
                                              ),
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: isSelected
                                                    ? ringColor.withValues(
                                                        alpha: 0.10,
                                                      )
                                                    : Colors.transparent,
                                                border: isSelected
                                                    ? Border.all(
                                                        color: ringColor,
                                                        width: 1.5,
                                                      )
                                                    : null,
                                              ),
                                              child: CustomPaint(
                                                painter: DayProgressPainter(
                                                  progress: dayProgress,
                                                  color: ringColor,
                                                ),
                                                child: SizedBox(
                                                  width: isSelected ? 46 : 42,
                                                  height: isSelected ? 46 : 42,
                                                  child: Center(
                                                    child:
                                                        dayProgress >= 1.0 &&
                                                            taskCount > 0
                                                        // When every task for this day is complete,
                                                        // replace the date number with a large green check.
                                                        ? const Icon(
                                                            Icons.check,
                                                            color: Colors
                                                                .greenAccent,
                                                            size: 28,
                                                          )
                                                        : Text(
                                                            '${date.day}',
                                                            style: TextStyle(
                                                              color: isSelected
                                                                  ? ringColor
                                                                  : isToday
                                                                  ? Colors.white
                                                                  : Colors
                                                                        .white70,
                                                              fontWeight:
                                                                  isSelected
                                                                  ? FontWeight
                                                                        .w700
                                                                  : FontWeight
                                                                        .w600,
                                                              fontSize:
                                                                  isSelected
                                                                  ? 18
                                                                  : 16,
                                                            ),
                                                          ),
                                                  ),
                                                ),
                                              ),
                                            ),

                                            const SizedBox(height: 6),
                                            SizedBox(
                                              width: 50,
                                              child: Text(
                                                taskCount == 1
                                                    ? '1 task'
                                                    : '$taskCount tasks',
                                                textAlign: TextAlign.center,
                                                maxLines: 1,
                                                overflow: TextOverflow.visible,
                                                style: const TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
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
              TextField(
                controller: searchController,
                onChanged: (value) => setState(() => searchQuery = value),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search tasks',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searchQuery.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() {
                            searchController.clear();
                            searchQuery = '';
                          }),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButton<String>(
                value: selectedFilter,
                dropdownColor: Colors.grey[900],
                isExpanded: true,
                style: const TextStyle(color: Colors.white),
                items: ['All', ...categories].map((filter) {
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
                  : ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      itemCount: filteredTasks.length,
                      onReorder: reorderTasks,
                      itemBuilder: (context, index) {
                        final task = filteredTasks[index];
                        return Card(
                          key: ObjectKey(task),
                          color: Colors.white10,
                          child: ListTile(
                            onTap: () => showTaskDetails(task),
                            leading: GestureDetector(
                              onTap: () async {
                                // Get the task that the user tapped.
                                final task = filteredTasks[index];

                                final currentStatus =
                                    task['status']?.toString() ?? 'Not Started';
                                final statusDate = selectedTaskDate;

                                setState(() {
                                  if (currentStatus == 'Complete') {
                                    // Reopen a completed task.
                                    task['status'] = 'Not Started';
                                    task['completed'] = false;
                                  } else {
                                    // Quick-complete any unfinished task.
                                    task['status'] = 'Complete';
                                    task['completed'] = true;
                                  }
                                });

                                // Persist this occurrence before rebuilding its reminders.
                                await saveTasks();
                                await handleTaskStatusNotifications(task);
                                offerUndoStatus(
                                  task,
                                  currentStatus,
                                  statusDate,
                                );

                                if (!mounted) return;

                                setState(() {});
                              },
                              child: CustomPaint(
                                painter: DayProgressPainter(
                                  // Not Started = empty
                                  // In Progress = half filled
                                  // Complete = fully filled
                                  progress:
                                      (task['status']?.toString() ??
                                              'Not Started') ==
                                          'Complete'
                                      ? 1.0
                                      : (task['status']?.toString() ??
                                                'Not Started') ==
                                            'In Progress'
                                      ? 0.5
                                      : 0.0,

                                  // Amber while in progress, green when complete.
                                  color:
                                      (task['status']?.toString() ??
                                              'Not Started') ==
                                          'In Progress'
                                      ? Colors.amber
                                      : Colors.greenAccent,
                                ),
                                child: SizedBox(
                                  width: 34,
                                  height: 34,
                                  child: Center(
                                    child:
                                        (task['status']?.toString() ??
                                                'Not Started') ==
                                            'Complete'
                                        ? const Icon(
                                            Icons.check,
                                            color: Colors.greenAccent,
                                            size: 20,
                                          )
                                        : (task['status']?.toString() ??
                                                  'Not Started') ==
                                              'In Progress'
                                        ? const Icon(
                                            Icons.play_arrow,
                                            color: Colors.amber,
                                            size: 18,
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
                                  '${filteredTasks[index]['category'] ?? '🏠 Personal'} • '
                                  '${filteredTasks[index]['title']}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    decoration:
                                        filteredTasks[index]['completed'] ==
                                            true
                                        ? TextDecoration.lineThrough
                                        : TextDecoration.none,
                                  ),
                                ),

                                if ((filteredTasks[index]['description'] ?? '')
                                    .toString()
                                    .isNotEmpty)
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

                                if (filteredTasks[index]['priority'] != null)
                                  Text(
                                    filteredTasks[index]['priority'],
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),

                                if (task['tags'] is List &&
                                    (task['tags'] as List).isNotEmpty)
                                  Text(
                                    (task['tags'] as List)
                                        .map((tag) => '#$tag')
                                        .join('  '),
                                    style: const TextStyle(
                                      color: Colors.greenAccent,
                                      fontSize: 12,
                                    ),
                                  ),

                                // ---------------------------------------------------------------------------
                                // TASK STATUS
                                // ---------------------------------------------------------------------------

                                // Shows the task's current workflow status.
                                // Tapping the status moves the task through:
                                // Not Started -> In Progress -> Complete.
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: GestureDetector(
                                    onTap: () async {
                                      final task = filteredTasks[index];

                                      final currentStatus =
                                          task['status']?.toString() ??
                                          'Not Started';
                                      final statusDate = selectedTaskDate;

                                      String nextStatus;

                                      if (currentStatus == 'Not Started') {
                                        nextStatus = 'In Progress';
                                      } else if (currentStatus ==
                                          'In Progress') {
                                        nextStatus = 'Complete';
                                      } else {
                                        nextStatus = 'Not Started';
                                      }

                                      setState(() {
                                        // Update the workflow status.
                                        task['status'] = nextStatus;

                                        // Keep the existing completed field synchronized
                                        // with the new status system.
                                        task['completed'] =
                                            nextStatus == 'Complete';
                                      });

                                      // Persist this occurrence before rebuilding its reminders.
                                      await saveTasks();
                                      await handleTaskStatusNotifications(task);
                                      offerUndoStatus(
                                        task,
                                        currentStatus,
                                        statusDate,
                                      );

                                      if (!mounted) return;

                                      setState(() {});
                                    },
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          (filteredTasks[index]['status'] ??
                                                      'Not Started') ==
                                                  'Complete'
                                              ? Icons.check_circle_outline
                                              : (filteredTasks[index]['status'] ??
                                                        'Not Started') ==
                                                    'In Progress'
                                              ? Icons.play_circle_outline
                                              : Icons.radio_button_unchecked,
                                          size: 16,
                                          color:
                                              (filteredTasks[index]['status'] ??
                                                      'Not Started') ==
                                                  'Complete'
                                              ? Colors.greenAccent
                                              : (filteredTasks[index]['status'] ??
                                                        'Not Started') ==
                                                    'In Progress'
                                              ? Colors.amber
                                              : Colors.white54,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          filteredTasks[index]['status']
                                                  ?.toString() ??
                                              'Not Started',
                                          style: TextStyle(
                                            color:
                                                (filteredTasks[index]['status'] ??
                                                        'Not Started') ==
                                                    'Complete'
                                                ? Colors.greenAccent
                                                : (filteredTasks[index]['status'] ??
                                                          'Not Started') ==
                                                      'In Progress'
                                                ? Colors.amber
                                                : Colors.white60,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // ---------------------------------------------------------------------------
                                // TASK SCHEDULE DISPLAY
                                // ---------------------------------------------------------------------------

                                // Show the optional scheduled time window when one exists.
                                if (filteredTasks[index]['startTime'] != null ||
                                    filteredTasks[index]['endTime'] != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.schedule,
                                          size: 15,
                                          color: Colors.white54,
                                        ),

                                        const SizedBox(width: 5),

                                        Text(
                                          filteredTasks[index]['startTime'] !=
                                                      null &&
                                                  filteredTasks[index]['endTime'] !=
                                                      null
                                              ? '${filteredTasks[index]['startTime']} - ${filteredTasks[index]['endTime']}'
                                              : filteredTasks[index]['startTime'] !=
                                                    null
                                              ? 'Starts ${filteredTasks[index]['startTime']}'
                                              : 'Ends ${filteredTasks[index]['endTime']}',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                // Show recurrence underneath repeating tasks.
                                if ((filteredTasks[index]['repeat'] ??
                                        'Never') !=
                                    'Never')
                                  Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Text(
                                      '🔁 ${filteredTasks[index]['repeat']}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                if (filteredTasks[index]['reminderTime'] !=
                                    null)
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
                                ReorderableDragStartListener(
                                  index: index,
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: Icon(
                                      Icons.drag_handle,
                                      color: Colors.white54,
                                      size: 22,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  constraints: const BoxConstraints(
                                    minWidth: 34,
                                    minHeight: 34,
                                  ),
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.greenAccent,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    showEditTaskPopup(task);
                                  },
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  constraints: const BoxConstraints(
                                    minWidth: 34,
                                    minHeight: 34,
                                  ),
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.redAccent,
                                    size: 20,
                                  ),
                                  tooltip: 'Delete task',
                                  onPressed: () => deleteTaskWithUndo(task),
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

  DayProgressPainter({required this.progress, this.color = Colors.greenAccent});

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
