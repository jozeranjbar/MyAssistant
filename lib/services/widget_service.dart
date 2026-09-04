import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/weather_location.dart';
import '../models/weather_data.dart';
import '../models/reminder.dart';
import '../data/iranian_holidays.dart';

/// انتخاب ایموجی پوشش ابر متناسب با وضعیت هوا و زمان روز/شب.
String _cloudCoverageEmoji(WeatherData? weather, bool isDay) {
  final desc = weather?.description ?? '';

  if (desc.contains('برف')) return '🌨️';
  if (desc.contains('رعد') || desc.contains('طوفان')) return '⛈️';
  if (desc.contains('باران') || desc.contains('بارش')) return isDay ? '🌦️' : '🌧️';
  if (desc.contains('ابری') && !desc.contains('کمی') && !desc.contains('نیمه')) {
    return '☁️';
  }
  if (desc.contains('ابر')) {
    // کمی ابری / نیمه‌ابری
    return isDay ? '🌤️' : '🌥️';
  }
  if (desc.contains('صاف') || desc.contains('آفتاب')) {
    return isDay ? '☀️' : '🌙';
  }
  // مقدار پیش‌فرض وقتی توضیحی در دسترس نیست
  return isDay ? '🌤️' : '🌙';
}

/// این سرویس اطلاعات لازم برای ویجت صفحه اصلی گوشی (شهر، دما، ساعت، تاریخ،
/// تعداد یادآوری‌های امروز) را در حافظه مشترک با بخش بومی اندروید ذخیره
/// می‌کند و به ویجت اعلام می‌کند که خودش را بازسازی کند.
class WidgetService {
  static const _pinChannel = MethodChannel('com.myassistant.app/widget_pin');
  static const _promptShownKey = 'widget_prompt_shown';

  static const String androidWidgetName = 'WeatherClockWidgetProvider';

  /// بروزرسانی اطلاعات ویجت با آخرین وضعیت آب‌وهوای اولین لوکیشن، ساعت،
  /// تاریخ (شمسی/قمری/میلادی) و تعداد یادآوری‌های فعال امروز.
  static Future<void> updateWidgetData({
    WeatherLocation? location,
    WeatherData? weather,
    List<Reminder> reminders = const [],
  }) async {
    try {
      final today = Jalali.now();
      final gDate = today.toDateTime();
      final hijri = HijriCalendar.fromDate(gDate);

      final weekdayText = shamsiWeekdayNamesFa[today.weekDay - 1];
      // اعداد انگلیسی (بدون تبدیل به ارقام فارسی)
      final dateShamsi = '${today.day} ${today.formatter.mN}';
      final dateHijri = '${hijri.hDay} ${hijriMonthNamesFa[hijri.hMonth - 1]}';
      final dateGregorian = '${gDate.day} ${gregorianMonthNamesFa[gDate.month - 1]}';

      // تعداد یادآوری‌های فعال (هر دو دسته‌ی دارو و روزمره)
      final activeCount = reminders.where((r) => r.isActive).length;
      final reminderText = '$activeCount یادآوری';

      final now = DateTime.now();
      final hour = now.hour;
      final isDay = hour >= 6 && hour < 18;

      await HomeWidget.saveWidgetData<String>('city_name', location?.name ?? '—');
      await HomeWidget.saveWidgetData<String>(
          'temperature', weather != null ? '${weather.temperature.round()}°' : '--');
      await HomeWidget.saveWidgetData<String>('weather_emoji', _cloudCoverageEmoji(weather, isDay));
      await HomeWidget.saveWidgetData<String>('weekday_text', weekdayText);
      await HomeWidget.saveWidgetData<String>('date_shamsi', dateShamsi);
      await HomeWidget.saveWidgetData<String>('date_hijri', dateHijri);
      await HomeWidget.saveWidgetData<String>('date_gregorian', dateGregorian);
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
  /// (فقط اندروید ۸ به بالا پشتیبانی می‌شود). این تأییدیه توسط خود
  /// سیستم‌عامل نمایش داده می‌شود و هیچ اپی نمی‌تواند آن را حذف کند.
  static Future<void> requestPinWidget() async {
    try {
      await _pinChannel.invokeMethod('requestPin');
    } catch (_) {
      // روی نسخه‌های قدیمی‌تر اندروید یا خطای دیگر، بی‌صدا نادیده گرفته می‌شود
    }
  }
}
