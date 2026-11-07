import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

Future<TimeOfDay?> chooseReminderTime(
  BuildContext context,
  TimeOfDay initial,
) async {
  if (Theme.of(context).platform != TargetPlatform.iOS) {
    return showTimePicker(context: context, initialTime: initial);
  }
  var pending = initial;
  return showCupertinoModalPopup<TimeOfDay>(
    context: context,
    builder: (sheetContext) => CupertinoTheme(
      data: CupertinoThemeData(brightness: Theme.of(context).brightness),
      child: Container(
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text('Cancel'),
                  ),
                  CupertinoButton(
                    onPressed: () => Navigator.pop(sheetContext, pending),
                    child: const Text('Done'),
                  ),
                ],
              ),
              SizedBox(
                height: 216,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: MediaQuery.of(context).alwaysUse24HourFormat,
                  initialDateTime: DateTime(
                    2026,
                    1,
                    1,
                    initial.hour,
                    initial.minute,
                  ),
                  onDateTimeChanged: (d) =>
                      pending = TimeOfDay(hour: d.hour, minute: d.minute),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
