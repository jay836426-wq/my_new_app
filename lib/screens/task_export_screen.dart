import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../services/account_planning_store.dart';
import '../services/task_export.dart';
import '../utils/planning_rules.dart';

class TaskExportScreen extends StatefulWidget {
  const TaskExportScreen({super.key, required this.selected});
  final DateTime selected;
  @override
  State<TaskExportScreen> createState() => _TaskExportScreenState();
}

class _TaskExportScreenState extends State<TaskExportScreen> {
  String _period = 'Week';
  String _format = 'pdf';
  bool _busy = false;
  late DateTime _date;
  @override
  void initState() {
    super.initState();
    _date = widget.selected;
  }

  Future<void> export() async {
    setState(() => _busy = true);
    try {
      final store = await AccountPlanningStore.current();
      final saved = await store.allSavedDays();
      final templates = await store.listState('recurringTasks');
      final (start, end) = exportRange(_date, _period);
      final days = <String, List<TaskData>>{};
      for (var d = start; d.isBefore(end); d = calendarDay(d, 1)) {
        final key = dayKey(d);
        final tasks = materializeDay(
          saved: saved[key] ?? [],
          templates: templates,
          date: key,
        );
        if (tasks.isNotEmpty) days[key] = tasks;
      }
      if (days.values.fold<int>(0, (n, t) => n + t.length) > 5000) {
        throw StateError(
          'Choose a smaller period (maximum 5,000 task occurrences).',
        );
      }
      final title =
          'TrakOn $_period: ${dayKey(start)} to ${dayKey(calendarDay(end, -1))}';
      Uint8List bytes;
      String mime;
      if (_format == 'pdf') {
        bytes = await taskPdf(
          days,
          await rootBundle.load('assets/fonts/DejaVuSans.ttf'),
          title,
        );
        mime = 'application/pdf';
      } else if (_format == 'xlsx') {
        bytes = taskWorkbook(days);
        mime =
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      } else {
        final text = _format == 'csv'
            ? exportTasksCsv(days)
            : const JsonEncoder.withIndent('  ').convert({
                'period': _period,
                'start': dayKey(start),
                'endInclusive': dayKey(calendarDay(end, -1)),
                'days': days,
              });
        bytes = Uint8List.fromList(utf8.encode(text));
        mime = _format == 'csv' ? 'text/csv' : 'application/json';
      }
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox;
      await SharePlus.instance.share(
        ShareParams(
          title: title,
          files: [XFile.fromData(bytes, mimeType: mime)],
          fileNameOverrides: ['TrakOn_${_period}_${dayKey(start)}.$_format'],
          sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is StateError ? e.message : 'Could not export. Please retry.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (start, end) = exportRange(_date, _period);
    return Scaffold(
      appBar: AppBar(title: const Text('Export tasks')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Choose a period and a file format.',
            style: TextStyle(fontSize: 20),
          ),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            initialValue: _period,
            decoration: const InputDecoration(labelText: 'Period'),
            items: [
              for (final p in ['Week', 'Month', 'Year'])
                DropdownMenuItem(value: p, child: Text(p)),
            ],
            onChanged: _busy ? null : (v) => setState(() => _period = v!),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${dayKey(start)} – ${dayKey(calendarDay(end, -1))}'),
            subtitle: const Text('Tap to choose a date within the period'),
            trailing: const Icon(Icons.event),
            onTap: _busy
                ? null
                : () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) setState(() => _date = d);
                  },
          ),
          DropdownButtonFormField<String>(
            initialValue: _format,
            decoration: const InputDecoration(labelText: 'Format'),
            items: const [
              DropdownMenuItem(value: 'pdf', child: Text('PDF document')),
              DropdownMenuItem(
                value: 'xlsx',
                child: Text('Excel workbook (.xlsx)'),
              ),
              DropdownMenuItem(value: 'csv', child: Text('CSV')),
              DropdownMenuItem(value: 'json', child: Text('JSON')),
            ],
            onChanged: _busy ? null : (v) => setState(() => _format = v!),
          ),
          const SizedBox(height: 24),
          const Text(
            'Includes saved tasks and scheduled recurring occurrences for this period. Exporting does not change your tasks. Choose Save to Files in the share sheet to keep a copy.',
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy ? null : export,
            icon: const Icon(Icons.ios_share),
            label: Text(_busy ? 'Creating file…' : 'Create and share'),
          ),
        ],
      ),
    );
  }
}
