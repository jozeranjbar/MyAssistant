import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/weather_location.dart';
import '../models/weather_data.dart';

String _toPersianDigits(String input) {
  const western = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  var result = input;
  for (var i = 0; i < western.length; i++) {
    result = result.replaceAll(western[i], persian[i]);
  }
  return result;
}

/// ساعت را به‌صورت ۱۲ ساعتی همراه با قبل/بعدازظهر برمی‌گرداند (نه ۲۴ ساعتی).
String _formatTime12(DateTime dt) {
  final h12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final period = dt.hour < 12 ? 'ق.ظ' : 'ب.ظ';
  return '${h12.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $period';
}

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
    return _toPersianDigits('${DateFormat('yyyy/MM/dd').format(d)} - ${_formatTime12(d)}');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
            // سطر اول: نام لوکیشن (تهران) و زمان بروزرسانی
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(location.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text('بروزرسانی: ${_formattedUpdateTime()}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
            const SizedBox(height: 6),
            // سطر دوم: حالت ابر (آیکون + توضیح) و دما به همراه حداقل/حداکثر در پرانتز
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(data!.iconEmoji, style: const TextStyle(fontSize: 26)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(data!.description, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                      ),
                    ],
                  ),
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${_toPersianDigits(data!.temperature.round().toString())}°',
                        style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                      if (data!.todayForecast != null)
                        TextSpan(
                          text:
                              ' (${_toPersianDigits(data!.todayForecast!.minTemp.round().toString())}°-${_toPersianDigits(data!.todayForecast!.maxTemp.round().toString())}°)',
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.normal),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // همه‌ی آمار پشت سر هم؛ فقط اگر عرض صفحه کم باشد به ردیف بعد می‌روند - اعداد انگلیسی
            Wrap(
              alignment: WrapAlignment.start,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 14,
              runSpacing: 10,
              children: [
                _StatChip(icon: Icons.thermostat, color: Colors.red, label: 'احساس دما', value: '${data!.feelsLike.round()}°'),
                if (data!.todayForecast != null)
                  _StatChip(
                      icon: Icons.umbrella,
                      color: Colors.indigo,
                      label: 'احتمال بارش',
                      value: '${data!.todayForecast!.precipitationProbability}%'),
                _StatChip(icon: Icons.water_drop, color: Colors.blue, label: 'رطوبت', value: '${data!.humidity}%'),
                _StatChip(icon: Icons.grain, color: Colors.blueGrey, label: 'بارندگی', value: '${data!.precipitation.toStringAsFixed(1)} mm'),
                _StatChip(icon: Icons.air, color: Colors.blue, label: 'باد', value: '${data!.windSpeed.round()} km/h'),
                Text('|', style: TextStyle(fontSize: 22, color: Colors.grey.shade400)),
                _StatChip(icon: Icons.visibility, color: Colors.teal, label: 'دید افقی', value: '${data!.visibility.toStringAsFixed(1)} km'),
                Text('|', style: TextStyle(fontSize: 22, color: Colors.grey.shade400)),
                _StatChip(icon: Icons.wb_sunny, color: Colors.orange, label: 'شاخصUV', value: '${data!.uvIndex.round()}'),
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

class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _StatChip({required this.icon, required this.color, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    // فونت و آیکون این ردیف نسبت به نسخه قبلی دو برابر شده است
    // ترتیب: آیکون، کلمه فارسی، عدد انگلیسی
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 28, color: color),
        const SizedBox(width: 4),
        if (label.isNotEmpty) ...[
          Text(label, style: TextStyle(fontSize: 20, color: Colors.grey.shade700)),
          const SizedBox(width: 4),
        ],
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
