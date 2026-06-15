import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

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

  // Store the category selected in the dropdown
  String selectedCategory = '🏠 Personal';

  // Store the priority level is currently selected
  String? selectedPriority;

  // Stores which category filter is currently selected
  String selectedFilter = 'All';

  // Stores dynamic username for login
  String userName = 'User';

  // Store selected Reminder Time
  TimeOfDay ? selectedReminderTime;

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
        streakCounter = streakCounter;
      } else if (lastCompletedDate == yesterdayString) {
        // Completed yesterday, continue streak
        streakCounter += 1;
      } else {
        // Missed a day, reset streak
        streakCounter = 1;
      }

      lastCompletedDate = todayString;
    });

    await prefs.setBool('dayCompleted', dayCompleted);
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

    setState(() {
      dayCompleted = false;

      if (streakCounter > 0) {
        streakCounter -= 1;
      }
    });

    await prefs.setBool('dayCompleted', dayCompleted);
    await prefs.setInt('streakCounter', streakCounter);

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
    loadTasks().then((_) {
      checkForNewDay();
    });
    loadUserName();
    checkStreakReset();
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
      return "Add your first task to start your day.";
    }

    if (progress == 0) {
      return "Let’s get started 💪";
    }

    if (progress < 0.5) {
      return "Good start — keep going!";
    }

    if (progress < 1) {
      return "You’re on a roll 🔥";
    }

    return "Tasks complete for the day! 🎉";
  }

  @override
  void dispose() {
    taskController.dispose();
    super.dispose();
  }

  // Saves the task list to local phone storage
  Future<void> saveTasks() async {
    final prefs = await SharedPreferences.getInstance();

    selectedTaskDate = prefs.getString('selectedTaskDate') ?? '';

    // Convert tasks list into a JSON string
    final String encodedTasks = jsonEncode(tasks);

    final String todayKey =
    '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}';

    final String taskKey =
        (selectedTaskDate.isEmpty || selectedTaskDate == todayKey)
            ? 'tasks'
            : 'tasks_$selectedTaskDate';

    await prefs.setString(taskKey, encodedTasks);
    await prefs.setBool('dayCompleted', dayCompleted);
    await prefs.setInt('streakCounter', streakCounter);
    await prefs.setString('lastCompletedDate', lastCompletedDate);
    await prefs.setString('lastActiveDate', lastActiveDate);
    await prefs.setString('selectedTaskDate', selectedTaskDate);
  }

  // Loads saved tasks from local phone storage
  Future<void> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();

    selectedTaskDate = prefs.getString('selectedTaskDate') ?? '';

    final String todayKey =
    '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}';

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

        dayCompleted = prefs.getBool('dayCompleted') ?? false;
        streakCounter = prefs.getInt('streakCounter') ?? 0;
        lastCompletedDate = prefs.getString('lastCompletedDate') ?? '';
        lastActiveDate = prefs.getString('lastActiveDate') ?? '';
        selectedTaskDate = prefs.getString('selectedTaskDate') ?? '';
      });
    } else{
      setState(() {
        dayCompleted = prefs.getBool('dayCompleted') ?? false;
        streakCounter = prefs.getInt('streakCounter') ?? 0;
        lastCompletedDate = prefs.getString('lastCompletedDate') ?? '';
        lastActiveDate = prefs.getString('lastActiveDate') ?? '';
        selectedTaskDate = prefs.getString('selectedTaskDate') ?? '';
      });
    }
  }

  // Checks if a new day has started and resets tasks for a fresh day
  Future<void> checkForNewDay() async {
    final prefs = await SharedPreferences.getInstance();

    final DateTime today = DateTime.now();
    final String todayString = '${today.year}-${today.month}-${today.day}';

    if (lastActiveDate.isEmpty) {
      lastActiveDate = todayString;
      await prefs.setString('lastActiveDate', lastActiveDate);
      return;
    }

    if (lastActiveDate != todayString) {
        // New Day Started

      if(tasks.isNotEmpty) {
        final String historyKey = 'tasks_$lastActiveDate';
        final String encodedOldTasks = jsonEncode(tasks);

        await prefs.setString(
          historyKey,
          encodedOldTasks,
        );
      }

      setState(() {
        tasks = [];
        dayCompleted = false;
        lastActiveDate = todayString;
      });

      await saveTasks();
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

      await prefs.setInt('streakCounter', streakCounter);
      await prefs.setBool('dayCompleted', dayCompleted);
    }
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

                     const SizedBox(height: 24),
 
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
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );

                          if (picked != null) {
                            setDialogState(() {
                              selectedReminderTime = picked;
                            });
                          }
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
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newTask = taskController.text.trim();

                if (newTask.isNotEmpty) {
                  final TimeOfDay? reminderToSchedule = selectedReminderTime;
                  setState(() {
                    tasks.add({
                      'title': taskController.text,
                      'completed': false,
                      'category': selectedCategory,
                      'priority': selectedPriority,
                      'reminderTime': selectedReminderTime?.format(context),
                      'date': DateTime.now().toIso8601String(),
                    }); // SAVE TASK

                    selectedPriority = null;
                    selectedReminderTime = null;
                  });
                  if(reminderToSchedule != null) {
                        DateTime reminderDateTime = DateTime(
                          DateTime.now().year,
                          DateTime.now().month,
                          DateTime.now().day,
                          reminderToSchedule.hour,
                          reminderToSchedule.minute,
                    );
                    if(reminderDateTime.isBefore(DateTime.now())) {
                      reminderDateTime = reminderDateTime.add(
                        const Duration(days: 1),
                      );
                    }

                    await NotificationService.scheduleNotification(
                      id: tasks.length,
                      title: 'Task Reminder',
                      body: newTask,
                      scheduledTime: reminderDateTime,
                    );
                  };
                  saveTasks();
                }

                Navigator.pop(context);
                taskController.clear();
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
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );

                        if (picked != null) {
                          setDialogState(() {
                            editReminderTime = picked.format(context);
                          });
                        }
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
                  onPressed: () {
                    final updatedTitle = editController.text.trim();

                    if (updatedTitle.isNotEmpty) {
                      setState(() {
                        task['title'] = updatedTitle;
                        task['category'] = editCategory;
                        task['priority'] = editPriority;
                        task['reminderTime'] = editReminderTime;
                      });

                      saveTasks();
                      Navigator.pop(context);
                    }
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
    final double progress = getProgress();
    final List<Map<String, dynamic>> filteredTasks = getFilteredTasks();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Traqon'),
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
              Text(
                DateTime.now().hour < 12
                    ? 'Good Morning, $userName 👋 '
                    : DateTime.now().hour < 17
                        ? 'Good Afternoon, $userName 👋'
                        : 'Good Evening, $userName 👋',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                'Welcome back to Traqon!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              
              const Text(
                'Track. Focus. Achieve.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 32),

              const SizedBox(height: 30),

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

              // Complete Task Button
                ElevatedButton(
                  onPressed: () async {
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
                  },
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
              
                  child: Row(
                    children: [
                      Text('🔥', style: TextStyle(fontSize: 28)),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$streakCounter Day Streak',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Keep showing up daily.',
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                        ],
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
                              leading: Checkbox(
                                value: filteredTasks[index]['completed'],
                                activeColor: Colors.white,
                                checkColor: Colors.black,
                                onChanged: (value) {
                                  setState(() {
                                    filteredTasks[index]['completed'] = value!;
                                  });

                                  saveTasks();
                                },
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
                                  onPressed: () {
                                    setState(() {
                                      tasks.remove(filteredTasks[index]);
                                    });
                                    saveTasks();
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