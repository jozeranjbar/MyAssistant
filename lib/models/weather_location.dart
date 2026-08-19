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
        id: json['id'],
        name: json['name'],
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        source: json['source'] ?? 'manual',
        province: json['province'],
      );
}
