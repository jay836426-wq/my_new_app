import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../utils/planning_rules.dart';

List<List<String>> exportRows(Map<String, List<TaskData>> days) {
  final rows = <List<String>>[
    ['Date', 'Task', 'Status', 'Start', 'End', 'Minutes', 'Repeat', 'Subtasks'],
  ];
  final dates = days.keys.toList()
    ..sort((a, b) => parseDay(a).compareTo(parseDay(b)));
  for (final date in dates) {
    for (final t in days[date]!) {
      rows.add([
        date,
        t['title']?.toString() ?? '',
        isTaskComplete(t)
            ? 'Complete'
            : t['status']?.toString() ?? 'Not Started',
        t['startTime']?.toString() ?? '',
        t['endTime']?.toString() ?? '',
        taskDuration(t)?.toString() ?? '',
        t['repeat']?.toString() ?? 'Never',
        taskSubtasks(t)
            .map(
              (s) => '${s['completed'] == true ? '[x]' : '[ ]'} ${s['title']}',
            )
            .join('\n'),
      ]);
    }
  }
  return rows;
}

String _xml(String s) => s
    .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
Uint8List taskWorkbook(Map<String, List<TaskData>> days) {
  final files = <String, String>{
    '[Content_Types].xml':
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>',
    '_rels/.rels':
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>',
    'xl/workbook.xml':
        '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Tasks" sheetId="1" r:id="rId1"/></sheets></workbook>',
    'xl/_rels/workbook.xml.rels':
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>',
  };
  final rows = exportRows(days);
  final sheet = StringBuffer(
    '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" state="frozen"/></sheetView></sheetViews><cols><col min="1" max="1" width="15" customWidth="1"/><col min="2" max="2" width="48" customWidth="1"/><col min="3" max="8" width="20" customWidth="1"/></cols><sheetData>',
  );
  for (var i = 0; i < rows.length; i++) {
    sheet.write('<row r="${i + 1}">');
    for (var j = 0; j < rows[i].length; j++) {
      final cell = '${String.fromCharCode(65 + j)}${i + 1}';
      sheet.write(
        '<c r="$cell" t="inlineStr"><is><t xml:space="preserve">${_xml(rows[i][j])}</t></is></c>',
      );
    }
    sheet.write('</row>');
  }
  sheet.write('</sheetData><autoFilter ref="A1:H${rows.length}"/></worksheet>');
  files['xl/worksheets/sheet1.xml'] = sheet.toString();
  final zip = Archive();
  for (final entry in files.entries) {
    final bytes = utf8.encode(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>${entry.value}',
    );
    zip.addFile(ArchiveFile(entry.key, bytes.length, bytes));
  }
  return Uint8List.fromList(ZipEncoder().encode(zip));
}

Future<Uint8List> taskPdf(
  Map<String, List<TaskData>> days,
  ByteData fontBytes,
  String title,
) async {
  final font = pw.Font.ttf(fontBytes);
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: font, bold: font),
  );
  String text(String value) => String.fromCharCodes(
    value.runes.where((r) => r <= 0xFFFF && r != 0xFE0F).take(260),
  );
  final rows = exportRows(days);
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      maxPages: 1000,
      footer: (c) => pw.Text(
        'TrakOn • Page ${c.pageNumber}',
        style: const pw.TextStyle(fontSize: 9),
      ),
      build: (_) => [
        pw.Header(level: 0, child: pw.Text(title)),
        pw.Paragraph(
          text:
              '${rows.length - 1} task occurrences. Selected period; weeks run Sunday–Saturday.',
        ),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
          ),
          cellStyle: const pw.TextStyle(fontSize: 8),
          headers: ['Date', 'Task', 'Status / Time'],
          columnWidths: {
            0: const pw.FixedColumnWidth(64),
            1: const pw.FlexColumnWidth(3),
            2: const pw.FlexColumnWidth(2),
          },
          data: rows
              .skip(1)
              .map(
                (r) => [
                  r[0],
                  text(r[1]),
                  text(
                    '${r[2]}\n${r[3]}${r[4].isEmpty ? '' : ' – ${r[4]}'}${r[5].isEmpty ? '' : '\n${r[5]} minutes'}',
                  ),
                ],
              )
              .toList(),
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          'PDF task names are limited to 260 characters; some emoji may be omitted. Excel, CSV and JSON retain full text.',
          style: const pw.TextStyle(fontSize: 8),
        ),
      ],
    ),
  );
  return doc.save();
}
