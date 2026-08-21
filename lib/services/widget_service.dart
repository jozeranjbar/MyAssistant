import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/weather_location.dart';
import '../models/weather_data.dart';
import '../models/reminder.dart';
import '../data/iranian_holidays.dart';

String _toPersianDigits(String input) {
  const western = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  var result = input;
  for (var i = 0; i < western.length; i++) {
    result = result.replaceAll(western[i], persian[i]);
  }
  return result;
}

/// این سرویس اطلاعات لازم برای ویجت صفحه اصلی گوشی (شهر، دما، ساعت، تاریخ،
/// نزدیک‌ترین یادآوری امروز) را در حافظه مشترک با بخش بومی اندروید ذخیره
/// می‌کند و به ویجت اعلام می‌کند که خودش را بازسازی کند.
class WidgetService {
  static const _pinChannel = MethodChannel('com.myassistant.app/widget_pin');
  static const _promptShownKey = 'widget_prompt_shown';

  static const String androidWidgetName = 'WeatherClockWidgetProvider';

  /// بروزرسانی اطلاعات ویجت با آخرین وضعیت آب‌وهوای اولین لوکیشن و
  /// نزدیک‌ترین یادآوری فعال امروز.
  static Future<void> updateWidgetData({
    WeatherLocation? location,
    WeatherData? weather,
    List<Reminder> reminders = const [],
  }) async {
    try {
      final today = Jalali.now();
      final gDate = today.toDateTime();
      final hijri = HijriCalendar.fromDate(gDate);
      const weekdays = ['شنبه', 'یکشنبه', 'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنجشنبه', 'جمعه'];

      final dateLine1 =
          '${weekdays[today.weekDay - 1]} ${_toPersianDigits(today.day.toString())} ${today.formatter.mN} ${_toPersianDigits(today.year.toString())}';
      final dateLine2 =
          '${_toPersianDigits(hijri.hDay.toString())} ${hijriMonthNamesFa[hijri.hMonth - 1]} ، ${gDate.day} ${gregorianMonthNamesFa[gDate.month - 1]}';

      // نزدیک‌ترین یادآوری فعال امروز که هنوز زمانش نگذشته
      final now = DateTime.now();
      final todayReminders = reminders.where((r) {
        if (!r.isActive) return false;
        final isToday = r.dateTime.year == now.year && r.dateTime.month == now.month && r.dateTime.day == now.day;
        return (isToday || r.repeatDaily) && r.dateTime.isAfter(now.subtract(const Duration(minutes: 1)));
      }).toList()
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

      final reminderText = todayReminders.isEmpty
          ? 'امروز یادآوری ندارید'
          : 'یادآوری در ساعت ${_toPersianDigits(todayReminders.first.dateTime.hour.toString().padLeft(2, '0'))}:${_toPersianDigits(todayReminders.first.dateTime.minute.toString().padLeft(2, '0'))}';

      await HomeWidget.saveWidgetData<String>('city_name', location?.name ?? '—');
      await HomeWidget.saveWidgetData<String>(
          'temperature', weather != null ? '${_toPersianDigits(weather.temperature.round().toString())}°' : '--');
      await HomeWidget.saveWidgetData<String>('weather_desc', weather?.description ?? '');
      await HomeWidget.saveWidgetData<String>('weather_emoji', weather?.iconEmoji ?? '🌡️');
      await HomeWidget.saveWidgetData<String>('date_line1', dateLine1);
      await HomeWidget.saveWidgetData<String>('date_line2', dateLine2);
      await HomeWidget.saveWidgetData<String>('reminder_text', reminderText);

      await HomeWidget.updateWidget(
        androidName: androidWidgetName,
        qualifiedAndroidName: 'com.myassistant.app.$androidWidgetName',
      );
    } catch (_) {
      // بروزرسانی ویجت اختیاری است؛ خطا نباید کل برنامه را متوقف کند
    }
  }

  /// آیا قبلاً از کاربر برای افزودن ویجت سؤال شده است؟
  static Future<bool> hasPromptedBefore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_promptShownKey) ?? false;
  }

  static Future<void> markPrompted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_promptShownKey, true);
  }

  /// نمایش دیالوگ سیستمی اندروید برای «پین کردن» ویجت به صفحه اصلی
  /// (فقط اندروید ۸ به بالا پشتیبانی می‌شود).
  static Future<void> requestPinWidget() async {
    try {
      await _pinChannel.invokeMethod('requestPin');
    } catch (_) {
      // روی نسخه‌های قدیمی‌تر اندروید یا خطای دیگر، بی‌صدا نادیده گرفته می‌شود
    }
  }
}
