class Task {
  String title;
  String? description;
  DateTime dueDate;
  bool isCompleted;

  Task({
    required this.title,
    this.description,
    required this.dueDate,
    this.isCompleted = false,
  });
}
