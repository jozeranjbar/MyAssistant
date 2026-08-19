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
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => WeatherLocation.fromJson(e)).toList();
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

  Future<void> reorder(List<WeatherLocation> newOrder) async {
    await saveLocations(newOrder);
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
