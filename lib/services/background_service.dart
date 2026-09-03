import 'package:workmanager/workmanager.dart';
import 'weather_service.dart';
import 'location_storage_service.dart';

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
  final weatherService = WeatherService();
  final locations = await storage.loadLocations();
  for (final loc in locations) {
    try {
      final data = await weatherService.fetchWeather(
        latitude: loc.latitude,
        longitude: loc.longitude,
      );
      await storage.cacheWeather(loc.id, data);
    } catch (_) {
      // بدون اینترنت یا خطای سرور؛ کش قبلی دست‌نخورده باقی می‌ماند
    }
  }
}

class BackgroundService {
  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    // بروزرسانی دوره‌ای آب‌وهوا هر ۳۰ دقیقه (حداقل بازه مجاز در اندروید ۱۵ دقیقه است)
    await Workmanager().registerPeriodicTask(
      'periodic-weather-refresh',
      kWeatherRefreshTask,
      frequency: const Duration(minutes: 30),
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }
}
