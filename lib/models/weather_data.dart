class DailyForecast {
  final DateTime date;
  final double minTemp;
  final double maxTemp;
  final int weatherCode;
  final int precipitationProbability;
  final int humidity; // رطوبت میانگین روز %
  final double uvIndex; // شاخص UV روز

  DailyForecast({
    required this.date,
    required this.minTemp,
    required this.maxTemp,
    required this.weatherCode,
    required this.precipitationProbability,
    this.humidity = 0,
    this.uvIndex = 0,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'minTemp': minTemp,
        'maxTemp': maxTemp,
        'weatherCode': weatherCode,
        'precipitationProbability': precipitationProbability,
        'humidity': humidity,
        'uvIndex': uvIndex,
      };

  factory DailyForecast.fromJson(Map<String, dynamic> json) => DailyForecast(
        date: DateTime.parse(json['date']),
        minTemp: (json['minTemp'] as num).toDouble(),
        maxTemp: (json['maxTemp'] as num).toDouble(),
        weatherCode: json['weatherCode'] as int,
        precipitationProbability: json['precipitationProbability'] as int,
        humidity: (json['humidity'] as num?)?.toInt() ?? 0,
        uvIndex: (json['uvIndex'] as num?)?.toDouble() ?? 0,
      );

  String get iconEmoji => WeatherData.emojiForCode(weatherCode);
}

class WeatherData {
  final double temperature; // دما
  final double feelsLike; // احساس دما
  final int humidity; // رطوبت %
  final double precipitation; // بارندگی mm
  final double windSpeed; // سرعت باد km/h
  final double uvIndex; // شاخص UV
  final double visibility; // دید افقی (کیلومتر)
  final int weatherCode; // کد وضعیت هوا (Open-Meteo WMO code)
  final DateTime updatedAt; // زمان بروزرسانی
  final List<DailyForecast> forecast; // پیش‌بینی ۱۰ روزه

  WeatherData({
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.precipitation,
    required this.windSpeed,
    required this.uvIndex,
    this.visibility = 0,
    required this.weatherCode,
    required this.updatedAt,
    this.forecast = const [],
  });

  Map<String, dynamic> toJson() => {
        'temperature': temperature,
        'feelsLike': feelsLike,
        'humidity': humidity,
        'precipitation': precipitation,
        'windSpeed': windSpeed,
        'uvIndex': uvIndex,
        'visibility': visibility,
        'weatherCode': weatherCode,
        'updatedAt': updatedAt.toIso8601String(),
        'forecast': forecast.map((f) => f.toJson()).toList(),
      };

  factory WeatherData.fromJson(Map<String, dynamic> json) => WeatherData(
        temperature: (json['temperature'] as num).toDouble(),
        feelsLike: (json['feelsLike'] as num).toDouble(),
        humidity: (json['humidity'] as num).toInt(),
        precipitation: (json['precipitation'] as num).toDouble(),
        windSpeed: (json['windSpeed'] as num).toDouble(),
        uvIndex: (json['uvIndex'] as num).toDouble(),
        visibility: (json['visibility'] as num?)?.toDouble() ?? 0,
        weatherCode: json['weatherCode'] as int,
        updatedAt: DateTime.parse(json['updatedAt']),
        forecast: json['forecast'] != null
            ? (json['forecast'] as List).map((f) => DailyForecast.fromJson(f)).toList()
            : const [],
      );

  /// پیش‌بینی «امروز» (اولین آیتم لیست پیش‌بینی، در صورت وجود)
  DailyForecast? get todayForecast => forecast.isNotEmpty ? forecast.first : null;

  /// پیش‌بینی ده روز آینده، از «فردا» شروع می‌شود (آیتم اول لیست «امروز» است و کنار گذاشته می‌شود)
  List<DailyForecast> get next10DaysForecast =>
      forecast.length > 1 ? forecast.sublist(1, forecast.length > 11 ? 11 : forecast.length) : const [];

  /// توضیح وضعیت هوا بر اساس کد WMO (استفاده‌شده در Open-Meteo)
  String get description => descriptionForCode(weatherCode);

  static String descriptionForCode(int weatherCode) {
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
  String get iconEmoji => emojiForCode(weatherCode);

  static String emojiForCode(int weatherCode) {
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
