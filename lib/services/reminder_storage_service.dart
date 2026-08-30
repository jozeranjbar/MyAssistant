import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reminder.dart';

class ReminderStorageService {
  static const _key = 'reminders_v2';

  Future<List<Reminder>> loadReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Reminder.fromJson(e)).toList();
  }

  Future<List<Reminder>> loadByCategory(ReminderCategory category) async {
    final all = await loadReminders();
    return all.where((r) => r.category == category).toList()
      ..sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
  }

  Future<void> saveReminders(List<Reminder> reminders) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(reminders.map((e) => e.toJson()).toList()));
  }

  Future<void> addReminder(Reminder reminder) async {
    final reminders = await loadReminders();
    reminders.add(reminder);
    await saveReminders(reminders);
  }

  Future<void> removeReminder(int id) async {
    final reminders = await loadReminders();
    reminders.removeWhere((r) => r.id == id);
    await saveReminders(reminders);
  }

  Future<void> updateReminder(Reminder reminder) async {
    final reminders = await loadReminders();
    final index = reminders.indexWhere((r) => r.id == reminder.id);
    if (index != -1) {
      reminders[index] = reminder;
      await saveReminders(reminders);
    }
  }
}
