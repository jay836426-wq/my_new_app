import 'package:flutter/material.dart';

import 'planner_screen.dart';

/// Calendar and Planner share the same dated tasks and recurrence rules.
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});
  @override
  Widget build(BuildContext context) => const PlannerScreen(calendarMode: true);
}
