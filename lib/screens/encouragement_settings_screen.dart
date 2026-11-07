import 'package:flutter/material.dart';
import '../services/account_planning_store.dart';
import '../services/planning_store.dart';
import '../services/engagement_service.dart';
import '../widgets/reminder_time_picker.dart';
import 'notification_service.dart';

class EncouragementSettingsScreen extends StatefulWidget {
  const EncouragementSettingsScreen({super.key});
  @override
  State<EncouragementSettingsScreen> createState() =>
      _EncouragementSettingsState();
}

class _EncouragementSettingsState extends State<EncouragementSettingsScreen> {
  PlanningStore? store;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final s = await AccountPlanningStore.current();
      if (mounted) setState(() => store = s);
    } catch (_) {
      if (mounted) setState(() => error = 'Could not load preferences.');
    }
  }

  bool flag(String key, [bool fallback = false]) =>
      store!.prefs.getBool(store!.key(key)) ?? fallback;
  int number(String key, int fallback) =>
      store!.prefs.getInt(store!.key(key)) ?? fallback;
  Future<void> change(
    Future<bool> Function() write, {
    bool permission = false,
  }) async {
    setState(() => busy = true);
    try {
      if (!await write()) throw StateError('Save failed');
      if (permission) {
        final granted = await NotificationService.requestPermissions();
        if (!granted && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Preference saved. Enable notifications in iPhone Settings to receive alerts.',
              ),
            ),
          );
        }
      }
      await EngagementService.refresh(store!);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not update alerts. Reopen this page and retry.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget toggle(
    String key,
    String title,
    String subtitle, {
    bool fallback = false,
  }) => SwitchListTile.adaptive(
    title: Text(title),
    subtitle: Text(subtitle),
    value: flag(key, fallback),
    onChanged: busy
        ? null
        : (v) => change(
            () => store!.prefs.setBool(store!.key(key), v),
            permission: v,
          ),
  );
  Future<void> time(String kind) async {
    final key = kind == 'Task' ? 'engagementTask' : 'engagement$kind';
    final chosen = await chooseReminderTime(
      context,
      TimeOfDay(
        hour: number(
          '${key}Hour',
          kind == 'Morning'
              ? 9
              : kind == 'Midday'
              ? 14
              : kind == 'Task'
              ? 18
              : 20,
        ),
        minute: number('${key}Minute', 0),
      ),
    );
    if (chosen == null || !mounted) return;
    await change(
      () async =>
          await store!.prefs.setInt(store!.key('${key}Hour'), chosen.hour) &&
          await store!.prefs.setInt(store!.key('${key}Minute'), chosen.minute),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (store == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Encouragement & check-ins')),
        body: Center(
          child: error == null
              ? const CircularProgressIndicator()
              : Text(error!),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Encouragement & check-ins')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Choose a little support throughout your day. These alerts are optional and also require the master notification switch. Task due-time, focus timer and mood alerts have their own controls.',
            ),
          ),
          toggle(
            'engagementEnabled',
            'Enable encouragement',
            'Turn on the new motivation, recognition and task check-in features.',
          ),
          for (final kind in ['Morning', 'Midday', 'Evening', 'Goals']) ...[
            toggle(
              'engagement$kind',
              {
                'Morning': 'A fresh start',
                'Midday': 'Midday motivation',
                'Evening': 'Evening reflection',
                'Goals': 'Goal check-ins',
              }[kind]!,
              kind == 'Goals'
                  ? 'Saturday and month-end check-ins for weekly, monthly and long-term goals.'
                  : kind == 'Evening'
                  ? 'Today’s saved task count when refreshed; a general reflection on future days.'
                  : 'A supportive message at your chosen time.',
            ),
            ListTile(
              title: const Text('Reminder time'),
              subtitle: Text(
                TimeOfDay(
                  hour: number(
                    'engagement${kind}Hour',
                    kind == 'Morning'
                        ? 9
                        : kind == 'Midday'
                        ? 14
                        : 20,
                  ),
                  minute: number('engagement${kind}Minute', 0),
                ).format(context),
              ),
              trailing: const Icon(Icons.schedule),
              onTap: busy ? null : () => time(kind),
            ),
          ],
          toggle(
            'engagementQuote',
            'Include quote of the day',
            'Adds a rotating quote to your morning message.',
            fallback: true,
          ),
          toggle(
            'engagementRecognition',
            'Celebrate real progress',
            'Recognize saved goal achievements, active-day streaks and consistency. At most one recognition per day.',
            fallback: true,
          ),
          const Divider(),
          toggle(
            'engagementTaskCheckIns',
            'Task-specific check-ins',
            'Up to five incomplete tasks today. Completed or deleted tasks are removed when the app updates their status.',
          ),
          ListTile(
            title: const Text('Task check-in time'),
            subtitle: Text(
              TimeOfDay(
                hour: number('engagementTaskHour', 18),
                minute: number('engagementTaskMinute', 0),
              ).format(context),
            ),
            onTap: busy ? null : () => time('Task'),
          ),
          const Divider(),
          toggle(
            'engagementQuiet',
            'Quiet hours',
            'Applies to this page’s new alerts; task due-time, mood and timer alerts remain separate.',
            fallback: true,
          ),
          for (final end in [false, true])
            ListTile(
              title: Text(end ? 'Quiet hours end' : 'Quiet hours start'),
              trailing: DropdownButton<int>(
                value: number(
                  end ? 'engagementQuietEnd' : 'engagementQuietStart',
                  end ? 8 : 22,
                ),
                items: [
                  for (var h = 0; h < 24; h++)
                    DropdownMenuItem(
                      value: h,
                      child: Text(
                        TimeOfDay(hour: h, minute: 0).format(context),
                      ),
                    ),
                ],
                onChanged: busy
                    ? null
                    : (v) => change(
                        () => store!.prefs.setInt(
                          store!.key(
                            end ? 'engagementQuietEnd' : 'engagementQuietStart',
                          ),
                          v!,
                        ),
                      ),
              ),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Equal start and end times mean no quiet window. Alerts deferred into the next day are skipped to avoid sending yesterday’s encouragement.',
            ),
          ),
          ListTile(
            title: const Text('Daily encouragement limit'),
            subtitle: const Text(
              'Includes scheduled motivation, goal check-ins and recognition. Task-specific check-ins are separate.',
            ),
            trailing: DropdownButton<int>(
              value: number('engagementDailyLimit', 3),
              items: [
                for (var n = 1; n <= 4; n++)
                  DropdownMenuItem(value: n, child: Text('$n')),
              ],
              onChanged: busy
                  ? null
                  : (v) => change(
                      () => store!.prefs.setInt(
                        store!.key('engagementDailyLimit'),
                        v!,
                      ),
                    ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Routine encouragement is scheduled up to seven days ahead and refreshed when you open TrakOn. Task check-ins and progress recognition use saved activity when the app runs.',
            ),
          ),
        ],
      ),
    );
  }
}
