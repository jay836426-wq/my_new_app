import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive.dart';
import 'package:TrakOn/utils/planning_rules.dart';
import 'package:TrakOn/services/task_export.dart';

void main() {
  test('Optional notifications choose future daily and Saturday times', () {
    expect(
      nextCheckInTime(DateTime(2026, 11, 1, 10), 9, 0),
      DateTime(2026, 11, 2, 9),
    );
    expect(
      nextCheckInTime(DateTime(2026, 11, 7, 19), 18, 0, saturday: true),
      DateTime(2026, 11, 14, 18),
    );
    expect(
      nextCheckInTime(DateTime(2026, 11, 7, 17), 18, 0, saturday: true),
      DateTime(2026, 11, 7, 18),
    );
  });
  test('DST fall-back week has seven unique dates Sunday through Saturday', () {
    final start = sundayOf(DateTime(2026, 11, 4));
    final days = List.generate(7, (i) => calendarDay(start, i));
    expect(days.map(dayKey).toSet().length, 7);
    expect(days.first.weekday, DateTime.sunday);
    expect(days.last.weekday, DateTime.saturday);
    expect(dayKey(days.last), '2026-11-7');
  });
  test('DST spring-forward and year boundary calendar navigation', () {
    for (final selected in [DateTime(2026, 3, 11), DateTime(2027, 1, 1)]) {
      final start = sundayOf(selected);
      expect(
        List.generate(7, (i) => dayKey(calendarDay(start, i))).toSet().length,
        7,
      );
      expect(calendarDay(start, 6).weekday, 6);
      expect(dayKey(calendarDay(calendarDay(start, 7), -7)), dayKey(start));
    }
  });
  test('Week month and leap-year export ranges', () {
    final (w, e) = exportRange(DateTime(2026, 11, 4), 'Week');
    expect(dayKey(w), '2026-11-1');
    expect(dayKey(e), '2026-11-8');
    final (m, n) = exportRange(DateTime(2028, 2, 10), 'Month');
    expect(civilDays(m, n), 29);
    final (y, z) = exportRange(DateTime(2028, 4, 1), 'Year');
    expect(civilDays(y, z), 366);
  });
  test('Workbook uses XLSX and stores formula-like input as text', () {
    final bytes = taskWorkbook({
      '2026-11-1': [
        {'title': '=SUM(A1,A2) & <check> 😀'},
      ],
    });
    final zip = ZipDecoder().decodeBytes(bytes);
    expect(zip.findFile('xl/workbook.xml'), isNotNull);
    final sheet = String.fromCharCodes(
      zip.findFile('xl/worksheets/sheet1.xml')!.content,
    );
    expect(sheet, contains('&amp; &lt;check&gt;'));
    expect(sheet, contains('t="inlineStr"'));
    expect(sheet, isNot(contains('<f>')));
  });
  test('PDF renders empty and multi-page reports', () async {
    final output = Directory.systemTemp.createTempSync('trakon-export-test-');
    addTearDown(() => output.deleteSync(recursive: true));
    final font = ByteData.sublistView(
      File('assets/fonts/DejaVuSans.ttf').readAsBytesSync(),
    );
    for (final count in [0, 100]) {
      final bytes = await taskPdf(
        {
          '2026-11-1': List.generate(
            count,
            (i) => {
              'title': 'Study task $i',
              'startTime': '9:00 AM',
              'durationMinutes': 30,
            },
          ),
        },
        font,
        'TrakOn test',
      );
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
      File('${output.path}/sample_$count.pdf').writeAsBytesSync(bytes);
    }
    File('${output.path}/sample_tasks.xlsx').writeAsBytesSync(
      taskWorkbook({
        '2026-11-1': [
          {'title': 'Read & review 😀', 'status': 'Complete'},
        ],
      }),
    );
  });
}
