import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reminder.dart';

/// ذخیره‌سازی محلی یادآوری‌ها (هم داروها و هم یادآوری‌های روزمره) با
/// SharedPreferences. هر دو دسته در یک لیست واحد نگه‌داری می‌شوند و فیلد
/// `category` روی هر آیتم مشخص می‌کند که به کدام تب تعلق دارد؛ این دقیقاً
/// همان چیزی است که بقیه‌ی برنامه (home_screen، main.dart) انتظارش را دارند.
class ReminderStorageService {
  static const _key = 'reminders_v1';

  Future<List<Reminder>> loadReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => Reminder.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveAll(List<Reminder> reminders) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(reminders.map((r) => r.toJson()).toList());
    await prefs.setString(_key, raw);
  }

  Future<void> addReminder(Reminder reminder) async {
    final reminders = await loadReminders();
    reminders.add(reminder);
    await _saveAll(reminders);
  }

  Future<void> updateReminder(Reminder reminder) async {
    final reminders = await loadReminders();
    final index = reminders.indexWhere((r) => r.id == reminder.id);
    if (index == -1) {
      reminders.add(reminder);
    } else {
      reminders[index] = reminder;
    }
    await _saveAll(reminders);
  }

  Future<void> removeReminder(int id) async {
    final reminders = await loadReminders();
    reminders.removeWhere((r) => r.id == id);
    await _saveAll(reminders);
  }
}
