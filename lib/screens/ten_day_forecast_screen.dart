import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
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

/// صفحه‌ی وضعیت ده روز آینده آب‌وهوا (از فردا شروع می‌شود)
class TenDayForecastScreen extends StatelessWidget {
  final WeatherLocation location;
  final WeatherData data;

  const TenDayForecastScreen({super.key, required this.location, required this.data});

  @override
  Widget build(BuildContext context) {
    final days = data.next10DaysForecast;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.lightBlue.shade100,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.arrow_back_ios, size: 16, color: Colors.brown.shade400),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'وضعیت هوای ده روز آینده ${location.name}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.brown.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.brown.shade400),
          ],
        ),
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0).abs() > 200) {
            Navigator.of(context).maybePop();
          }
        },
        child: days.isEmpty
            ? const Center(child: Text('پیش‌بینی ده روز آینده در دسترس نیست'))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: days.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final f = days[index];
                  final weekday = _weekdayNamesFa[f.date.weekday - 1];
                  final jalali = Jalali.fromDateTime(f.date);
                  final dateStr = '${_toPersianDigits(jalali.day.toString())} ${jalali.formatter.mN}';
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$weekday $dateStr',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue.shade900)),
                      const SizedBox(height: 10),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 14,
                        runSpacing: 10,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(f.iconEmoji, style: const TextStyle(fontSize: 26)),
                              const SizedBox(width: 6),
                              Text(WeatherData.descriptionForCode(f.weatherCode), style: const TextStyle(fontSize: 18)),
                            ],
                          ),
                          Text(
                            '${_toPersianDigits(f.minTemp.round().toString())}°/${_toPersianDigits(f.maxTemp.round().toString())}°',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.brown.shade700),
                          ),
                          _DayStatChip(
                            icon: Icons.grain,
                            color: Colors.blue,
                            label: 'بارش',
                            value: '${_toPersianDigits(f.precipitationProbability.toString())}%',
                          ),
                          _DayStatChip(
                            icon: Icons.water_drop,
                            color: Colors.blue,
                            label: 'رطوبت',
                            value: '${_toPersianDigits(f.humidity.toString())}%',
                          ),
                          _DayStatChip(
                            icon: Icons.wb_sunny,
                            color: Colors.orange,
                            label: 'UV',
                            value: _toPersianDigits(f.uvIndex.round().toString()),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
      ),
    );
  }
}

class _DayStatChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _DayStatChip({required this.icon, required this.color, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 16, color: Colors.green.shade900)),
        const SizedBox(width: 4),
        Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.brown.shade700)),
      ],
    );
  }
}
