TrakOn 1.2.1 build 16 — Focus & Break update
Based on GitHub build 15 (34e0143). Also accepts the earlier cleanup-only timer file.
This package replaces the cleanup-only build 16 download with the full update.

INSTALL ON YOUR OLD MAC
Extract the ZIP into Downloads. From Terminal in your my_new_app directory:
python3 ~/Downloads/TrakOn_1.2.1_Focus_Break_Build16/apply_focus_update.py .
The installer backs up the existing files outside the project and copies only
10 named files. It does not delete files, replace lib folders, alter dependencies,
or overwrite your tracked installer files. Unexpected edits stop the installation
before it changes anything. Do not force past that warning; request a merge.
The two iOS files are essential: AppDelegate.swift and Info.plist. This update does
not replace Podfile, signing, Xcode project files, pubspec.lock or Firebase config.
The version bump to 1.2.1+16 is included.

THEN
flutter analyze
flutter test
Send the results before committing/pushing. Use the normal two-Mac workflow:
push the checked source on the old Mac; stash local iOS setup on the new Mac,
pull, apply the stash, run checks, then flutter build ipa.
Xcode 26 or newer is needed to compile AlarmKit support. With an older SDK,
the conditional build uses notification fallback instead. Minimum iOS stays 15.

WHAT IS INCLUDED
- A visible Focus & Break card on Home with labeled Focus/Break start controls.
- The current session's name, countdown and Pause/Resume controls on Home.
- One shared per-account timer, so Home and the full timer cannot start competing
  countdowns. Returning from the background uses the saved absolute deadline.
- Editable session names; separate remembered Focus/Break names and durations.
- Completion controls: Stop and Start Break / Start Focus.
- Two distinct generated PCM WAV sounds: an ascending focus melody and a
  different break melody. Files are installed in the app's Library/Sounds folder;
  no external audio dependency or Xcode resource-list edit is needed.
- On iOS 26+ with alarm authorization: a fixed-deadline AlarmKit system alarm.
  iOS provides the ringing alert and Stop control, including on the Lock Screen.
  Pause cancels it; Resume schedules the remaining time. Reset, switching phases,
  Stop, master notification cancellation and sign-out use the cancellation path.
- Otherwise: a custom local-notification sound in the background, subject to
  notification permission, silent mode, Focus settings and device volume. While
  the app remains foregrounded, the native player repeats the completion sound
  until Stop, reset or switching phase. It stops when the app backgrounds; this
  does not fake background audio to keep the app alive.
- The existing reminder queue fix is retained. Native AlarmKit alarms do not
  consume the ordinary local-notification queue. The diagnostic test button and
  queue-count text remain removed.

IMPORTANT BEHAVIOR
Start a session and allow the new Alarms permission prompt on a supported iPhone.
The app displays whether it scheduled a system alarm or is using the notification
fallback. The in-app master switch and Focus timer completion setting still apply.
AlarmKit permission is separate from notification permission. If denied, enable
Alarms for TrakOn in iPhone Settings to use ringing system alarms.
Only the ending alert uses AlarmKit. This version does not add an ongoing Lock
Screen countdown Live Activity; the countdown remains on Home and in the app.
System alarm sound and volume are ultimately controlled by iOS.

VALIDATION HERE
- 99 existing standalone Dart tests passed against this source tree.
- 10 new controller regressions passed through VM-safe Flutter/OS adapters; these
  check the real controller action/persistence logic, not native delivery or widgets.
- Static analysis of changed Dart files and the added Flutter test file has no
  errors/warnings; the existing Home onReorder informational deprecation remains.
- Plist, permission description, diagnostic removal and patch checks passed.
- Installer verified on baseline build 15 and the earlier cleanup-only timer file;
  unexpected-edits protection verified.
- Native Swift cannot be compiled in this Linux workspace. Xcode compilation,
  Flutter runtime/widget tests and physical-device sound delivery are still required.
  Do not submit this build until those checks pass on your Macs/iPhone.

IPHONE ACCEPTANCE CHECKS (TESTFLIGHT BUILD 16)
1. Confirm the Focus & Break card is easy to find on Home.
2. Rename Focus, set one minute, allow Alarms, start, leave the app and lock the
   iPhone. Confirm it rings, shows the session name, and Stop dismisses it.
3. Repeat with a one-minute Break; confirm a different sound.
4. Pause a timer, wait past the original end time (it must not ring), then Resume;
   confirm only the remaining time is used and the Home countdown agrees.
5. Reset a timer, wait past its former end time, and confirm it does not ring.
6. Rename a running session; confirm the deadline stays the same and the alarm
   uses its new name. Start Break after Focus completion and the reverse.
7. Finish a session with the app open; verify the completion card and Stop button.
8. Deny Alarms permission to check the clearly labeled notification fallback with
   ringer on and Focus off. It is not a ringing background alarm on older iOS.
9. Sign out while a timer is active and confirm no old-account alarm sounds.
10. Recheck a normal task reminder and mood reminder after installing this build.

APPLE REFERENCES
https://developer.apple.com/documentation/alarmkit/scheduling-an-alarm-with-alarmkit
https://developer.apple.com/videos/play/wwdc2025/230/
https://developer.apple.com/documentation/activitykit/alertconfiguration/alertsound/named(_:)
https://developer.apple.com/documentation/bundleresources/information-property-list/nsalarmkitusagedescription
