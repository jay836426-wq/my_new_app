import 'package:flutter/material.dart';
import '../services/account_planning_store.dart';
import '../utils/planning_rules.dart';

class GoalAchievementsScreen extends StatefulWidget {
  const GoalAchievementsScreen({super.key});
  @override
  State<GoalAchievementsScreen> createState() => _GoalAchievementsState();
}

class _GoalAchievementsState extends State<GoalAchievementsScreen> {
  late Future<List<TaskData>> entries;
  @override
  void initState() {
    super.initState();
    entries = load();
  }

  Future<List<TaskData>> load() async =>
      (await AccountPlanningStore.current()).listState('goalAchievementsV13');
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Your achievements')),
    body: FutureBuilder<List<TaskData>>(
      future: entries,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(() => entries = load()),
              child: const Text('Could not load. Retry'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final all = snapshot.data!.reversed.toList();
        if (all.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Completed goal periods will appear here. Link tasks to a goal and complete them to build your history.',
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'A record of goals reached. Resetting progress or deleting a goal does not remove these achievements.',
              ),
            ),
            for (final a in all)
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.emoji_events,
                    color: Colors.greenAccent,
                  ),
                  title: Text(a['title']?.toString() ?? 'Goal'),
                  subtitle: Text(
                    '${a['period']} • ${a['target']} linked tasks completed\nPeriod includes ${a['periodDate']}',
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}
