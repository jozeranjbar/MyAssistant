import 'package:flutter/material.dart';
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
const _monthNamesFaGregorian = [
  'ژانویه', 'فوریه', 'مارس', 'آوریل', 'می', 'ژوئن',
  'ژوئیه', 'اوت', 'سپتامبر', 'اکتبر', 'نوامبر', 'دسامبر'
];

/// صفحه‌ی وضعیت ده روز آینده آب‌وهوا (از فردا شروع می‌شود)
class TenDayForecastScreen extends StatelessWidget {
  final WeatherLocation location;
  final WeatherData data;

  const TenDayForecastScreen({super.key, required this.location, required this.data});

  @override
  Widget build(BuildContext context) {
    final days = data.next10DaysForecast;

    return Scaffold(
      appBar: AppBar(title: Text('وضعیت هوای ده روز آینده ${location.name}')),
      body: days.isEmpty
          ? const Center(child: Text('پیش‌بینی ده روز آینده در دسترس نیست'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: days.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final f = days[index];
                final weekday = _weekdayNamesFa[f.date.weekday - 1];
                final dateStr =
                    '${_toPersianDigits(f.date.day.toString())} ${_monthNamesFaGregorian[f.date.month - 1]}';
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ردیف اول: تاریخ، حالت ابرها، احتمال بارش، رطوبت
                      Row(
                        children: [
                          SizedBox(
                            width: 84,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(weekday, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text(dateStr, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                          Text(f.iconEmoji, style: const TextStyle(fontSize: 26)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              WeatherData.descriptionForCode(f.weatherCode),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Icon(Icons.grain, size: 16, color: Colors.blue.shade400),
                          const SizedBox(width: 2),
                          Text('${_toPersianDigits(f.precipitationProbability.toString())}%',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                          const SizedBox(width: 10),
                          Icon(Icons.water_drop, size: 16, color: Colors.blue.shade400),
                          const SizedBox(width: 2),
                          Text('${_toPersianDigits(f.humidity.toString())}%',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      // ردیف دوم: حداقل و حداکثر دما، شاخص UV
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_toPersianDigits(f.minTemp.round().toString())}° / ${_toPersianDigits(f.maxTemp.round().toString())}°',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Row(
                            children: [
                              Icon(Icons.wb_sunny, size: 16, color: Colors.orange.shade400),
                              const SizedBox(width: 2),
                              Text('UV ${_toPersianDigits(f.uvIndex.round().toString())}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
