import 'package:workmanager/workmanager.dart';
import 'weather_service.dart';
import 'location_storage_service.dart';
import 'reminder_storage_service.dart';
import 'widget_service.dart';
import '../models/weather_data.dart';

const String kWeatherRefreshTask = 'weather_refresh_task';

/// این تابع باید سطح بالا (top-level) یا static باشد چون توسط Workmanager
/// در یک Isolate جدا اجرا می‌شود.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case kWeatherRefreshTask:
        await _refreshAllWeatherInBackground();
        break;
    }
    return Future.value(true);
  });
}

Future<void> _refreshAllWeatherInBackground() async {
  final storage = LocationStorageService();
  final reminderStorage = ReminderStorageService();
  final weatherService = WeatherService();
  final locations = await storage.loadLocations();

  WeatherData? firstWeather;
  for (final loc in locations) {
    try {
      final data = await weatherService.fetchWeather(
        latitude: loc.latitude,
        longitude: loc.longitude,
      );
      await storage.cacheWeather(loc.id, data);
      if (loc.id == locations.first.id) {
        firstWeather = data;
      }
    } catch (_) {
      // بدون اینترنت یا خطای سرور؛ کش قبلی دست‌نخورده باقی می‌ماند
    }
  }

  // اگر دریافت تازه ناموفق بود (مثلاً قطعی موقت اینترنت)، از آخرین مقدار
  // کش‌شده استفاده می‌شود تا حداقل تاریخ/ساعت/یادآوری‌های ویجت به‌روز شوند.
  if (firstWeather == null && locations.isNotEmpty) {
    firstWeather = await storage.getCachedWeather(locations.first.id);
  }

  // این بخش، همان چیزی است که قبلاً فراموش شده بود: بدون این فراخوانی،
  // اطلاعات فقط در حافظه‌ی کش ذخیره می‌شد ولی خودِ ویجتِ روی صفحه‌ی گوشی
  // هرگز بازسازی نمی‌شد و کاربر مجبور بود برنامه را باز کند.
  final reminders = await reminderStorage.loadReminders();
  await WidgetService.updateWidgetData(
    location: locations.isNotEmpty ? locations.first : null,
    weather: firstWeather,
    reminders: reminders,
  );
}

class BackgroundService {
  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    // بروزرسانی دوره‌ای آب‌وهوا (و ویجت) هر ۳۰ دقیقه (حداقل بازه مجاز در اندروید ۱۵ دقیقه است)
    await Workmanager().registerPeriodicTask(
      'periodic-weather-refresh',
      kWeatherRefreshTask,
      frequency: const Duration(minutes: 30),
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }
}
