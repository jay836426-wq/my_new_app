import 'package:flutter/material.dart';
import '../models/task_model.dart';

class FutureTasksScreen extends StatefulWidget {
  const FutureTasksScreen({super.key});

  @override
  State<FutureTasksScreen> createState() => _FutureTasksScreenState();
}

class _FutureTasksScreenState extends State<FutureTasksScreen> {
  final List<Task> _tasks = [];

  void _showAddTaskDialog() {
    final TextEditingController titleController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Future Task'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Task Title'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Due: ${selectedDate.month}/${selectedDate.day}/${selectedDate.year}',
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2100),
                          );

                          if (pickedDate != null) {
                            setDialogState(() {
                              selectedDate = pickedDate;
                            });
                          }
                        },
                        child: const Text('Pick Date'),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (titleController.text.trim().isEmpty) return;

                    setState(() {
                      _tasks.add(
                        Task(
                          title: titleController.text.trim(),
                          dueDate: selectedDate,
                        ),
                      );

                      _tasks.sort((a, b) => a.dueDate.compareTo(b.dueDate));
                    });

                    Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Future Tasks')),
      body: _tasks.isEmpty
          ? const Center(
              child: Text(
                'No future tasks yet.',
                style: TextStyle(fontSize: 18),
              ),
            )
          : ListView.builder(
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                final task = _tasks[index];

                return ListTile(
                  title: Text(task.title),
                  subtitle: Text(
                    '${task.dueDate.month}/${task.dueDate.day}/${task.dueDate.year}',
                  ),
                  trailing: Checkbox(
                    value: task.isCompleted,
                    onChanged: (value) {
                      setState(() {
                        task.isCompleted = value ?? false;
                      });
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
