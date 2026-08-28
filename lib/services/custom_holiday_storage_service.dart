import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// نوع مناسبت سفارشی: شمسی یا قمری
enum CustomHolidayType { solar, lunar }

class CustomHoliday {
  final String id;
  final CustomHolidayType type;
  final int month;
  final int day;
  final String title;

  const CustomHoliday({
    required this.id,
    required this.type,
    required this.month,
    required this.day,
    required this.title,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type == CustomHolidayType.solar ? 'solar' : 'lunar',
        'month': month,
        'day': day,
        'title': title,
      };

  factory CustomHoliday.fromJson(Map<String, dynamic> json) => CustomHoliday(
        id: json['id'] as String,
        type: (json['type'] as String) == 'solar' ? CustomHolidayType.solar : CustomHolidayType.lunar,
        month: json['month'] as int,
        day: json['day'] as int,
        title: json['title'] as String,
      );
}

/// مدیریت مناسبت‌های سفارشی که کاربر (شمسی یا قمری) به تقویم اضافه می‌کند؛
/// این‌ها علاوه بر فهرست ثابت تعطیلات (iranian_holidays.dart) در نظر گرفته می‌شوند
/// و راهی برای بروزرسانی/افزودن مناسبت‌ها بدون نیاز به آپدیت کامل برنامه هستند.
class CustomHolidayStorageService {
  static const _key = 'custom_holidays_v1';

  Future<List<CustomHoliday>> loadCustomHolidays() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => CustomHoliday.fromJson(e)).toList();
  }

  Future<void> _saveAll(List<CustomHoliday> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  Future<void> addCustomHoliday(CustomHoliday holiday) async {
    final items = await loadCustomHolidays();
    items.add(holiday);
    await _saveAll(items);
  }

  Future<void> removeCustomHoliday(String id) async {
    final items = await loadCustomHolidays();
    items.removeWhere((e) => e.id == id);
    await _saveAll(items);
  }
}
