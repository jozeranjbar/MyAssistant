import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../models/weather_location.dart';
import '../models/weather_data.dart';
import '../data/iranian_holidays.dart';
import '../utils/persian_numbers.dart';

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
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_forward_ios, color: Colors.brown.shade400, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        centerTitle: true,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'وضعیت هوای ده روز آینده ${location.name}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.brown.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
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
                  final weekday = gregorianWeekdayNamesFa[f.date.weekday - 1];
                  final jalali = Jalali.fromDateTime(f.date);
                  final dateStr = '${toPersianDigits(jalali.day.toString())} ${jalali.formatter.mN}';
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
                            '${toPersianDigits(f.minTemp.round().toString())}°/${toPersianDigits(f.maxTemp.round().toString())}°',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.brown.shade700),
                          ),
                          _DayStatChip(
                            icon: Icons.grain,
                            color: Colors.blue,
                            label: 'بارش',
                            value: '${toPersianDigits(f.precipitationProbability.toString())}%',
                          ),
                          _DayStatChip(
                            icon: Icons.water_drop,
                            color: Colors.blue,
                            label: 'رطوبت',
                            value: '${toPersianDigits(f.humidity.toString())}%',
                          ),
                          _DayStatChip(
                            icon: Icons.wb_sunny,
                            color: Colors.orange,
                            label: 'UV',
                            value: toPersianDigits(f.uvIndex.round().toString()),
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
