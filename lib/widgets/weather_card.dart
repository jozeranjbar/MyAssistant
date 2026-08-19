import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/weather_location.dart';
import '../models/weather_data.dart';

class WeatherCard extends StatelessWidget {
  final WeatherLocation location;
  final WeatherData? data;
  final bool loading;
  final String? error;

  const WeatherCard({
    super.key,
    required this.location,
    required this.data,
    required this.loading,
    required this.error,
  });

  String _formattedUpdateTime() {
    if (data == null) return '--';
    final d = data!.updatedAt;
    return '${DateFormat('yyyy/MM/dd').format(d)} - ${DateFormat('HH:mm').format(d)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('بروزرسانی: ${_formattedUpdateTime()}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              Row(
                children: [
                  Text(location.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  const Icon(Icons.location_on, color: Colors.blue, size: 20),
                ],
              ),
            ],
          ),
          const Divider(height: 20),
          if (loading && data == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (error != null && data == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  const Icon(Icons.cloud_off, color: Colors.grey, size: 32),
                  const SizedBox(height: 8),
                  Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                ],
              ),
            )
          else if (data != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _InfoItem(
                  icon: Icons.thermostat,
                  iconColor: Colors.red,
                  value: '${data!.feelsLike.round()}°',
                  label: 'احساس دما',
                ),
                _InfoItem(
                  icon: Icons.thermostat_outlined,
                  iconColor: Colors.blue,
                  value: '${data!.temperature.round()}°',
                  label: 'دما',
                ),
                _InfoItem(
                  emoji: data!.iconEmoji,
                  value: '',
                  label: data!.description,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _InfoItem(
                  icon: Icons.water_drop,
                  iconColor: Colors.blue,
                  value: '${data!.humidity}%',
                  label: 'رطوبت',
                ),
                _InfoItem(
                  icon: Icons.grain,
                  iconColor: Colors.blueGrey,
                  value: '${data!.precipitation.toStringAsFixed(1)} mm',
                  label: 'بارندگی',
                ),
                _InfoItem(
                  icon: Icons.air,
                  iconColor: Colors.blue,
                  value: '${data!.windSpeed.round()} km/h',
                  label: 'سرعت باد',
                ),
                _InfoItem(
                  icon: Icons.wb_sunny,
                  iconColor: Colors.orange,
                  value: 'UV ${data!.uvIndex.round()}',
                  label: 'شاخص UV',
                ),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text('⚠️ $error (نمایش آخرین اطلاعات ذخیره‌شده)',
                  style: const TextStyle(fontSize: 11, color: Colors.orange)),
            ]
          ],
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final String? emoji;
  final String value;
  final String label;

  const _InfoItem({this.icon, this.iconColor, this.emoji, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (emoji != null)
          Text(emoji!, style: const TextStyle(fontSize: 28))
        else
          Icon(icon, color: iconColor, size: 26),
        const SizedBox(height: 4),
        if (value.isNotEmpty)
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
      ],
    );
  }
}
