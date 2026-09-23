class WeatherLocation {
  final String id;
  String name;
  final double latitude;
  final double longitude;
  final String source; // 'manual' یا 'iran_city'
  final String? province;

  WeatherLocation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.source = 'manual',
    this.province,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'source': source,
        'province': province,
      };

  factory WeatherLocation.fromJson(Map<String, dynamic> json) => WeatherLocation(
        // به‌جای فرض قطعی روی نوعِ دقیقِ هر فیلد (که با دیتای بازیابی‌شده از
        // گوشیِ قبلی یا نسخه‌ی قدیمی‌تر برنامه ممکن است جور در نیاید و کل
        // اپ را کرش کند)، همه‌جا با as? خوانده می‌شود و مقدار پیش‌فرضِ امن
        // جایگزین می‌شود.
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
        source: json['source'] as String? ?? 'manual',
        province: json['province'] as String?,
      );
}
