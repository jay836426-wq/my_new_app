import '../utils/motivational_quotes.dart';
import '../services/engagement_service.dart';
import '../widgets/home_mood_card.dart';
import 'mood_check_in_screen.dart';
import 'check_in_settings_screen.dart';
import '../services/check_in_service.dart';
import '../services/account_planning_store.dart';

import 'dart:async';
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
import '../utils/planning_rules.dart';
import '../services/planning_store.dart';
import '../widgets/task_options_editor.dart';
import 'recently_deleted_screen.dart';
import 'focus_timer_screen.dart';

// ---------------------------
// Home Screen
// ---------------------------
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.initialDate, this.initialTaskId});
  final String? initialDate;
  final String? initialTaskId;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _homeReady = false;
  String? _loadError;
  late PlanningStore _store;
  Timer? _midnightTimer;
  Future<void>? _dayChangeInFlight;
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
  late final String _ownerId;
  String get currentUserId => _ownerId;

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

  Future<void> saveAppStateFieldsToCloud(Map<String, dynamic> fields) async {
    try {
      await userAppStateDocument.set({
        ...fields,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error) {
      debugPrint('Could not save app state to Firestore: $error');
    }
  }

  Future<void> saveDayCompletionToCloud(String dateKey, bool completed) async {
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
      final snapshot = await userCloudDocument
          .collection('taskDays')
          .doc(dateKey)
          .get();

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

    final DateTime yesterday = DateTime(today.year, today.month, today.day - 1);

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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Day status updated.')));
  }

  // Runs when Home screen is first opened and loads the saved username
  @override
  void initState() {
    super.initState();
    _ownerId = FirebaseAuth.instance.currentUser!.uid;
    WidgetsBinding.instance.addObserver(this);

    final now = DateTime.now();

    // Starts the weekly preview on the most recent Sunday
    displayedWeekStart = DateTime(
      now.year,
      now.month,
      now.day - now.weekday % 7,
    );
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
      displayedWeekStart = sundayOf(date);
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
    try {
      await loadTasks();
      await checkForNewDay();
      if (!mounted) return;
      if (widget.initialDate != null) {
        selectedTaskDate = widget.initialDate!;
        final selected = parseDay(selectedTaskDate);
        displayedWeekStart = DateTime(
          selected.year,
          selected.month,
          selected.day - selected.weekday % 7,
        );
      }
      await loadTasksForSelectedDate();
      await checkStreakReset();
      if (!mounted) return;
      setState(() {
        _homeReady = true;
        _loadError = null;
      });
      _scheduleMidnightRefresh();
      try {
        await CheckInService.apply(_store);
        await _refreshEngagement();
      } catch (error) {
        debugPrint('Could not refresh optional check-ins: $error');
      }
      try {
        await refreshAllRecurringReminders();
      } catch (error) {
        debugPrint('Reminder refresh failed: $error');
      }
      if (mounted && widget.initialTaskId != null) {
        final matches = tasks.where(
          (t) => taskIdentity(t) == widget.initialTaskId,
        );
        if (matches.isNotEmpty) showTaskDetails(matches.first);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _loadError = 'Could not load tasks. Please retry.');
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _homeReady) {
      refreshRemindersOnResume();
    }
  }

  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextDay = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(nextDay.difference(now), () async {
      if (!mounted || !_homeReady) return;
      try {
        await refreshRemindersOnResume();
      } finally {
        if (mounted) _scheduleMidnightRefresh();
      }
    });
  }

  Future<void> refreshRemindersOnResume() async {
    _scheduleMidnightRefresh();
    await checkForNewDay();
    if (!mounted) return;
    await checkStreakReset();
    if (!mounted) return;
    await refreshAllRecurringReminders();
    await refreshDailyTaskNotifications();
    try {
      await CheckInService.refreshMood(_store);
    } catch (e) {
      debugPrint('Mood reminder refresh failed: $e');
    }
    await _refreshEngagement();
    if (mounted) setState(() {});
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
              task.remove('previousStatus');
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

  Future<void> undoTaskStatus(Map<String, dynamic> task) async {
    final previous = task['previousStatus'];
    if (previous is! String) return;
    setState(() {
      task.remove('previousStatus');
      task['status'] = previous;
      task['completed'] = previous == 'Complete';
    });
    await saveTasks();
    await handleTaskStatusNotifications(task);
  }

  bool _deletingTask = false;

  Future<void> deleteTaskWithUndo(Map<String, dynamic> task) async {
    if (_deletingTask || !tasks.contains(task)) return;
    _deletingTask = true;
    final date = selectedTaskDate;
    try {
      if (task['recurringId'] != null) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Delete recurring series?'),
            content: const Text(
              'This stops this series from the selected date onward. Past history stays. You can restore it in Recently Deleted.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Delete series'),
              ),
            ],
          ),
        );
        if (confirm != true) return;
      }
      final entry = await _store.deleteTask(date, task);
      if (task['recurringId'] != null) {
        await _recurringReminderUpdates;
        await cancelRecurringReminders(task);
        await refreshAllRecurringReminders();
      } else {
        await cancelTaskReminders(task);
      }
      if (!mounted) return;
      await loadTasksForSelectedDate();
      await refreshDailyTaskNotifications();
      await _refreshEngagement();
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: const Text('Task moved to Recently Deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              try {
                await _store.restoreDeleted(entry['id'].toString());
                if (!mounted) return;
                await loadTasksForSelectedDate();
                await refreshAllRecurringReminders();
                await _refreshEngagement();
                await handleTaskStatusNotifications(task);
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Restore failed. The recovery copy is kept.',
                      ),
                    ),
                  );
                }
              }
            },
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not finish deletion. Check Recently Deleted before retrying.',
            ),
          ),
        );
      }
    } finally {
      _deletingTask = false;
    }
  }

  Future<void> _refreshEngagement() async {
    try {
      await EngagementService.refresh(_store);
    } catch (e) {
      debugPrint('Optional encouragement refresh failed: $e');
    }
  }

  final Set<String> _statusActions = {};
  Future<void> _setTaskStatus(TaskData task, String status) async {
    final id = taskIdentity(task);
    if (_statusActions.contains(id) || !tasks.contains(task)) return;
    setState(() {
      _statusActions.add(id);
      task['previousStatus'] = task['status'] ?? 'Not Started';
      task['status'] = status;
      task['completed'] = status == 'Complete';
    });
    try {
      await saveTasks();
      await handleTaskStatusNotifications(task);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not finish saving. Please reopen this task and retry.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _statusActions.remove(id));
    }
  }

  Widget _activeTasksCard() {
    final active = tasks
        .where((t) => !isTaskComplete(t) && t['status'] == 'In Progress')
        .toList();
    if (active.isEmpty || !isViewingToday()) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2111),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withValues(alpha: .3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'IN PROGRESS',
            style: TextStyle(
              color: Colors.amber,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'One step at a time. Keep going when you are ready.',
            style: TextStyle(color: Colors.white70),
          ),
          for (final task in active) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.play_circle_outline,
                color: Colors.amber,
              ),
              title: Text(
                task['title']?.toString() ?? 'Task',
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                taskSubtasks(task).isEmpty
                    ? 'In progress'
                    : '${taskSubtasks(task).where((s) => s['completed'] == true).length} of ${taskSubtasks(task).length} steps completed',
                style: const TextStyle(color: Colors.white70),
              ),
              onTap: () => showTaskDetails(task),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.timer_outlined),
                  label: const Text('Continue focusing'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => FocusTimerScreen(
                        taskTitle: task['title']?.toString(),
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => showTaskDetails(task),
                  child: Text(
                    taskSubtasks(task).isEmpty
                        ? 'View details'
                        : 'Update subtasks',
                  ),
                ),
                TextButton(
                  onPressed: _statusActions.contains(taskIdentity(task))
                      ? null
                      : () => _setTaskStatus(task, 'Complete'),
                  child: const Text('Mark complete'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void showTaskDetails(Map<String, dynamic> task) {
    final date = selectedTaskDate;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF181B1A),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, update) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task['title']?.toString() ?? 'Task',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if ((task['description']?.toString() ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(task['description'].toString()),
                  ),
                Text('Status: ${task['status'] ?? 'Not Started'}'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (!isTaskComplete(task))
                      FilledButton.icon(
                        icon: Icon(
                          task['status'] == 'In Progress'
                              ? Icons.check
                              : Icons.play_arrow,
                        ),
                        label: Text(
                          task['status'] == 'In Progress'
                              ? 'Mark complete'
                              : 'Start task',
                        ),
                        onPressed: _statusActions.contains(taskIdentity(task))
                            ? null
                            : () async {
                                if (selectedTaskDate != date) return;
                                await _setTaskStatus(
                                  task,
                                  task['status'] == 'In Progress'
                                      ? 'Complete'
                                      : 'In Progress',
                                );
                                if (sheetContext.mounted) update(() {});
                              },
                      ),
                    if (task['status'] == 'In Progress')
                      TextButton(
                        onPressed: _statusActions.contains(taskIdentity(task))
                            ? null
                            : () async {
                                if (selectedTaskDate != date) return;
                                await _setTaskStatus(task, 'Not Started');
                                if (sheetContext.mounted) update(() {});
                              },
                        child: const Text('Return to Not started'),
                      ),
                  ],
                ),
                Text('Category: ${task['category'] ?? 'Personal'}'),
                if (task['priority'] != null)
                  Text('Priority: ${task['priority']}'),
                if (task['goalId'] != null)
                  Text('Goal: ${goalTitleFor(task['goalId'])}'),
                if (task['tags'] is List)
                  Text('Tags: ${(task['tags'] as List).join(', ')}'),
                Text(
                  'Time: ${task['startTime'] ?? 'Unscheduled'} – ${task['endTime'] ?? '—'}',
                ),
                if (taskDuration(task) != null)
                  Text('Duration: ${taskDuration(task)} minutes'),
                if (task['reminderTime'] != null)
                  Text('Reminder: ${task['reminderTime']}'),
                const SizedBox(height: 16),
                if (taskSubtasks(task).isNotEmpty)
                  const Text(
                    'Subtasks',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                for (final sub in taskSubtasks(task))
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(sub['title']?.toString() ?? ''),
                    value: sub['completed'] == true,
                    onChanged: (done) async {
                      if (selectedTaskDate != date) return;
                      final subs = taskSubtasks(task);
                      for (final item in subs) {
                        if (item['id'] == sub['id']) {
                          item['completed'] = done == true;
                        }
                      }
                      setState(() => task['subtasks'] = subs);
                      update(() {});
                      await saveTasks();
                    },
                  ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        showEditTaskPopup(task);
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit task'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => FocusTimerScreen(
                              taskTitle: task['title']?.toString(),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.timer_outlined),
                      label: const Text('Focus'),
                    ),
                  ],
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

    return quoteForDay(selectedDate);
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    taskController.dispose();
    descriptionController.dispose();
    searchController.dispose();
    tagsController.dispose();
    super.dispose();
  }

  // Loads all saved recurring-task templates.
  Future<List<Map<String, dynamic>>> loadRecurringTasks() async =>
      _store.listState('recurringTasks');

  Future<void> saveRecurringTasks(
    List<Map<String, dynamic>> recurringTasks,
  ) async {
    await _store.saveState('recurringTasks', recurringTasks);
  }

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
    recurringTask['subtasks'] = taskSubtasks(
      task,
    ).map((s) => {...s, 'completed': false}).toList();

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
      updatedTemplate['subtasks'] = taskSubtasks(
        task,
      ).map((s) => {...s, 'completed': false}).toList();

      // Future recurring occurrences should not inherit
      // the current occurrence's completed/in-progress state.
      updatedTemplate['status'] = 'Not Started';

      recurringTasks[index] = updatedTemplate;

      await saveRecurringTasks(recurringTasks);
    }
  }

  // Saves the task list to local phone storage
  Future<void> saveTasks() async {
    // Capture date and values before awaiting storage or network operations.
    final date = selectedTaskDate.isEmpty
        ? getDateKey(DateTime.now())
        : selectedTaskDate;
    final snapshot = tasks.map(copyTask).toList();
    final completed = dayCompleted;
    await _store.saveDay(date, snapshot);
    final prefs = _store.prefs;
    await prefs.setBool(userKey('dayCompleted_$date'), completed);
    await prefs.setInt(userKey('streakCounter'), streakCounter);
    await prefs.setString(userKey('lastCompletedDate'), lastCompletedDate);
    await prefs.setString(userKey('selectedTaskDate'), date);
    await saveDayCompletionToCloud(date, completed);
    await saveAppStateFieldsToCloud({
      'streakCounter': streakCounter,
      'lastCompletedDate': lastCompletedDate,
    });
    if (mounted && isViewingToday()) await refreshDailyTaskNotifications();
    await _refreshEngagement();
  }

  Future<void> loadTasks() async {
    _store = await AccountPlanningStore.current();
    if (_store.prefs.getBool(_store.key('homeMoodCardBuild10')) != true) {
      if (!await _store.prefs.setBool(_store.key('v12_moodPrompt'), true)) {
        throw StateError('Could not enable mood card');
      }
      await _store.prefs.setBool(_store.key('homeMoodCardBuild10'), true);
    }
    await _store.migrateLegacyCache();
    final prefs = _store.prefs;
    final cloudState = prefs.getInt(userKey('streakCounter')) == null
        ? await loadAppStateFromCloud()
        : null;
    if (!mounted) return;
    setState(() {
      selectedTaskDate = getDateKey(DateTime.now());
      tasks = [];
      streakCounter =
          prefs.getInt(userKey('streakCounter')) ??
          (cloudState?['streakCounter'] as num?)?.toInt() ??
          0;
      lastCompletedDate =
          prefs.getString(userKey('lastCompletedDate')) ??
          cloudState?['lastCompletedDate']?.toString() ??
          '';
      lastActiveDate = prefs.getString(userKey('lastActiveDate')) ?? '';
    });
  }

  Future<void> checkForNewDay() async {
    final pending = _dayChangeInFlight;
    if (pending != null) return pending;
    final update = _performDayChange();
    _dayChangeInFlight = update;
    try {
      await update;
    } finally {
      _dayChangeInFlight = null;
    }
  }

  Future<void> _performDayChange() async {
    final previous = _store.prefs.getString(userKey('lastActiveDate'));
    await _store.prepareToday();
    if (!mounted) return;
    final today = getDateKey(DateTime.now());
    if (previous != today) {
      setState(() {
        lastActiveDate = today;
        selectedTaskDate = today;
        dayCompleted = false;
      });
      await loadTasksForSelectedDate();
    }
    final carry = _store.carryOver.map(copyTask).toList();
    final from = _store.previousDate;
    if (carry.isEmpty || !mounted) return;
    final accept = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: const Text('Carry over unfinished tasks?'),
        content: Text(
          '${carry.length} unfinished tasks from $from. Recurring tasks follow their own schedule.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Skip'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Carry Over'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (accept == true) {
      // Carry into today even if Home was opened for a future calendar date.
      final todayTasks = await _store.readDay(today);
      for (final task in carry) {
        if (!todayTasks.any((t) => taskIdentity(t) == taskIdentity(task))) {
          todayTasks.add(copyTask(task)..['date'] = today);
        }
      }
      await _store.saveDay(today, todayTasks);
      if (selectedTaskDate == today) await loadTasksForSelectedDate();
    }
    await _store.prefs.remove(userKey('pendingCarryOverV12'));
    _store.carryOver = [];
  }

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

    final DateTime yesterday = DateTime(today.year, today.month, today.day - 1);
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
  bool recurringTaskRunsOnDate(Map<String, dynamic> task, DateTime date) =>
      taskRunsOnDate(task, date);

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
  String getTaskStorageKey(String dateKey) => userKey('tasks_$dateKey');

  Future<void> loadTasksForSelectedDate() async {
    final date = selectedTaskDate;
    final rebuilt = await _store.readDay(date);
    final completed =
        _store.prefs.getBool(userKey('dayCompleted_$date')) ??
        await loadDayCompletionFromCloud(date) ??
        false;
    if (!mounted || selectedTaskDate != date) return;
    setState(() {
      tasks = rebuilt;
      dayCompleted =
          completed && rebuilt.isNotEmpty && rebuilt.every(isTaskComplete);
      selectedFilter = 'All';
    });
  }

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
        !await NotificationPreferences.taskRemindersEnabled()) {
      return;
    }
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
    for (final storageKey in prefs.getKeys()) {
      if (!storageKey.startsWith(userKey('tasks_'))) continue;
      final key = storageKey.substring(userKey('tasks_').length);
      DateTime date;
      try {
        date = parseDay(key);
      } catch (_) {
        continue;
      }
      if (date.isBefore(first)) continue;
      final saved = jsonDecode(prefs.getString(storageKey) ?? '[]') as List;
      for (final value in saved) {
        if (value is Map &&
            value['recurringId'] == template['recurringId'] &&
            (value['date'] == null || value['date'] == key)) {
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
        !await NotificationPreferences.taskRemindersEnabled()) {
      return;
    }

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
    final minutes = timeMinutes(reminderText);
    return minutes == null
        ? null
        : TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }

  Future<void> openRecentlyDeleted() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const RecentlyDeletedScreen()),
    );
    if (!mounted) return;
    await loadTasksForSelectedDate();
    await refreshAllRecurringReminders();
    for (final task in tasks) {
      if (task['recurringId'] == null) {
        await handleTaskStatusNotifications(task);
      }
    }
    await refreshDailyTaskNotifications();
  }

  String? taskTimeLabel(TimeOfDay? time) =>
      time == null ? null : minutesLabel(time.hour * 60 + time.minute);

  void showAddTaskPopup() {
    Map<String, dynamic> extraOptions = {
      'subtasks': <Map<String, dynamic>>[],
      'repeatInterval': 1,
    };
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
                      TaskOptionsEditor(
                        value: extraOptions,
                        repeat: selectedRepeat,
                        onChanged: (value) => extraOptions = value,
                      ),
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
                            value: 'Monthly',
                            child: Text('Repeat: Monthly'),
                          ),
                          DropdownMenuItem(
                            value: 'Yearly',
                            child: Text('Repeat: Yearly'),
                          ),
                          DropdownMenuItem(
                            value: 'Every N Days',
                            child: Text('Repeat: Every N Days'),
                          ),
                          DropdownMenuItem(
                            value: 'Every N Weeks',
                            child: Text('Repeat: Every N Weeks'),
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
                    final candidate = <String, dynamic>{
                      ...extraOptions,
                      'title': newTaskTitle,
                      'startDate': selectedTaskDate,
                      'date': selectedTaskDate,
                      'repeat': selectedRepeat,
                      'repeatDays': selectedRepeatDays.toList(),
                      'startTime': taskTimeLabel(selectedStartTime),
                      'endTime': taskTimeLabel(selectedEndTime),
                    };
                    final error = validatePlanningTask(candidate);
                    if (error != null) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(error)));
                      return;
                    }
                    applyDuration(candidate);

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
                      ...extraOptions,
                      'title': newTaskTitle,
                      'description': descriptionController.text.trim(),
                      'completed': selectedStatus == 'Complete',
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
                      'startTime': taskTimeLabel(selectedStartTime),
                      'endTime': candidate['endTime'],

                      // New tasks begin as Not Started.
                      'status': selectedStatus,

                      // Optional normal reminder.
                      'reminderTime': taskTimeLabel(selectedReminderTime),

                      // Stable notification ID for this task.
                      'id': DateTime.now().microsecondsSinceEpoch.toString(),
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
    Map<String, dynamic> extraOptions = {
      'subtasks': taskSubtasks(task).map(copyTask).toList(),
      'durationMinutes': taskDuration(task),
      'repeatInterval': task['repeatInterval'] ?? 1,
      'repeatUntil': task['repeatUntil'],
    };
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
                      TaskOptionsEditor(
                        value: extraOptions,
                        repeat: editRepeat,
                        onChanged: (value) => extraOptions = value,
                      ),
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
                            value: 'Monthly',
                            child: Text('Repeat: Monthly'),
                          ),
                          DropdownMenuItem(
                            value: 'Yearly',
                            child: Text('Repeat: Yearly'),
                          ),
                          DropdownMenuItem(
                            value: 'Every N Days',
                            child: Text('Repeat: Every N Days'),
                          ),
                          DropdownMenuItem(
                            value: 'Every N Weeks',
                            child: Text('Repeat: Every N Weeks'),
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
                    final candidate = <String, dynamic>{
                      ...task,
                      ...extraOptions,
                      'title': updatedTitle,
                      'repeat': editRepeat,
                      'repeatDays': editRepeatDays.toList(),
                      'startTime': editStartTime,
                      'endTime': editEndTime,
                    };
                    final error = validatePlanningTask(candidate);
                    if (error != null) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(error)));
                      return;
                    }
                    applyDuration(candidate);
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
                      if (task['status'] != editStatus) {
                        task['previousStatus'] =
                            task['status'] ?? 'Not Started';
                      }
                      task.addAll(extraOptions);
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
                      task['endTime'] = candidate['endTime'];

                      // Keep the task's existing workflow status.
                      task['status'] = editStatus;
                      task['completed'] = editStatus == 'Complete';
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

  Future<void> _openTools() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF181B19),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Your daily tools',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.mood, color: Colors.greenAccent),
                  title: const Text(
                    'Mood check-in',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'Reflect on today and view your history',
                    style: TextStyle(color: Colors.white70),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.white54,
                  ),
                  onTap: () => Navigator.pop(context, 'mood'),
                ),
                const Divider(color: Colors.white12),
                ListTile(
                  leading: const Icon(
                    Icons.notifications_outlined,
                    color: Colors.greenAccent,
                  ),
                  title: const Text(
                    'Reminders & check-ins',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'Choose what to hear about and when',
                    style: TextStyle(color: Colors.white70),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.white54,
                  ),
                  onTap: () => Navigator.pop(context, 'alerts'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => choice == 'mood'
            ? const MoodCheckInScreen()
            : const CheckInSettingsScreen(),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_homeReady) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(title: const Text('TrakOn')),
        body: Center(
          child: _loadError == null
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_loadError!),
                    TextButton(
                      onPressed: initializeHomeScreen,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
        ),
      );
    }
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
        automaticallyImplyLeading: widget.initialDate != null,
        actions: [
          IconButton(
            tooltip: 'More tools',
            icon: const Icon(Icons.more_horiz),
            onPressed: _openTools,
          ),
          IconButton(
            tooltip: 'Focus timer',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const FocusTimerScreen()),
            ),
            icon: const Icon(Icons.timer_outlined),
          ),
          IconButton(
            tooltip: 'Recently Deleted',
            onPressed: openRecentlyDeleted,
            icon: const Icon(Icons.restore_from_trash_outlined),
          ),
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

              if (_store.prefs.getBool(_store.key('v12_moodPrompt')) ?? true)
                HomeMoodCard(
                  store: _store,
                  onChanged: () {
                    if (mounted) setState(() {});
                  },
                ),
              _activeTasksCard(),
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
                              displayedWeekStart = calendarDay(
                                displayedWeekStart,
                                -7,
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
                          '${calendarDay(displayedWeekStart, 6).month}/'
                          '${calendarDay(displayedWeekStart, 6).day}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        IconButton(
                          onPressed: () {
                            setState(() {
                              displayedWeekStart = calendarDay(
                                displayedWeekStart,
                                7,
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
                          final date = calendarDay(displayedWeekStart, index);
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
                                  task['previousStatus'] = currentStatus;
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
                                        task['previousStatus'] = currentStatus;
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
                                  tooltip: 'Undo last status change',
                                  visualDensity: VisualDensity.compact,
                                  constraints: const BoxConstraints(
                                    minWidth: 34,
                                    minHeight: 34,
                                  ),
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.undo, size: 20),
                                  onPressed: task['previousStatus'] is String
                                      ? () => undoTaskStatus(task)
                                      : null,
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
