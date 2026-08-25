import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/reminder.dart';
import '../services/reminder_storage_service.dart';
import '../services/notification_service.dart';

class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key});

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  final _storage = ReminderStorageService();
  final _notifications = NotificationService();
  List<Reminder> _reminders = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final reminders = await _storage.loadReminders();
    setState(() => _reminders = reminders);
  }

  Future<void> _addOrEditReminder({Reminder? existing}) async {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final noteController = TextEditingController(text: existing?.note ?? '');
    DateTime pickedDateTime = existing?.dateTime ?? DateTime.now().add(const Duration(minutes: 5));
    bool repeatDaily = existing?.repeatDaily ?? false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(existing == null ? 'یادآوری جدید' : 'ویرایش یادآوری',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'عنوان', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(labelText: 'یادداشت (اختیاری)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('زمان: ${DateFormat('yyyy/MM/dd HH:mm').format(pickedDateTime)}'),
                    trailing: const Icon(Icons.edit_calendar),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: pickedDateTime,
                        firstDate: DateTime.now().subtract(const Duration(days: 1)),
                        lastDate: DateTime.now().add(const Duration(days: 3650)),
                      );
                      if (date == null) return;
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(pickedDateTime),
                      );
                      if (time == null) return;
                      setModalState(() {
                        pickedDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                      });
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('تکرار روزانه'),
                    value: repeatDaily,
                    onChanged: (v) => setModalState(() => repeatDaily = v),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () async {
                      if (titleController.text.trim().isEmpty) return;
                      final reminder = Reminder(
                        id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.remainder(1000000000),
                        title: titleController.text.trim(),
                        note: noteController.text.trim(),
                        dateTime: pickedDateTime,
                        repeatDaily: repeatDaily,
                        isActive: true,
                      );
                      if (existing == null) {
                        await _storage.addReminder(reminder);
                      } else {
                        await _storage.updateReminder(reminder);
                      }
                      await _notifications.scheduleReminder(reminder);
                      if (context.mounted) Navigator.pop(context);
                      await _load();
                    },
                    child: const Text('ذخیره'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteReminder(Reminder r) async {
    await _storage.removeReminder(r.id);
    await _notifications.cancelReminder(r.id);
    await _load();
  }

  Future<void> _toggleActive(Reminder r, bool value) async {
    r.isActive = value;
    await _storage.updateReminder(r);
    if (value) {
      await _notifications.scheduleReminder(r);
    } else {
      await _notifications.cancelReminder(r.id);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('یادآوری')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditReminder(),
        child: const Icon(Icons.add_alarm),
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0).abs() > 200) {
            Navigator.of(context).maybePop();
          }
        },
        child: _reminders.isEmpty
          ? const Center(child: Text('یادآوری ثبت نشده است.'))
          : ListView.builder(
              itemCount: _reminders.length,
              itemBuilder: (context, index) {
                final r = _reminders[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text(r.title),
                    subtitle: Text(
                        '${DateFormat('yyyy/MM/dd HH:mm').format(r.dateTime)}${r.repeatDaily ? ' • تکرار روزانه' : ''}'),
                    onTap: () => _addOrEditReminder(existing: r),
                    leading: Switch(value: r.isActive, onChanged: (v) => _toggleActive(r, v)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteReminder(r),
                    ),
                  ),
                );
              },
            ),
      ),
    );
  }
}
