import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';
import '../services/events_service.dart';
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

/// اطلاعات تعطیلی یک روز مشخص شمسی (بررسی جمعه، تعطیلات شمسی و قمری)
class _HolidayInfo {
  final bool isHoliday;
  final List<String> titles;
  final bool hasLunar;
  const _HolidayInfo(this.isHoliday, this.titles, this.hasLunar);
}

_HolidayInfo _checkHoliday(Jalali jDate, HijriCalendar hijri) {
  final titles = <String>[];
  var hasLunar = false;

  if (jDate.weekDay == 7) {
    titles.add('جمعه');
  }
  for (final h in solarHolidays) {
    if (h.month == jDate.month && h.day == jDate.day) titles.add(h.title);
  }
  for (final h in lunarHolidays) {
    if (h.month == hijri.hMonth && h.day == hijri.hDay) {
      titles.add(h.title);
      hasLunar = true;
    }
  }
  return _HolidayInfo(titles.isNotEmpty, titles, hasLunar);
}

/// انتخاب‌گر تاریخ شمسی ساده (سه فهرست کشویی روز/ماه/سال) به‌جای تقویم
/// میلادی پیش‌فرض فلاتر.
Future<Jalali?> showJalaliDatePicker(BuildContext context, {Jalali? initial}) {
  final now = initial ?? Jalali.now();
  int selectedYear = now.year;
  int selectedMonth = now.month;
  int selectedDay = now.day;

  return showDialog<Jalali>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          final daysInMonth = Jalali(selectedYear, selectedMonth, 1).monthLength;
          if (selectedDay > daysInMonth) selectedDay = daysInMonth;

          return AlertDialog(
            backgroundColor: Colors.deepPurple.shade50,
            title: const Text('انتخاب تاریخ', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: selectedDay,
                    items: List.generate(daysInMonth, (i) => i + 1)
                        .map((d) => DropdownMenuItem(value: d, child: Text(_toPersianDigits(d.toString()))))
                        .toList(),
                    onChanged: (v) => setModalState(() => selectedDay = v!),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: selectedMonth,
                    items: List.generate(12, (i) => i + 1)
                        .map((m) => DropdownMenuItem(value: m, child: Text(Jalali(selectedYear, m, 1).formatter.mN)))
                        .toList(),
                    onChanged: (v) => setModalState(() => selectedMonth = v!),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: selectedYear,
                    items: List.generate(8, (i) => now.year - 1 + i)
                        .map((y) => DropdownMenuItem(value: y, child: Text(_toPersianDigits(y.toString()))))
                        .toList(),
                    onChanged: (v) => setModalState(() => selectedYear = v!),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('انصراف')),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, Jalali(selectedYear, selectedMonth, selectedDay)),
                child: const Text('تأیید'),
              ),
            ],
          );
        },
      );
    },
  );
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  String _mode = 'year'; // 'year' یا 'events'
  final _eventsService = EventsService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تقویم کامل 🗓️'),
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0).abs() > 200) {
            Navigator.of(context).maybePop();
          }
        },
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  _ModeButton(
                    label: 'تقویم سال',
                    selected: _mode == 'year',
                    onTap: () => setState(() => _mode = 'year'),
                  ),
                  const SizedBox(width: 8),
                  _ModeButton(
                    label: 'مناسبت‌ها',
                    selected: _mode == 'events',
                    onTap: () => setState(() => _mode = 'events'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _mode == 'year'
                  ? const _YearCalendarView()
                  : _EventsListView(eventsService: _eventsService),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ModeButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.purple : Colors.purple.shade50,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 16),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : Colors.purple,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

/// ------------------ نمای تقویم سال (۱۲ ماه) ------------------

class _YearCalendarView extends StatelessWidget {
  const _YearCalendarView();

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
              Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
              const Text('تاریخ سبز رنگ، تاریخ امروز است و', style: TextStyle(fontSize: 12)),
              Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
              const Text('تاریخ‌های قرمز، تعطیلات رسمی هستند. برای دیدن جزئیات، روی هر روز بزنید.',
                  style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...months.map((m) => _MonthBlock(year: today.year, month: m, today: today)),
      ],
    );
  }
}

class _MonthBlock extends StatelessWidget {
  final int year;
  final int month;
  final Jalali today;
  const _MonthBlock({required this.year, required this.month, required this.today});

  static const _weekdayHeaders = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج']; // شنبه تا جمعه

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = Jalali(year, month, 1);
    final daysInMonth = firstOfMonth.monthLength;
    final firstWeekday = firstOfMonth.weekDay; // 1=شنبه ... 7=جمعه

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF7B1FA2), Color(0xFFE91E8C)]),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                '${firstOfMonth.formatter.mN} ${_toPersianDigits(year.toString())}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: _weekdayHeaders
                .map((w) => Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: w == 'ج' ? Colors.red.shade50 : Colors.deepPurple.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(w, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 4),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.35,
              mainAxisSpacing: 1,
              crossAxisSpacing: 1,
            ),
            itemCount: daysInMonth + (firstWeekday - 1),
            itemBuilder: (context, index) {
              if (index < firstWeekday - 1) return const SizedBox();
              final day = index - (firstWeekday - 1) + 1;
              final jDate = Jalali(year, month, day);
              final gDate = jDate.toDateTime();
              final hijri = HijriCalendar.fromDate(gDate);
              final holidayInfo = _checkHoliday(jDate, hijri);
              final isToday = jDate.year == today.year && jDate.month == today.month && jDate.day == today.day;

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
                onTap: () => _showDayDetail(context, jDate, gDate, hijri, holidayInfo),
                child: Container(
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _toPersianDigits(day.toString()),
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: fg),
                      ),
                      Text(DateFormat('MMM d').format(gDate),
                          style: TextStyle(fontSize: 10, color: fg.withOpacity(0.8))),
                      Text(
                        '${_toPersianDigits(hijri.hDay.toString())} ${hijriMonthNamesFa[hijri.hMonth - 1]}',
                        style: TextStyle(fontSize: 10, color: fg.withOpacity(0.8)),
                        overflow: TextOverflow.ellipsis,
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
    const weekdays = ['شنبه', 'یکشنبه', 'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنجشنبه', 'جمعه'];
    final events = await EventsService().getEventsForJalali(jDate);

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.deepPurple.shade50, Colors.pink.shade50],
              ),
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(weekdays[jDate.weekDay - 1],
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 19, color: Colors.deepPurple.shade700)),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.deepPurple.shade400),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ],
                ),
                Text(
                  'شمسی: ${_toPersianDigits(jDate.day.toString())} ${jDate.formatter.mN} ${_toPersianDigits(jDate.year.toString())}',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                ),
                const SizedBox(height: 6),
                Text('میلادی: ${DateFormat('d MMMM y').format(gDate)}',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.teal.shade700)),
                const SizedBox(height: 6),
                Text(
                  'قمری: ${_toPersianDigits(hijri.hDay.toString())} ${hijriMonthNamesFa[hijri.hMonth - 1]} ${_toPersianDigits(hijri.hYear.toString())}',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.orange.shade800),
                ),
                Divider(height: 26, color: Colors.deepPurple.shade100),
                if (holidayInfo.isHoliday) ...[
                  ...holidayInfo.titles.map((t) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.circle, size: 8, color: Colors.red),
                            const SizedBox(width: 6),
                            Expanded(
                                child: Text(t,
                                    style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold))),
                          ],
                        ),
                      )),
                  if (holidayInfo.hasLunar)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'تاریخ‌های قمری بر پایه محاسبه نجومی است و ممکن است با اعلام رسمی یک روز اختلاف داشته باشد.',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ),
                ],
                if (events.isEmpty && !holidayInfo.isHoliday)
                  const Text('مناسبتی برای این روز ثبت نشده است.', style: TextStyle(color: Colors.grey))
                else
                  ...events.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(e.isPublic ? Icons.circle : Icons.star,
                                size: e.isPublic ? 8 : 14,
                                color: e.isPublic ? Colors.grey : Colors.purple),
                            const SizedBox(width: 6),
                            Expanded(
                                child: Text(e.title,
                                    style: TextStyle(
                                        color: e.isPublic ? Colors.black87 : Colors.purple.shade700,
                                        fontWeight: FontWeight.w600))),
                          ],
                        ),
                      )),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// ------------------ نمای لیست مناسبت‌ها (افزودن/حذف) ------------------

class _EventsListView extends StatefulWidget {
  final EventsService eventsService;
  const _EventsListView({required this.eventsService});

  @override
  State<_EventsListView> createState() => _EventsListViewState();
}

class _EventsListViewState extends State<_EventsListView> {
  List<CalendarEvent> _events = [];
  bool _loading = true;
  final _scrollController = ScrollController();
  final Map<String, GlobalKey> _itemKeys = {};
  String? _lastAddedKey;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _eventKey(CalendarEvent e) => e.id ?? '${e.month}-${e.day}-${e.title}';

  Future<void> _load() async {
    final events = await widget.eventsService.getAllEvents();
    if (!mounted) return;
    setState(() {
      _events = events;
      _loading = false;
      _itemKeys.clear();
      for (final e in _events) {
        _itemKeys[_eventKey(e)] = GlobalKey();
      }
    });

    // بعد از رندر شدن لیست، به مناسبتی که تازه اضافه شده اسکرول می‌کنیم
    if (_lastAddedKey != null) {
      final targetKey = _lastAddedKey;
      _lastAddedKey = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final key = _itemKeys[targetKey];
        if (key?.currentContext != null) {
          Scrollable.ensureVisible(
            key!.currentContext!,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            alignment: 0.3,
          );
        }
      });
    }
  }

  Future<void> _addEvent() async {
    final jPicked = await showJalaliDatePicker(context);
    if (jPicked == null || !mounted) return;

    final titleController = TextEditingController();
    final gDate = jPicked.toDateTime();
    final hPicked = HijriCalendar.fromDate(gDate);

    await showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.pink.shade50, Colors.orange.shade50],
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('✨ مناسبت جدید',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple.shade700)),
              const SizedBox(height: 14),
              Text(
                'شمسی: ${_toPersianDigits(jPicked.day.toString())} ${jPicked.formatter.mN} ${_toPersianDigits(jPicked.year.toString())}',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
              ),
              const SizedBox(height: 6),
              Text('میلادی: ${DateFormat('d MMMM y').format(gDate)}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.teal.shade700)),
              const SizedBox(height: 6),
              Text(
                'قمری: ${_toPersianDigits(hPicked.hDay.toString())} ${hijriMonthNamesFa[hPicked.hMonth - 1]} ${_toPersianDigits(hPicked.hYear.toString())}',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.orange.shade800),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                autofocus: true,
                style: const TextStyle(fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: 'عنوان مناسبت',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('انصراف'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple.shade400,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        if (titleController.text.trim().isEmpty) return;
                        await widget.eventsService.addPrivateEvent(jPicked, titleController.text.trim());
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        // شناسه‌ی موقت برای پیدا کردن مناسبت تازه اضافه‌شده بعد از رفرش لیست
                        _lastAddedKey = '${jPicked.month}-${jPicked.day}-${titleController.text.trim()}';
                        await _load();
                      },
                      child: const Text('افزودن', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    titleController.dispose();
  }

  Future<void> _deleteEvent(CalendarEvent e) async {
    if (e.isPublic) {
      await widget.eventsService.hidePublicEvent(e.month, e.day, e.title);
    } else if (e.id != null) {
      await widget.eventsService.removePrivateEvent(e.id!);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Container(
      color: Colors.pink.shade50,
      child: Stack(
        children: [
          _events.isEmpty
              ? const Center(child: Text('هیچ مناسبتی ثبت نشده است.'))
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: _events.length,
                  itemBuilder: (context, index) {
                    final e = _events[index];
                    final isJustAdded = _eventKey(e) == _lastAddedKey;
                    return ListTile(
                      key: _itemKeys[_eventKey(e)],
                      tileColor: isJustAdded ? Colors.yellow.shade100 : null,
                      leading: Icon(e.isPublic ? Icons.public : Icons.star,
                          color: e.isPublic ? Colors.grey : Colors.purple),
                      title: Text(e.title),
                      subtitle: Text(
                          '${_toPersianDigits(e.day.toString())} ${Jalali(1400, e.month, 1).formatter.mN}${e.year != null ? ' ${_toPersianDigits(e.year.toString())}' : ''}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteEvent(e),
                      ),
                    );
                  },
                ),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              onPressed: _addEvent,
              icon: const Icon(Icons.add),
              label: const Text('مناسبت جدید'),
            ),
          ),
        ],
      ),
    );
  }
}
