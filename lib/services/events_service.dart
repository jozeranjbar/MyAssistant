import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shamsi_date/shamsi_date.dart';

class CalendarEvent {
  final String title;
  final String description;
  final bool isPublic; // true = مناسبت عمومی (از فایل ضمیمه‌شده) / false = خصوصی (کاربر اضافه کرده)

  CalendarEvent({required this.title, this.description = '', required this.isPublic});
}

/// این سرویس مناسبت‌های «عمومی» را از فایل assets/events.json (که هر سال بر
/// اساس روز و ماه شمسی تکرار می‌شود) و مناسبت‌های «خصوصی» را که کاربر از
/// صفحه تقویم اضافه کرده (ذخیره‌شده در SharedPreferences) با هم ترکیب می‌کند.
class EventsService {
  static List<Map<String, dynamic>>? _publicEventsCache;

  static const _privateEventsKey = 'calendar_events_v1';

  Future<void> _ensureLoaded() async {
    if (_publicEventsCache != null) return;
    try {
      final raw = await rootBundle.loadString('assets/events.json');
      final data = jsonDecode(raw) as List;
      _publicEventsCache = data.cast<Map<String, dynamic>>();
    } catch (_) {
      _publicEventsCache = [];
    }
  }

  Future<List<CalendarEvent>> getEventsForJalali(Jalali date) async {
    await _ensureLoaded();

    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    final key = '$mm-$dd';

    final publicEvents = (_publicEventsCache ?? [])
        .where((e) => e['date'] == key)
        .map((e) => CalendarEvent(
              title: e['title'] as String,
              description: (e['description'] as String?) ?? '',
              isPublic: true,
            ))
        .toList();

    final privateEvents = await _getPrivateEvents(date);

    return [...publicEvents, ...privateEvents];
  }

  Future<List<CalendarEvent>> _getPrivateEvents(Jalali date) async {
    try {
      final gDate = date.toDateTime();
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_privateEventsKey);
      if (raw == null) return [];
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final dateKey = '${gDate.year}-${gDate.month}-${gDate.day}';
      final list = map[dateKey];
      if (list == null) return [];
      return (list as List)
          .map((t) => CalendarEvent(title: t.toString(), isPublic: false))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
