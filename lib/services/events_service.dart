import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shamsi_date/shamsi_date.dart';

class CalendarEvent {
  final String? id; // فقط برای مناسبت‌های خصوصی پر می‌شود (برای حذف لازم است)
  final String title;
  final String description;
  final bool isPublic;
  final int month; // ماه شمسی
  final int day; // روز شمسی
  final int? year; // فقط برای مناسبت‌های خصوصی (مناسبت‌های عمومی هرساله تکرار می‌شوند)

  CalendarEvent({
    this.id,
    required this.title,
    this.description = '',
    required this.isPublic,
    required this.month,
    required this.day,
    this.year,
  });
}

/// این سرویس مناسبت‌های «عمومی» (از فایل assets/events.json، تکرارشونده هر
/// سال بر اساس روز و ماه شمسی) را با مناسبت‌های «خصوصی» که کاربر اضافه کرده
/// (ذخیره‌شده در SharedPreferences) ترکیب می‌کند. حذف یک مناسبت عمومی به
/// معنای «پنهان کردن» آن است (چون از فایل ضمیمه حذف واقعی ممکن نیست)، اما
/// مناسبت‌های خصوصی واقعاً حذف می‌شوند.
class EventsService {
  static List<Map<String, dynamic>>? _publicEventsCache;

  static const _privateEventsKey = 'private_events_v2';
  static const _hiddenPublicKey = 'hidden_public_events_v1';

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

  String _publicKey(String date, String title) => '$date|$title';

  Future<Set<String>> _getHiddenKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_hiddenPublicKey);
    return raw?.toSet() ?? {};
  }

  /// مناسبت‌های یک روز مشخص شمسی (برای کارت «امروز» در صفحه اصلی و پاپ‌آپ روز)
  Future<List<CalendarEvent>> getEventsForJalali(Jalali date) async {
    await _ensureLoaded();
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    final key = '$mm-$dd';
    final hidden = await _getHiddenKeys();

    final publicEvents = (_publicEventsCache ?? [])
        .where((e) => e['date'] == key && !hidden.contains(_publicKey(key, e['title'] as String)))
        .map((e) => CalendarEvent(
              title: e['title'] as String,
              description: (e['description'] as String?) ?? '',
              isPublic: true,
              month: date.month,
              day: date.day,
            ))
        .toList();

    final privateEvents = await _getAllPrivateEvents();
    final todayPrivate = privateEvents
        .where((e) => e.month == date.month && e.day == date.day && e.year == date.year)
        .toList();

    return [...publicEvents, ...todayPrivate];
  }

  /// همه مناسبت‌های عمومی (پنهان‌نشده) به‌همراه همه مناسبت‌های خصوصی، برای
  /// نمایش در صفحه «مناسبت‌ها».
  Future<List<CalendarEvent>> getAllEvents() async {
    await _ensureLoaded();
    final hidden = await _getHiddenKeys();

    final publicEvents = (_publicEventsCache ?? [])
        .where((e) => !hidden.contains(_publicKey(e['date'] as String, e['title'] as String)))
        .map((e) {
      final parts = (e['date'] as String).split('-');
      return CalendarEvent(
        title: e['title'] as String,
        description: (e['description'] as String?) ?? '',
        isPublic: true,
        month: int.parse(parts[0]),
        day: int.parse(parts[1]),
      );
    }).toList();

    final privateEvents = await _getAllPrivateEvents();

    final all = [...publicEvents, ...privateEvents];
    all.sort((a, b) => a.month != b.month ? a.month.compareTo(b.month) : a.day.compareTo(b.day));
    return all;
  }

  Future<List<CalendarEvent>> _getAllPrivateEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_privateEventsKey);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => CalendarEvent(
                id: e['id'] as String,
                title: e['title'] as String,
                isPublic: false,
                month: e['month'] as int,
                day: e['day'] as int,
                year: e['year'] as int,
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addPrivateEvent(Jalali date, String title) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_privateEventsKey);
    final list = raw != null ? (jsonDecode(raw) as List) : [];
    list.add({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'title': title,
      'year': date.year,
      'month': date.month,
      'day': date.day,
    });
    await prefs.setString(_privateEventsKey, jsonEncode(list));
  }

  Future<void> removePrivateEvent(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_privateEventsKey);
    if (raw == null) return;
    final list = (jsonDecode(raw) as List).where((e) => e['id'] != id).toList();
    await prefs.setString(_privateEventsKey, jsonEncode(list));
  }

  /// «حذف» یک مناسبت عمومی؛ چون از فایل ضمیمه واقعاً حذف نمی‌شود، در فهرست
  /// مناسبت‌های پنهان‌شده ذخیره می‌شود و دیگر در هیچ‌جای برنامه نمایش داده
  /// نمی‌شود.
  Future<void> hidePublicEvent(int month, int day, String title) async {
    final mm = month.toString().padLeft(2, '0');
    final dd = day.toString().padLeft(2, '0');
    final key = _publicKey('$mm-$dd', title);
    final prefs = await SharedPreferences.getInstance();
    final hidden = await _getHiddenKeys();
    hidden.add(key);
    await prefs.setStringList(_hiddenPublicKey, hidden.toList());
  }
}
