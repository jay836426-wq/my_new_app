import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // streak counter
  int streakCounter = 0;

  // Calculates how much of today's tasks are completed
  double getProgress() {
    // If there are no tasks, progress is 0%
    if (tasks.isEmpty) return 0;

    // Count how many tasks are marked as completed
    int completed = tasks.where((task) => task['completed'] == true).length;

    // Return progress as a value between 0.0 and 1.0
    return completed / tasks.length;
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

    // Convert tasks list into a JSON string
    final String encodedTasks = jsonEncode(tasks);

    await prefs.setString('tasks', encodedTasks);
  }

  // Loads saved tasks from local phone storage
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

  // Runs when HomeScreen first opens
  @override
  void initState() {
    super.initState();
    loadTasks();
  }

  void showAddTaskPopup() {

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.black,
          title: const Text('Add Task', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: 300,
            child: TextField(
              controller: taskController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Task name',
                labelStyle: TextStyle(color: Colors.white),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
              ),
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
              onPressed: () {
                final newTask = taskController.text.trim();

                if (newTask.isNotEmpty) {
                  setState(() {
                    tasks.add({
                      'title': newTask,
                      'completed': false,
                    }); // SAVE TASK
                  });
                  saveTasks();
                }

                Navigator.pop(context);
                taskController.clear();
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
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

  @override
  Widget build(BuildContext context) {
    final double progress = getProgress();
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
              const Text(
                'Welcome to Traqon!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
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

                    const SizedBox(height: 8),

                    Text(
                      '${(progress * 100).toInt()}% complete',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              if (streakCounter > 0)
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

              // TASK LIST
              tasks.isEmpty
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
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          return Card(
                            color: Colors.white10,
                            child: ListTile(
                              leading: Checkbox(
                                value: tasks[index]['completed'],
                                activeColor: Colors.white,
                                checkColor: Colors.black,
                                onChanged: (value) {
                                  setState(() {
                                    tasks[index]['completed'] = value!;
                                  });

                                  saveTasks();
                                },
                              ),
                              title: Text(
                                tasks[index]['title'],
                                style: TextStyle(
                                  color: Colors.white,
                                  decoration: tasks[index]['completed']
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () {
                                  setState(() {
                                    tasks.removeAt(index);
                                  });
                                  saveTasks();
                                },
                              ),
                            ),
                          );
                        },
                      ),

              const SizedBox(height: 16),

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
                      'Tasks complete for the day!',
                      style: TextStyle(
                        color: Colors.greenAccent,
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