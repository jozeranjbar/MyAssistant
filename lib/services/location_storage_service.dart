import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/weather_location.dart';
import '../models/weather_data.dart';

/// ذخیره‌سازی دائمی لوکیشن‌های آب‌وهوا (حداکثر ۴ عدد) و کش موقت اطلاعات هر لوکیشن.
/// از SharedPreferences استفاده می‌شود که روی دیسک گوشی ذخیره شده و بعد از
/// بستن برنامه یا ری‌استارت گوشی باقی می‌ماند.
class LocationStorageService {
  static const _locationsKey = 'weather_locations';
  static const _cachePrefix = 'weather_cache_';
  static const int maxLocations = 4;

  Future<List<WeatherLocation>> loadLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_locationsKey);

    if (raw == null || raw.isEmpty) {
      // هیچ شهری به‌صورت پیش‌فرض انتخاب نمی‌شود؛ کاربر خودش باید شهر مورد
      // نظرش را از صفحه‌ی تنظیمات آب‌وهوا اضافه کند.
      return [];
    }

    // نکته‌ی مهم درباره‌ی «کرش روی گوشی‌های جدید»: وقتی کاربر گوشی عوض
    // می‌کند، اندروید به‌صورت خودکار (Auto Backup) دیتای SharedPreferences
    // برنامه را از گوشی قبلی روی گوشی جدید بازیابی می‌کند. اگر این دیتا به
    // هر دلیلی (نسخه‌ی قدیمی‌تر برنامه، بازیابیِ ناقص/خراب) با ساختار فعلی
    // WeatherLocation جور در نیاید، decode/parse خطا می‌دهد. قبلاً این خطا
    // اصلاً catch نمی‌شد، پس همان اولین باز شدنِ برنامه (در home_screen)
    // کرش می‌کرد. حالا هم کل لیست، هم هر آیتمِ داخلش جداگانه محافظت می‌شود:
    // یک آیتمِ خراب فقط همان یکی را حذف می‌کند، نه کل لیستِ شهرها را.
    try {
      final list = jsonDecode(raw) as List;
      final result = <WeatherLocation>[];
      for (final e in list) {
        try {
          result.add(WeatherLocation.fromJson(e as Map<String, dynamic>));
        } catch (_) {
          // این یک آیتم نادیده گرفته می‌شود؛ بقیه‌ی شهرها سالم می‌مانند.
        }
      }
      return result;
    } catch (_) {
      // کل دیتای ذخیره‌شده خراب/ناسازگار بود؛ به‌جای کرش، لیست خالی
      // برگردانده می‌شود (دقیقاً مثل رفتارِ ReminderStorageService).
      return [];
    }
  }

  Future<void> saveLocations(List<WeatherLocation> locations) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(locations.map((e) => e.toJson()).toList());
    await prefs.setString(_locationsKey, raw);
  }

  Future<bool> addLocation(WeatherLocation location) async {
    final locations = await loadLocations();
    if (locations.length >= maxLocations) return false;
    locations.add(location);
    await saveLocations(locations);
    return true;
  }

  Future<void> removeLocation(String id) async {
    final locations = await loadLocations();
    locations.removeWhere((l) => l.id == id);
    await saveLocations(locations);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_cachePrefix$id');
  }

  /// انتقال یک لوکیشن به ابتدای لیست
  Future<void> moveToTop(String id) async {
    final locations = await loadLocations();
    final index = locations.indexWhere((l) => l.id == id);
    if (index <= 0) return;
    final item = locations.removeAt(index);
    locations.insert(0, item);
    await saveLocations(locations);
  }

  // --- کش موقت اطلاعات آب‌وهوا برای هر لوکیشن (برای نمایش سریع/آفلاین) ---

  Future<void> cacheWeather(String locationId, WeatherData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_cachePrefix$locationId', jsonEncode(data.toJson()));
  }

  Future<WeatherData?> getCachedWeather(String locationId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_cachePrefix$locationId');
    if (raw == null) return null;
    try {
      return WeatherData.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }
}
