class WeatherData {
  final double temperature; // دما
  final double feelsLike; // احساس دما
  final int humidity; // رطوبت %
  final double precipitation; // بارندگی mm
  final double windSpeed; // سرعت باد km/h
  final double uvIndex; // شاخص UV
  final int weatherCode; // کد وضعیت هوا (Open-Meteo WMO code)
  final DateTime updatedAt; // زمان بروزرسانی

  WeatherData({
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.precipitation,
    required this.windSpeed,
    required this.uvIndex,
    required this.weatherCode,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'temperature': temperature,
        'feelsLike': feelsLike,
        'humidity': humidity,
        'precipitation': precipitation,
        'windSpeed': windSpeed,
        'uvIndex': uvIndex,
        'weatherCode': weatherCode,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory WeatherData.fromJson(Map<String, dynamic> json) => WeatherData(
        temperature: (json['temperature'] as num).toDouble(),
        feelsLike: (json['feelsLike'] as num).toDouble(),
        humidity: (json['humidity'] as num).toInt(),
        precipitation: (json['precipitation'] as num).toDouble(),
        windSpeed: (json['windSpeed'] as num).toDouble(),
        uvIndex: (json['uvIndex'] as num).toDouble(),
        weatherCode: json['weatherCode'] as int,
        updatedAt: DateTime.parse(json['updatedAt']),
      );

  /// توضیح وضعیت هوا بر اساس کد WMO (استفاده‌شده در Open-Meteo)
  String get description {
    if (weatherCode == 0) return 'آفتابی';
    if (weatherCode <= 2) return 'کمی ابری';
    if (weatherCode == 3) return 'ابری';
    if (weatherCode == 45 || weatherCode == 48) return 'مه‌آلود';
    if (weatherCode >= 51 && weatherCode <= 57) return 'نم‌نم باران';
    if (weatherCode >= 61 && weatherCode <= 67) return 'بارانی';
    if (weatherCode >= 71 && weatherCode <= 77) return 'برفی';
    if (weatherCode >= 80 && weatherCode <= 82) return 'رگبار';
    if (weatherCode >= 85 && weatherCode <= 86) return 'رگبار برف';
    if (weatherCode >= 95) return 'طوفانی';
    return 'نامشخص';
  }

  /// نام آیکون Material متناظر با وضعیت هوا
  String get iconEmoji {
    if (weatherCode == 0) return '☀️';
    if (weatherCode <= 2) return '🌤️';
    if (weatherCode == 3) return '☁️';
    if (weatherCode == 45 || weatherCode == 48) return '🌫️';
    if (weatherCode >= 51 && weatherCode <= 67) return '🌧️';
    if (weatherCode >= 71 && weatherCode <= 77) return '❄️';
    if (weatherCode >= 80 && weatherCode <= 86) return '🌦️';
    if (weatherCode >= 95) return '⛈️';
    return '🌡️';
  }
}
