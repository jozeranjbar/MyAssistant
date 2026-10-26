import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/persian_numbers.dart';

/// یک تعطیلیِ رسمیِ متغیر (مثل عید فطر) با تاریخِ «شمسی»
class OfficialHoliday {
  final int month; // ماه شمسی ۱ تا ۱۲
  final int day;
  final String title;
  const OfficialHoliday(this.month, this.day, this.title);
}

enum CalendarUpdateStatus { updated, alreadyUpToDate, noData, network, server, badFormat }

class CalendarUpdateResult {
  final CalendarUpdateStatus status;
  final List<int> years;
  const CalendarUpdateResult(this.status, [this.years = const []]);

  String get message {
    switch (status) {
      case CalendarUpdateStatus.updated:
        return 'تقویم بروزرسانی شد (${years.map((y) => toPersianDigits(y.toString())).join('، ')})';
      case CalendarUpdateStatus.alreadyUpToDate:
        return 'تقویم از قبل به‌روز است';
      case CalendarUpdateStatus.noData:
        return 'هنوز تعطیلات رسمی جدیدی منتشر نشده است؛ چند روز دیگر دوباره امتحان کنید';
      case CalendarUpdateStatus.network:
        return 'اتصال اینترنت برقرار نیست؛ بعداً دوباره امتحان کنید';
      case CalendarUpdateStatus.server:
        return 'فایل بروزرسانی روی سرور پیدا نشد';
      case CalendarUpdateStatus.badFormat:
        return 'فایل بروزرسانی معتبر نیست';
    }
  }
}

/// بروزرسانیِ تعطیلاتِ رسمیِ متغیر (قمری) از یک فایل JSON در گیت‌هاب.
///
/// برنامه خودش نمی‌تواند تاریخِ رسمیِ تعطیلاتِ قمریِ هر سال را بداند (محاسبه‌ی
/// نجومی ممکن است یک روز اختلاف داشته باشد). پس هر سال، پس از اعلامِ رسمیِ
/// تقویم، فایل `calendar_update/holidays.json` در ریپو تکمیل می‌شود و برنامه
/// آن را دانلود و برای همان سال، جای محاسبه‌ی نجومی استفاده می‌کند.
class CalendarUpdateService {
  static const String sourceUrl =
      'https://raw.githubusercontent.com/jozeranjbar/MyAssistant/main/calendar_update/holidays.json';

  /// مقدارِ payload اعلانِ «بروزرسانی تقویم»
  static const String payload = 'update_calendar';

  static const String _prefsKey = 'official_holidays_json_v1';

  /// برای نمایش پیام (SnackBar) حتی وقتی از بیرونِ ویجت‌ها صدا زده می‌شود
  static final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

  /// با هر بروزرسانیِ موفق زیاد می‌شود تا صفحه‌ی تقویم دوباره ساخته شود
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static Map<int, List<OfficialHoliday>> _byYear = {};

  /// تعطیلاتِ رسمیِ متغیرِ یک سال؛ اگر برای آن سال داده‌ای نباشد null
  static List<OfficialHoliday>? holidaysForYear(int jalaliYear) => _byYear[jalaliYear];

  /// بارگذاریِ آخرین نسخه‌ی ذخیره‌شده (هنگام شروع برنامه)
  static Future<void> loadCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      _byYear = _parse(raw);
    } catch (_) {
      _byYear = {};
    }
  }

  /// فرمت: { "۱۴۰۶": { "lunar": [ {"month": 3, "day": 17, "title": "..."} ] } }
  /// کلیدهای غیرعددی (مثل _readme) و سال‌هایی که فهرستشان خالی است نادیده گرفته می‌شوند.
  static Map<int, List<OfficialHoliday>> _parse(String raw) {
    final decoded = json.decode(raw);
    if (decoded is! Map) throw const FormatException('root');
    final result = <int, List<OfficialHoliday>>{};
    decoded.forEach((key, value) {
      final year = int.tryParse(key.toString());
      if (year == null || value is! Map) return;
      final list = value['lunar'];
      if (list is! List) return;
      final items = <OfficialHoliday>[];
      for (final e in list) {
        if (e is! Map) continue;
        final m = e['month'], d = e['day'], t = e['title'];
        if (m is int && d is int && t is String && m >= 1 && m <= 12 && d >= 1 && d <= 31) {
          items.add(OfficialHoliday(m, d, t));
        }
      }
      if (items.isNotEmpty) result[year] = items;
    });
    return result;
  }

  static Future<CalendarUpdateResult> update() async {
    try {
      final res = await http.get(Uri.parse(sourceUrl)).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return const CalendarUpdateResult(CalendarUpdateStatus.server);
      final body = utf8.decode(res.bodyBytes);
      final parsed = _parse(body);
      if (parsed.isEmpty) return const CalendarUpdateResult(CalendarUpdateStatus.noData);

      final prefs = await SharedPreferences.getInstance();
      final previous = prefs.getString(_prefsKey);
      final years = parsed.keys.toList()..sort();
      if (previous != null && _sameData(_parse(previous), parsed)) {
        return CalendarUpdateResult(CalendarUpdateStatus.alreadyUpToDate, years);
      }
      await prefs.setString(_prefsKey, body);
      _byYear = parsed;
      revision.value++;
      return CalendarUpdateResult(CalendarUpdateStatus.updated, years);
    } on FormatException {
      return const CalendarUpdateResult(CalendarUpdateStatus.badFormat);
    } catch (_) {
      // قطعیِ اینترنت، timeout و ...
      return const CalendarUpdateResult(CalendarUpdateStatus.network);
    }
  }

  static bool _sameData(Map<int, List<OfficialHoliday>> a, Map<int, List<OfficialHoliday>> b) {
    if (a.length != b.length) return false;
    for (final y in a.keys) {
      final x = a[y]!, z = b[y];
      if (z == null || x.length != z.length) return false;
      for (var i = 0; i < x.length; i++) {
        if (x[i].month != z[i].month || x[i].day != z[i].day || x[i].title != z[i].title) return false;
      }
    }
    return true;
  }

  /// بروزرسانی + نمایشِ نتیجه به کاربر (با زدن روی اعلان صدا زده می‌شود)
  static Future<void> updateWithFeedback() async {
    final messenger = messengerKey.currentState;
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(const SnackBar(
      content: Text('در حال بروزرسانی تقویم...'),
      duration: Duration(seconds: 2),
    ));
    final result = await update();
    final m = messengerKey.currentState;
    m?.hideCurrentSnackBar();
    m?.showSnackBar(SnackBar(content: Text(result.message), duration: const Duration(seconds: 5)));
  }
}
