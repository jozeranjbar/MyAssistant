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

const _weekdayNamesFa = ['دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنجشنبه', 'جمعه', 'شنبه', 'یکشنبه'];

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
    return _toPersianDigits('${DateFormat('yyyy/MM/dd').format(d)} - ${DateFormat('HH:mm').format(d)}');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100),
      ),
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
            // ردیف بالا: توضیح وضعیت (سمت راست) + دمای بزرگ (سمت چپ)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data!.iconEmoji, style: const TextStyle(fontSize: 26)),
                      const SizedBox(height: 2),
                      Text(data!.description, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                    ],
                  ),
                ),
                Text(
                  '${_toPersianDigits(data!.temperature.round().toString())}°',
                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // ردیف فشرده آمار (احساس دما، رطوبت، باد، بارندگی، UV) با کمترین فاصله
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              runSpacing: 4,
              children: [
                _StatChip(icon: Icons.thermostat, color: Colors.red, value: '${_toPersianDigits(data!.feelsLike.round().toString())}°', label: 'احساس دما'),
                _StatChip(icon: Icons.water_drop, color: Colors.blue, value: '${_toPersianDigits(data!.humidity.toString())}%', label: 'رطوبت'),
                _StatChip(icon: Icons.air, color: Colors.blue, value: '${_toPersianDigits(data!.windSpeed.round().toString())} km/h', label: 'باد'),
                _StatChip(icon: Icons.grain, color: Colors.blueGrey, value: '${_toPersianDigits(data!.precipitation.toStringAsFixed(1))} mm', label: 'بارندگی'),
                _StatChip(icon: Icons.wb_sunny, color: Colors.orange, value: 'UV ${_toPersianDigits(data!.uvIndex.round().toString())}', label: ''),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(location.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text('بروزرسانی: ${_formattedUpdateTime()}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
            if (data!.forecast.isNotEmpty) ...[
              const Divider(height: 20),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  childAspectRatio: 0.68,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 2,
                ),
                itemCount: data!.forecast.length > 10 ? 10 : data!.forecast.length,
                itemBuilder: (context, index) {
                  final f = data!.forecast[index];
                  return Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_weekdayNamesFa[f.date.weekday - 1],
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis),
                        Text(f.iconEmoji, style: const TextStyle(fontSize: 16)),
                        Text(
                          '${_toPersianDigits(f.minTemp.round().toString())}°/${_toPersianDigits(f.maxTemp.round().toString())}°',
                          style: const TextStyle(fontSize: 10),
                        ),
                        Text('بارش ${_toPersianDigits(f.precipitationProbability.toString())}%',
                            style: TextStyle(fontSize: 8, color: Colors.grey.shade600)),
                      ],
                    ),
                  );
                },
              ),
            ],
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 2),
        Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        if (label.isNotEmpty) ...[
          const SizedBox(width: 2),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
        ],
      ],
    );
  }
}
