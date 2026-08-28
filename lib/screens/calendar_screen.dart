import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';
import '../services/events_service.dart';
import '../services/custom_holiday_storage_service.dart';
import '../data/iranian_holidays.dart';

String _toPersianDigits(String input) {
  const western = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

  var result = input;

  for (var i = 0; i < western.length; i++) {
    result = result.replaceAll(western[i], persian[i]);
  }

  return result;
}

/// اطلاعات تعطیلی یک روز مشخص
class _HolidayInfo {
  final bool isHoliday;
  final List<String> titles;

  const _HolidayInfo(this.isHoliday, this.titles);
}

_HolidayInfo _checkHoliday(
  Jalali jDate,
  HijriCalendar hijri,
  List<CustomHoliday> customHolidays,
) {
  final titles = <String>[];

  // جمعه
  if (jDate.weekDay == 7) {
    titles.add('جمعه');
  }

  // تعطیلات شمسی
  for (final h in solarHolidays) {
    if (h.month == jDate.month && h.day == jDate.day) {
      titles.add(h.title);
    }
  }

  // تعطیلات قمری
  for (final h in lunarHolidays) {
    if (h.month == hijri.hMonth && h.day == hijri.hDay) {
      titles.add(h.title);
    }
  }

  // مناسبت‌های سفارشی
  for (final h in customHolidays) {
    if (h.type == CustomHolidayType.solar &&
        h.month == jDate.month &&
        h.day == jDate.day) {
      titles.add(h.title);
    } else if (h.type == CustomHolidayType.lunar &&
        h.month == hijri.hMonth &&
        h.day == hijri.hDay) {
      titles.add(h.title);
    }
  }

  return _HolidayInfo(
    titles.isNotEmpty,
    titles,
  );
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  String _mode = 'year';

  final _eventsService = EventsService();
  final _customHolidayService = CustomHolidayStorageService();

  List<CustomHoliday> _customHolidays = [];

  @override
  void initState() {
    super.initState();
    _loadCustomHolidays();
  }

  Future<void> _loadCustomHolidays() async {
    final items = await _customHolidayService.loadCustomHolidays();

    if (!mounted) return;

    setState(() {
      _customHolidays = items;
    });
  }

  /// مدیریت مناسبت‌های سفارشی
  Future<void> _manageCustomHolidays() async {
    final titleController = TextEditingController();
    final monthController = TextEditingController();
    final dayController = TextEditingController();

    CustomHolidayType selectedType = CustomHolidayType.solar;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> refreshHolidays() async {
              final items =
                  await _customHolidayService.loadCustomHolidays();

              if (!mounted) return;

              setState(() {
                _customHolidays = items;
              });

              setModalState(() {});
            }

            return AlertDialog(
              title: const Text('بروزرسانی مناسبت‌ها'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_customHolidays.isNotEmpty) ...[
                      const Text(
                        'مناسبت‌های سفارشی فعلی:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),

                      ..._customHolidays.map(
                        (h) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(h.title),
                          subtitle: Text(
                            '${h.type == CustomHolidayType.solar ? 'شمسی' : 'قمری'} - '
                            '${_toPersianDigits(h.day.toString())} '
                            '${h.type == CustomHolidayType.solar ? '' : hijriMonthNamesFa[h.month - 1]}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.red,
                            ),
                            onPressed: () async {
                              await _customHolidayService
                                  .removeCustomHoliday(h.id);

                              await refreshHolidays();
                            },
                          ),
                        ),
                      ),

                      const Divider(height: 20),
                    ],

                    const Text(
                      'افزودن مناسبت جدید:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<CustomHolidayType>(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: const Text('شمسی'),
                            value: CustomHolidayType.solar,
                            groupValue: selectedType,
                            onChanged: (value) {
                              if (value == null) return;

                              setModalState(() {
                                selectedType = value;
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<CustomHolidayType>(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: const Text('قمری'),
                            value: CustomHolidayType.lunar,
                            groupValue: selectedType,
                            onChanged: (value) {
                              if (value == null) return;

                              setModalState(() {
                                selectedType = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: monthController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'ماه (۱ تا ۱۲)',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: dayController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'روز',
                            ),
                          ),
                        ),
                      ],
                    ),

                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'عنوان مناسبت',
                      ),
                    ),
                  ],
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('بستن'),
                ),

                ElevatedButton(
                  onPressed: () async {
                    final month =
                        int.tryParse(monthController.text.trim());

                    final day =
                        int.tryParse(dayController.text.trim());

                    final title =
                        titleController.text.trim();

                    // اعتبارسنجی اولیه
                    if (month == null ||
                        day == null ||
                        title.isEmpty ||
                        month < 1 ||
                        month > 12 ||
                        day < 1) {
                      return;
                    }

                    // تعیین تعداد روزهای مجاز ماه
                    int maxDay;

                    if (selectedType == CustomHolidayType.solar) {
                      if (month <= 6) {
                        // فروردین تا شهریور
                        maxDay = 31;
                      } else if (month <= 11) {
                        // مهر تا بهمن
                        maxDay = 30;
                      } else {
                        // اسفند
                        // monthLength خودش سال کبیسه را تشخیص می‌دهد.
                        final currentYear = Jalali.now().year;

                        maxDay = Jalali(
                          currentYear,
                          12,
                          1,
                        ).monthLength;
                      }
                    } else {
                      // ماه قمری حداکثر ۳۰ روز دارد.
                      maxDay = 30;
                    }

                    if (day > maxDay) {
                      return;
                    }

                    await _customHolidayService.addCustomHoliday(
                      CustomHoliday(
                        id: DateTime.now()
                            .millisecondsSinceEpoch
                            .toString(),
                        type: selectedType,
                        month: month,
                        day: day,
                        title: title,
                      ),
                    );

                    titleController.clear();
                    monthController.clear();
                    dayController.clear();

                    await refreshHolidays();
                  },
                  child: const Text('افزودن'),
                ),
              ],
            );
          },
        );
      },
    );

    // آزاد کردن Controllerها
    titleController.dispose();
    monthController.dispose();
    dayController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تقویم کامل 🗓️'),
        actions: [
          IconButton(
            icon: const Icon(Icons.event_repeat),
            tooltip: 'بروزرسانی مناسبت‌ها',
            onPressed: _manageCustomHolidays,
          ),
        ],
      ),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              10,
              16,
              6,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _ModeButton(
                  label: 'تقویم سال',
                  selected: _mode == 'year',
                  onTap: () {
                    setState(() {
                      _mode = 'year';
                    });
                  },
                ),

                const SizedBox(width: 8),

                _ModeButton(
                  label: 'مناسبت‌ها',
                  selected: _mode == 'events',
                  onTap: () {
                    setState(() {
                      _mode = 'events';
                    });
                  },
                ),
              ],
            ),
          ),

          Expanded(
            child: _mode == 'year'
                ? _YearCalendarView(
                    customHolidays: _customHolidays,
                    eventsService: _eventsService,
                  )
                : _EventsListView(
                    eventsService: _eventsService,
                  ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? Colors.purple
          : Colors.purple.shade50,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 9,
            horizontal: 16,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : Colors.purple,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

/// ------------------ نمای تقویم سال ------------------

class _YearCalendarView extends StatelessWidget {
  final List<CustomHoliday> customHolidays;
  final EventsService eventsService;

  const _YearCalendarView({
    required this.customHolidays,
    required this.eventsService,
  });

  @override
  Widget build(BuildContext context) {
    final today = Jalali.now();
    final months = List.generate(12, (i) => i + 1);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),

              const Text(
                'تاریخ سبز رنگ، تاریخ امروز است و',
                style: TextStyle(fontSize: 12),
              ),

              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),

              const Text(
                'تاریخ‌های قرمز، تعطیلات رسمی هستند. '
                'برای دیدن جزئیات، روی هر روز بزنید.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        ...months.map(
          (m) => _MonthBlock(
            year: today.year,
            month: m,
            today: today,
            customHolidays: customHolidays,
            eventsService: eventsService,
          ),
        ),
      ],
    );
  }
}

class _MonthBlock extends StatelessWidget {
  final int year;
  final int month;
  final Jalali today;
  final List<CustomHoliday> customHolidays;
  final EventsService eventsService;

  const _MonthBlock({
    required this.year,
    required this.month,
    required this.today,
    required this.customHolidays,
    required this.eventsService,
  });

  static const _weekdayHeaders = [
    'ش',
    'ی',
    'د',
    'س',
    'چ',
    'پ',
    'ج',
  ];

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = Jalali(
      year,
      month,
      1,
    );

    final daysInMonth =
        firstOfMonth.monthLength;

    final firstWeekday =
        firstOfMonth.weekDay;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(
                vertical: 8,
                horizontal: 20,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF7B1FA2),
                    Color(0xFFE91E8C),
                  ],
                ),
                borderRadius:
                    BorderRadius.circular(24),
              ),
              child: Text(
                '${firstOfMonth.formatter.mN} '
                '${_toPersianDigits(year.toString())}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          Row(
            children: _weekdayHeaders
                .map(
                  (w) => Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 2,
                      ),
                      padding:
                          const EdgeInsets.symmetric(
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: w == 'ج'
                            ? Colors.red.shade50
                            : Colors
                                .deepPurple
                                .shade50,
                        borderRadius:
                            BorderRadius.circular(8),
                      ),
                      child: Text(
                        w,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),

          const SizedBox(height: 4),

          GridView.builder(
            shrinkWrap: true,
            physics:
                const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.6,
              mainAxisSpacing: 1,
              crossAxisSpacing: 1,
            ),
            itemCount:
                daysInMonth +
                (firstWeekday - 1),

            itemBuilder: (context, index) {
              if (index < firstWeekday - 1) {
                return const SizedBox();
              }

              final day =
                  index -
                  (firstWeekday - 1) +
                  1;

              final jDate = Jalali(
                year,
                month,
                day,
              );

              final gDate =
                  jDate.toDateTime();

              final hijri =
                  HijriCalendar.fromDate(
                gDate,
              );

              final holidayInfo =
                  _checkHoliday(
                jDate,
                hijri,
                customHolidays,
              );

              final isToday =
                  jDate.year == today.year &&
                  jDate.month == today.month &&
                  jDate.day == today.day;

              final bg = isToday
                  ? Colors.green.shade200
                  : holidayInfo.isHoliday
                      ? Colors.red.shade50
                      : Colors.grey.shade100;

              final fg = isToday
                  ? Colors.green.shade900
                  : holidayInfo.isHoliday
                      ? Colors.red.shade700
                      : Colors.black87;

              return GestureDetector(
                onTap: () => _showDayDetail(
                  context,
                  jDate,
                  gDate,
                  hijri,
                  holidayInfo,
                ),

                child: Container(
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius:
                        BorderRadius.circular(4),
                  ),

                  padding:
                      const EdgeInsets.symmetric(
                    vertical: 1,
                  ),

                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [

                      // تاریخ شمسی
                      Text(
                        '${holidayInfo.isHoliday ? '•' : ''}'
                        '${_toPersianDigits(day.toString())}',
                        style: TextStyle(
                          fontWeight:
                              FontWeight.bold,
                          fontSize: 14,
                          color: fg,
                        ),
                      ),

                      // تاریخ میلادی
                      Text(
                        DateFormat('MMM d')
                            .format(gDate),
                        style: TextStyle(
                          fontSize: 9,
                          color: fg.withOpacity(0.8),
                        ),
                      ),

                      // تاریخ قمری
                      Text(
                        '${_toPersianDigits(hijri.hDay.toString())} '
                        '${hijriMonthNamesFa[hijri.hMonth - 1]}',
                        style: TextStyle(
                          fontSize: 9,
                          color: fg.withOpacity(0.8),
                        ),
                        overflow:
                            TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showDayDetail(
    BuildContext context,
    Jalali jDate,
    DateTime gDate,
    HijriCalendar hijri,
    _HolidayInfo holidayInfo,
  ) async {
    const weekdays = [
      'شنبه',
      'یکشنبه',
      'دوشنبه',
      'سه‌شنبه',
      'چهارشنبه',
      'پنجشنبه',
      'جمعه',
    ];

    // استفاده از همان EventsService
    final events =
        await eventsService.getEventsForJalali(
      jDate,
    );

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(20),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.deepPurple.shade50,
                  Colors.pink.shade50,
                ],
              ),
            ),

            padding:
                const EdgeInsets.all(18),

            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        weekdays[
                            jDate.weekDay - 1],
                        style: TextStyle(
                          fontWeight:
                              FontWeight.bold,
                          fontSize: 19,
                          color: Colors
                              .deepPurple
                              .shade700,
                        ),
                      ),
                    ),

                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: Colors
                            .deepPurple
                            .shade400,
                      ),
                      onPressed: () =>
                          Navigator.of(
                            dialogContext,
                          ).pop(),
                    ),
                  ],
                ),

                Text(
                  'شمسی: '
                  '${_toPersianDigits(jDate.day.toString())} '
                  '${jDate.formatter.mN} '
                  '${_toPersianDigits(jDate.year.toString())}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.bold,
                    color:
                        Colors.blue.shade800,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  'میلادی: '
                  '${DateFormat('d MMMM y').format(gDate)}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.bold,
                    color:
                        Colors.teal.shade700,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  'قمری: '
                  '${_toPersianDigits(hijri.hDay.toString())} '
                  '${hijriMonthNamesFa[hijri.hMonth - 1]} '
                  '${_toPersianDigits(hijri.hYear.toString())}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.bold,
                    color:
                        Colors.orange.shade800,
                  ),
                ),

                Divider(
                  height: 26,
                  color:
                      Colors.deepPurple.shade100,
                ),

                if (holidayInfo.isHoliday)
                  ...holidayInfo.titles.map(
                    (t) => Padding(
                      padding:
                          const EdgeInsets.only(
                        bottom: 4,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.circle,
                            size: 8,
                            color: Colors.red,
                          ),

                          const SizedBox(width: 6),

                          Expanded(
                            child: Text(
                              t,
                              style: TextStyle(
                                color: Colors
                                    .red
                                    .shade700,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (events.isEmpty &&
                    !holidayInfo.isHoliday)
                  const Text(
                    'مناسبتی برای این روز ثبت نشده است.',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  )
                else
                  ...events.map(
                    (e) => Padding(
                      padding:
                          const EdgeInsets.only(
                        bottom: 4,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            e.isPublic
                                ? Icons.circle
                                : Icons.star,
                            size: e.isPublic
                                ? 8
                                : 14,
                            color: e.isPublic
                                ? Colors.grey
                                : Colors.purple,
                          ),

                          const SizedBox(width: 6),

                          Expanded(
                            child: Text(
                              e.title,
                              style: TextStyle(
                                color: e.isPublic
                                    ? Colors.black87
                                    : Colors
                                        .purple
                                        .shade700,
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// ------------------ نمای لیست مناسبت‌ها ------------------

class _EventsListView extends StatefulWidget {
  final EventsService eventsService;

  const _EventsListView({
    required this.eventsService,
  });

  @override
  State<_EventsListView> createState() =>
      _EventsListViewState();
}

class _EventsListViewState
    extends State<_EventsListView> {
  List<CalendarEvent> _events = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final events =
        await widget.eventsService.getAllEvents();

    if (!mounted) return;

    setState(() {
      _events = events;
      _loading = false;
    });
  }

  Future<void> _addEvent() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate:
          DateTime(now.year - 1),
      lastDate:
          DateTime(now.year + 5),
    );

    if (picked == null || !mounted) {
      return;
    }

    final titleController =
        TextEditingController();

    final jPicked =
        Jalali.fromDateTime(picked);

    final hPicked =
        HijriCalendar.fromDate(picked);

    await showDialog(
      context: context,
      builder: (dialogContext) =>
          AlertDialog(
        backgroundColor:
            Colors.green.shade50,

        title:
            const Text('مناسبت جدید'),

        content: Column(
          mainAxisSize:
              MainAxisSize.min,
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'شمسی: '
              '${_toPersianDigits(jPicked.day.toString())} '
              '${jPicked.formatter.mN} '
              '${_toPersianDigits(jPicked.year.toString())}',
            ),

            const SizedBox(height: 4),

            Text(
              'میلادی: '
              '${DateFormat('d MMMM y').format(picked)}',
            ),

            const SizedBox(height: 4),

            Text(
              'قمری: '
              '${_toPersianDigits(hPicked.hDay.toString())} '
              '${hijriMonthNamesFa[hPicked.hMonth - 1]} '
              '${_toPersianDigits(hPicked.hYear.toString())}',
            ),

            const SizedBox(height: 12),

            TextField(
              controller: titleController,
              autofocus: true,
              decoration:
                  const InputDecoration(
                hintText:
                    'عنوان مناسبت',
                filled: true,
                fillColor:
                    Colors.white,
              ),
            ),
          ],
        ),

        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(
              dialogContext,
            ),
            child:
                const Text('انصراف'),
          ),

          ElevatedButton(
            onPressed: () async {
              if (titleController
                  .text
                  .trim()
                  .isEmpty) {
                return;
              }

              await widget.eventsService
                  .addPrivateEvent(
                jPicked,
                titleController
                    .text
                    .trim(),
              );

              if (dialogContext
                  .mounted) {
                Navigator.pop(
                  dialogContext,
                );
              }

              await _load();
            },
            child:
                const Text('افزودن'),
          ),
        ],
      ),
    );

    // آزاد کردن Controller
    titleController.dispose();
  }

  Future<void> _deleteEvent(
    CalendarEvent e,
  ) async {
    if (e.isPublic) {
      await widget.eventsService
          .hidePublicEvent(
        e.month,
        e.day,
        e.title,
      );
    } else if (e.id != null) {
      await widget.eventsService
          .removePrivateEvent(
        e.id!,
      );
    }

    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    return Container(
      color: Colors.pink.shade50,
      child: Stack(
        children: [
          _events.isEmpty
              ? const Center(
                  child: Text(
                    'هیچ مناسبتی ثبت نشده است.',
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.only(
                    bottom: 80,
                  ),
                  itemCount:
                      _events.length,
                  itemBuilder:
                      (context, index) {
                    final e =
                        _events[index];

                    return ListTile(
                      leading: Icon(
                        e.isPublic
                            ? Icons.public
                            : Icons.star,
                        color: e.isPublic
                            ? Colors.grey
                            : Colors.purple,
                      ),

                      title:
                          Text(e.title),

                      subtitle: Text(
                        '${_toPersianDigits(e.day.toString())} '
                        '${Jalali(1400, e.month, 1).formatter.mN}'
                        '${e.year != null ? ' ${_toPersianDigits(e.year.toString())}' : ''}',
                      ),

                      trailing:
                          IconButton(
                        icon:
                            const Icon(
                          Icons.delete,
                          color:
                              Colors.red,
                        ),
                        onPressed: () =>
                            _deleteEvent(e),
                      ),
                    );
                  },
                ),

          Positioned(
            right: 16,
            bottom: 16,
            child:
                FloatingActionButton.extended(
              onPressed: _addEvent,
              icon:
                  const Icon(Icons.add),
              label: const Text(
                'مناسبت جدید',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
