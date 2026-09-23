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

  /// فقط یادآوری‌های یک دسته (دارو یا روزمره)
  Future<List<Reminder>> loadByCategory(ReminderCategory category) async {
    final all = await loadReminders();
    return all.where((r) => r.category == category).toList();
  }

  /// پشتیبان‌گیری کامل به‌صورت متن JSON (برای ذخیره/اشتراک‌گذاری توسط کاربر)
  Future<String> exportBackupJson() async {
    final reminders = await loadReminders();
    final backup = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'reminders': reminders.map((r) => r.toJson()).toList(),
    };
    return jsonEncode(backup);
  }

  /// بازیابی از متن JSON پشتیبان.
  ///
  /// قبلاً این تابع همیشه کل لیستِ فعلیِ یادآوری‌ها را با محتوای فایلِ
  /// پشتیبان جایگزین می‌کرد؛ یعنی اگر کاربر ۲۰ یادآوری داشت و یک فایلِ
  /// پشتیبانِ قدیمی‌تر با ۵ یادآوری وارد می‌کرد، آن ۲۰ مورد برای همیشه از
  /// بین می‌رفت. حالا به‌صورت پیش‌فرض [BackupImportMode.merge] استفاده
  /// می‌شود: یادآوری‌های فایلِ پشتیبان با لیستِ فعلی ادغام می‌شوند؛ اگر
  /// شناسه‌ای در هر دو طرف تکراری باشد، نسخه‌ی داخلِ فایلِ پشتیبان جایگزینِ
  /// همان یک مورد می‌شود (به‌عنوانِ بروزرسانی)، نه اینکه کل لیست پاک شود.
  /// در صورتِ نیاز به رفتارِ قبلی (جایگزینیِ کامل)، mode را برابر
  /// [BackupImportMode.replace] قرار دهید.
  Future<bool> importBackupJson(
    String jsonStr, {
    BackupImportMode mode = BackupImportMode.merge,
  }) async {
    try {
      final data = jsonDecode(jsonStr);
      if (data is! Map || data['reminders'] is! List) return false;
      final imported = <Reminder>[];
      for (final e in data['reminders'] as List) {
        try {
          imported.add(Reminder.fromJson(e as Map<String, dynamic>));
        } catch (_) {
          // یک آیتمِ خرابِ داخلِ فایلِ پشتیبان نباید کل بازیابی را متوقف کند
        }
      }

      if (mode == BackupImportMode.replace) {
        await _saveAll(imported);
        return true;
      }

      final current = await loadReminders();
      final merged = [...current];
      for (final r in imported) {
        final index = merged.indexWhere((e) => e.id == r.id);
        if (index == -1) {
          merged.add(r);
        } else {
          // شناسه‌ی تکراری: نسخه‌ی فایلِ پشتیبان به‌عنوانِ بروزرسانی در نظر
          // گرفته می‌شود، نه یک موردِ کاملاً جدا.
          merged[index] = r;
        }
      }
      await _saveAll(merged);
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// نحوه‌ی برخورد با یادآوری‌های فعلی هنگامِ وارد کردنِ یک فایلِ پشتیبان.
enum BackupImportMode {
  /// یادآوری‌های فایلِ پشتیبان به لیستِ فعلی اضافه/ادغام می‌شوند (پیش‌فرضِ امن).
  merge,

  /// لیستِ فعلی کاملاً پاک و با محتوای فایلِ پشتیبان جایگزین می‌شود.
  replace,
}
