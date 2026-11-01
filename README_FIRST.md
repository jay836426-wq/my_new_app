# TrakOn 1.2 update — build 8

This is the complete replacement/addition bundle for the requested bug fixes and
1.2 upgrades. It supersedes the individual Home, Calendar and task-day files sent
earlier. Base: jay836426-wq/my_new_app, commit 6d02342 (1.1.0+7).

**Status: implementation candidate for testing. Do not submit it to the App Store
until the Mac and iPhone checks below pass.**

## Install on your coding laptop

1. Commit your current work in GitHub Desktop so you have a known starting point.
2. Extract this ZIP. Keep this entire folder together.
3. Open Terminal. Run the following, replacing the project path with your actual
   `my_new_app` folder. You can drag that folder from Finder into Terminal to insert
   its path:

```bash
python3 ~/Downloads/TrakOn_1.2_Update/apply_update.py "/path/to/my_new_app"
```

The script checks the package, backs up affected existing files beside your project,
and copies only the 23 files listed in FILES.json. It preserves every other project
file, including signing configuration and assets. It never commits, pushes or uploads.
If your extracted download has a different location, adjust the script path too.

Alternatively, copy the files individually using FILES_TO_COPY.md. Create folders
such as `lib/services` and `lib/widgets` if they do not exist. **Merge the supplied
files; do not replace your entire lib or test directory.** Files labelled Add may
already exist if you installed the earlier individual fixes; replace those copies.

## What is included

- Daily reset fix: every date has its own task record. An explicit date owns the
  legacy current-day cache, preventing yesterday's tasks being backed up as today.
  A one-time local migration backup is retained before conversion.
- Home rechecks dates on reopening/resuming and at midnight while it remains mounted.
  Calendar, Planner, Search and Stats use the same dated storage rules.
- Incomplete normal tasks can be carried forward. Recurring tasks are regenerated
  from their schedule instead of being carried forward as duplicate occurrences.
- Per-task status Undo: a small undo icon restores the last status change. The
  previous status is saved for that task occurrence, and does not leak into tomorrow.
- Recently Deleted: deleted tasks can be recovered after the 8-second snackbar is
  gone, even after closing the app. Restoring preserves date, task details, subtasks,
  and saved recurrence settings. Permanent deletion removes the recovery copy.
- Recurring deletion has an explicit confirmation. The series stops from the chosen
  date onward; saved history before that date remains. Deleting a future occurrence
  leaves intervening dates scheduled. Restoring one deletion respects other active
  deletions of the same series.
- Weekly and long-term goals: weekly means Monday–Sunday and counts linked task
  occurrences dated within that week. Long-term counts through today. Reset records
  a baseline of already-counted completions without clearing tasks or statistics.
- Planner and Calendar: day/week/month views, navigation and date selection, completed
  day markers, an agenda sorted by start time, duration totals and overlap warnings.
  "Plan this day" opens that date's existing Add/Edit task flow. Tapping a task opens
  its details. This is a manual planner, not an automatic schedule generator.
- Focus timer: focus/break modes, preset/custom durations, pause/resume/reset, completed
  session count, and a persisted UTC deadline that survives backgrounding/restarts.
  The session count is local to the account on that device. Alerts need notification
  permission and depend on the OS delivering local notifications.
- More recurrence: Monthly, Yearly, Every N Days (1–365), Every N Weeks (1–52), and an
  optional inclusive end date. A monthly 31st uses the last day of a shorter month,
  then returns to the 31st. A yearly February 29 uses February 28 in non-leap years.
- Task durations/time blocks: enter minutes in Add/Edit Task. With a start time,
  duration sets the end time. Blocks must end before midnight. Planner flags overlaps;
  it does not prevent deliberately overlapping tasks.
- Subtasks: add/remove named steps in Add/Edit, check steps in task details. Each
  recurring date gets its own fresh checklist. Parent task status remains separate.
- Export: Planner/Calendar share menu exports visible dates or saved history as CSV,
  or saved history as JSON. The native share sheet can save the file. Unopened future
  recurrence dates are not a complete pre-generated backup of all future instances.
- Five navigation tabs: Home, Plan, Calendar, Stats, Account; account version label and
  one-time 1.2 What's New slides. Version is `1.2.0+8`.

## Validation performed here

- 69 Dart logic/repository tests passed, including real PlanningStore operations with
  an in-memory preferences adapter. The same test assertions are in the Flutter tests.
- Static Dart analysis of app and tests against the repository's locked dependency
  sources and Flutter framework: **zero errors and zero warnings**. Two informational
  findings remain: the existing `Mfa_screen.dart` filename and deprecated `onReorder`.
- Formatting and `git diff --check` passed.
- Full Flutter tool execution was blocked by automatic approval review because it
  attempted a cloud instance-metadata request in this environment. That command was
  not retried. No Flutter build, widget execution, iOS archive or device test was
  completed here. The native adapters and UI still require the following checks.

## Run on your Mac before pushing/building

In the project directory:

```bash
flutter pub get
flutter analyze
flutter test
```

The old unrelated counter smoke test has been replaced by two relevant What's New
widget tests. There are 69 core assertions/tests plus those two widget tests.
If an error appears, send its complete output before building an IPA.

## iPhone/TestFlight checks before release

1. Upgrade an existing 1.1 installation without uninstalling it. Check old tasks,
   goals and completed days, sign out/sign back in, and verify account separation.
2. Complete a daily recurring task and one of its subtasks. Check its original date,
   then another date: that date's occurrence and steps should begin unchecked.
   Test actual midnight with Home open, background/resume, and a cold launch. Do not
   change the production phone's clock to simulate this; use a test device/simulator.
3. Plan normal tasks in advance; confirm rollover keeps those tasks. Carry over an
   unfinished normal task and confirm no recurring duplicates appear.
4. Change a task status and use its undo icon. Delete a normal task, dismiss the
   snackbar, close/reopen the app, and restore it from Recently Deleted. Check the
   original date, details and checklist. Test permanent removal separately.
5. Delete a recurring series beginning on a future date. Check that earlier dates are
   still scheduled and later ones stop. Restore it and check reminders again.
6. Add monthly, yearly, custom-interval and specific-weekday tasks, with/without end
   dates. Verify future dates and reminder times. Try a 24-hour device time format.
7. Add a duration and overlapping block. Check Planner/Calendar, edit task times,
   verify the resulting end time, and check small-screen/text-size layouts.
8. Start/pause/resume/reset a short focus session. Background and terminate/reopen the
   app. Verify remaining time, completion count and the completion alert. Sign-out
   cancels scheduled alerts but preserves account-local data.
9. Complete linked tasks for weekly and long-term goals. Reset a goal; verify progress
   starts at zero while tasks/statistics remain. A new week should start a new weekly
   period. Rechecking a task already in a reset baseline does not count it again.
10. Export CSV and JSON, save through Files on iPhone/iPad, and open the files to check
    their contents. Test the iPad share sheet and the once-only 1.2 introduction.

After the checks pass, commit/push from your coding laptop. Pull on the build Mac
while preserving its local iOS setup, then build `flutter build ipa`. Test
**1.2.0 (8)** in TestFlight before App Store submission. If build 8 has already been
used in your account, choose a higher unused build number in pubspec.yaml.

## Limits to understand

The fix prevents new date/status leakage. It cannot reliably distinguish an already
incorrect completion stamped as today's date by an older build from a genuine
completion; manually correct those existing checkmarks. Do not uninstall to test
migration—uninstalling clears device-local preferences.

Local saves are the primary copy. Cloud writes are attempted through the existing
Firestore structure; this is not a new conflict-resolving multi-device sync system.
Keep a device copy/export when testing offline or reinstalls.

Recurring reminders retain the bounded seven-occurrence queue, refilled when Home
opens/resumes. iOS has a pending-notification limit; many high-priority series can
crowd the queue. A daily series can run out of queued reminders after about a week
without reopening Home. Validate reminders with your expected task volume.

No Firebase rules, signing files, project platforms, or dependencies were added.
No code was pushed, no build was uploaded and no release was published.
