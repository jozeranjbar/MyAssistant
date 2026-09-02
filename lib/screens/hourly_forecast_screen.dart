import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

/// یک گرادیانِ رنگی متناسب با ساعت روز (برای ظاهر رنگی و زیبای هر کارتِ ساعتی)
LinearGradient _gradientForHour(int hour) {
  if (hour >= 5 && hour < 9) {
    // سپیده‌دم
    return const LinearGradient(colors: [Color(0xFFFFE29A), Color(0xFFFFA9A3)]);
  } else if (hour >= 9 && hour < 16) {
    // روز
    return const LinearGradient(colors: [Color(0xFF6EC6FF), Color(0xFF4FA8D8)]);
  } else if (hour >= 16 && hour < 19) {
    // غروب
    return const LinearGradient(colors: [Color(0xFFF2A93C), Color(0xFFE0729A)]);
  } else {
    // شب
    return const LinearGradient(colors: [Color(0xFF3949AB), Color(0xFF1A237E)]);
  }
}

/// صفحه‌ی وضعیت هوای ساعتی: از همین الان تا ۲۴ ساعت آینده
class HourlyForecastScreen extends StatelessWidget {
  final WeatherLocation location;
  final WeatherData data;

  const HourlyForecastScreen({super.key, required this.location, required this.data});

  @override
  Widget build(BuildContext context) {
    final hours = data.next24HoursForecast;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.indigo.shade100,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_forward_ios, color: Colors.indigo.shade700, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        centerTitle: true,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'وضعیت هوای ساعتی ${location.name}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.indigo.shade900,
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
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFE8EEFB), Color(0xFFFDF3E6)],
            ),
          ),
          child: hours.isEmpty
              ? const Center(child: Text('پیش‌بینی ساعتی در دسترس نیست'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: hours.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final h = hours[index];
                    final isNow = index == 0;
                    final jalali = Jalali.fromDateTime(h.dateTime);
                    final showDateLabel =
                        index == 0 || (index > 0 && !_sameJalaliDay(jalali, Jalali.fromDateTime(hours[index - 1].dateTime)));
                    final weekday = _weekdayNamesFa[h.dateTime.weekday - 1];
                    final dateStr = '$weekday ${_toPersianDigits(jalali.day.toString())} ${jalali.formatter.mN}';
                    final gradient = _gradientForHour(h.dateTime.hour);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showDateLabel) ...[
                          if (index != 0) const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(dateStr,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.brown.shade700)),
                          ),
                          const SizedBox(height: 6),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            gradient: gradient,
                            borderRadius: BorderRadius.circular(16),
                            border: isNow ? Border.all(color: Colors.white, width: 2.5) : null,
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 64,
                                child: Text(
                                  isNow ? 'اکنون' : _toPersianDigits(DateFormat('HH:mm').format(h.dateTime)),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                                ),
                              ),
                              Text(h.iconEmoji, style: const TextStyle(fontSize: 26)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  WeatherData.descriptionForCode(h.weatherCode),
                                  style: const TextStyle(fontSize: 14, color: Colors.white),
                                ),
                              ),
                              _HourStatChip(icon: Icons.water_drop, value: '${_toPersianDigits(h.humidity.toString())}%'),
                              const SizedBox(width: 10),
                              _HourStatChip(
                                  icon: Icons.grain, value: '${_toPersianDigits(h.precipitationProbability.toString())}%'),
                              const SizedBox(width: 12),
                              Text(
                                '${_toPersianDigits(h.temperature.round().toString())}°',
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }

  bool _sameJalaliDay(Jalali a, Jalali b) => a.year == b.year && a.month == b.month && a.day == b.day;
}

class _HourStatChip extends StatelessWidget {
  final IconData icon;
  final String value;

  const _HourStatChip({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.white),
        const SizedBox(width: 2),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }
}
