import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/weather_data.dart';

/// این سرویس از API رایگان Open-Meteo استفاده می‌کند (نیازی به کلید API نیست).
/// مستندات: https://open-meteo.com/
class WeatherService {
  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  /// در صورت خطا (نبود اینترنت، خطای سرور و ...) یک Exception با پیام
  /// قابل‌نمایش به کاربر پرتاب می‌شود.
  Future<WeatherData> fetchWeather({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'current': [
        'temperature_2m',
        'apparent_temperature',
        'relative_humidity_2m',
        'precipitation',
        'wind_speed_10m',
        'weather_code',
      ].join(','),
      'daily': [
        'uv_index_max',
        'temperature_2m_max',
        'temperature_2m_min',
        'weather_code',
        'precipitation_probability_max',
      ].join(','),
      'forecast_days': '10',
      'timezone': 'auto',
    });

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        throw WeatherException(
            'خطا در دریافت اطلاعات آب و هوا (کد ${response.statusCode}). لطفاً بعداً دوباره تلاش کنید.');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final current = data['current'] as Map<String, dynamic>?;
      final daily = data['daily'] as Map<String, dynamic>?;

      if (current == null) {
        throw WeatherException('پاسخ سرور آب‌وهوا نامعتبر بود.');
      }

      double uv = 0;
      try {
        uv = ((daily?['uv_index_max'] as List?)?.first as num?)?.toDouble() ?? 0;
      } catch (_) {
        uv = 0;
      }

      final forecast = <DailyForecast>[];
      try {
        final times = daily?['time'] as List?;
        final maxTemps = daily?['temperature_2m_max'] as List?;
        final minTemps = daily?['temperature_2m_min'] as List?;
        final codes = daily?['weather_code'] as List?;
        final precipProbs = daily?['precipitation_probability_max'] as List?;
        if (times != null) {
          for (var i = 0; i < times.length; i++) {
            forecast.add(DailyForecast(
              date: DateTime.parse(times[i] as String),
              maxTemp: (maxTemps?[i] as num?)?.toDouble() ?? 0,
              minTemp: (minTemps?[i] as num?)?.toDouble() ?? 0,
              weatherCode: (codes?[i] as num?)?.toInt() ?? 0,
              precipitationProbability: (precipProbs?[i] as num?)?.toInt() ?? 0,
            ));
          }
        }
      } catch (_) {
        // پیش‌بینی روزانه اختیاری است؛ در صورت خطا نادیده گرفته می‌شود
      }

      return WeatherData(
        temperature: (current['temperature_2m'] as num).toDouble(),
        feelsLike: (current['apparent_temperature'] as num).toDouble(),
        humidity: (current['relative_humidity_2m'] as num).toInt(),
        precipitation: (current['precipitation'] as num).toDouble(),
        windSpeed: (current['wind_speed_10m'] as num).toDouble(),
        uvIndex: uv,
        weatherCode: (current['weather_code'] as num).toInt(),
        updatedAt: DateTime.now(),
        forecast: forecast,
      );
    } on WeatherException {
      rethrow;
    } catch (e) {
      // شامل خطای نبود اینترنت (SocketException)، Timeout و غیره
      throw WeatherException('اتصال به اینترنت برقرار نیست یا سرور آب‌وهوا در دسترس نیست.');
    }
  }
}

class WeatherException implements Exception {
  final String message;
  WeatherException(this.message);
  @override
  String toString() => message;
}
