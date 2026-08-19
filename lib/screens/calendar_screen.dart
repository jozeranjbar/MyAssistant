import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  Map<String, List<String>> _events = {}; // key: yyyy-MM-dd میلادی

  static const _key = 'calendar_events_v1';

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  String _dateKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  Future<void> _loadEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        _events = map.map((k, v) => MapEntry(k, List<String>.from(v)));
      });
    }
  }

  Future<void> _saveEvents() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_events));
  }

  Future<void> _addEvent(String title) async {
    final key = _dateKey(_selectedDay);
    setState(() {
      _events.putIfAbsent(key, () => []).add(title);
    });
    await _saveEvents();
  }

  String _shamsiString(DateTime date) {
    final jalali = Jalali.fromDateTime(date);
    const weekdays = ['شنبه', 'یکشنبه', 'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنجشنبه', 'جمعه'];
    return '${weekdays[jalali.weekDay - 1]}، ${jalali.day} ${jalali.formatter.mN} ${jalali.year}';
  }

  void _showAddEventDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('افزودن مناسبت'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'عنوان رویداد'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                _addEvent(controller.text.trim());
              }
              Navigator.pop(context);
            },
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final todayEvents = _events[_dateKey(_selectedDay)] ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('تقویم')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddEventDialog,
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_shamsiString(_selectedDay),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (todayEvents.isEmpty)
                    const Text('امروز رویداد یا برنامه‌ای ثبت نشده است.')
                  else
                    ...todayEvents.map((e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.event, size: 18, color: Colors.green),
                              const SizedBox(width: 8),
                              Expanded(child: Text(e)),
                            ],
                          ),
                        )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SimpleMonthGrid(
            focusedDay: _focusedDay,
            selectedDay: _selectedDay,
            events: _events,
            dateKeyBuilder: _dateKey,
            onDaySelected: (day) => setState(() => _selectedDay = day),
            onMonthChanged: (day) => setState(() => _focusedDay = day),
          ),
        ],
      ),
    );
  }
}

/// یک گرید ساده ماهانه بر پایه تقویم شمسی (جایگزین سبک برای table_calendar
/// در مواردی که نیاز به تقویم شمسی کامل باشد).
class _SimpleMonthGrid extends StatelessWidget {
  final DateTime focusedDay;
  final DateTime selectedDay;
  final Map<String, List<String>> events;
  final String Function(DateTime) dateKeyBuilder;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onMonthChanged;

  const _SimpleMonthGrid({
    required this.focusedDay,
    required this.selectedDay,
    required this.events,
    required this.dateKeyBuilder,
    required this.onDaySelected,
    required this.onMonthChanged,
  });

  @override
  Widget build(BuildContext context) {
    final jFocused = Jalali.fromDateTime(focusedDay);
    final firstOfMonth = Jalali(jFocused.year, jFocused.month, 1);
    final daysInMonth = firstOfMonth.monthLength;
    final firstWeekday = firstOfMonth.weekDay; // 1=شنبه ... 7=جمعه

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => onMonthChanged(jFocused.addMonths(-1).toDateTime()),
            ),
            Text('${jFocused.formatter.mN} ${jFocused.year}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => onMonthChanged(jFocused.addMonths(1).toDateTime()),
            ),
          ],
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
          itemCount: daysInMonth + (firstWeekday - 1),
          itemBuilder: (context, index) {
            if (index < firstWeekday - 1) return const SizedBox();
            final day = index - (firstWeekday - 1) + 1;
            final jDate = Jalali(jFocused.year, jFocused.month, day);
            final gDate = jDate.toDateTime();
            final hasEvent = events.containsKey(dateKeyBuilder(gDate));
            final isSelected = dateKeyBuilder(gDate) == dateKeyBuilder(selectedDay);

            return GestureDetector(
              onTap: () => onDaySelected(gDate),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.green : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$day',
                          style: TextStyle(color: isSelected ? Colors.white : Colors.black)),
                      if (hasEvent)
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
