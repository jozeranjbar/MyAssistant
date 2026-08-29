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

          InputDecoration pickerDecoration() => InputDecoration(
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              );

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFE1D3FF), Color(0xFFFFE0EE), Color(0xFFFFF3D6)],
                ),
                boxShadow: [
                  BoxShadow(color: Colors.deepPurple.withOpacity(0.25), blurRadius: 24, offset: const Offset(0, 10)),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF7B5EA7), Color(0xFF4C93C6)]),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(color: Colors.deepPurple.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 5)),
                        ],
                      ),
                      child: const Text('📅 انتخاب تاریخ',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text('روز', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple.shade700, fontSize: 15)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<int>(
                              isExpanded: true,
                              decoration: pickerDecoration(),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                              value: selectedDay,
                              items: List.generate(daysInMonth, (i) => i + 1)
                                  .map((d) => DropdownMenuItem(value: d, child: Text(_toPersianDigits(d.toString()))))
                                  .toList(),
                              onChanged: (v) => setModalState(() => selectedDay = v!),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: Column(
                          children: [
                            Text('ماه', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.pink.shade700, fontSize: 15)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<int>(
                              isExpanded: true,
                              decoration: pickerDecoration(),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.pink),
                              value: selectedMonth,
                              items: List.generate(12, (i) => i + 1)
                                  .map((m) => DropdownMenuItem(value: m, child: Text(Jalali(selectedYear, m, 1).formatter.mN)))
                                  .toList(),
                              onChanged: (v) => setModalState(() => selectedMonth = v!),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          children: [
                            Text('سال', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade800, fontSize: 15)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<int>(
                              isExpanded: true,
                              decoration: pickerDecoration(),
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange.shade800),
                              value: selectedYear,
                              items: List.generate(8, (i) => now.year - 1 + i)
                                  .map((y) => DropdownMenuItem(value: y, child: Text(_toPersianDigits(y.toString()))))
                                  .toList(),
                              onChanged: (v) => setModalState(() => selectedYear = v!),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('انصراف', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(18),
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF7B5EA7), Color(0xFF4C93C6)]),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(color: Colors.deepPurple.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 5)),
                              ],
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () => Navigator.pop(dialogContext, Jalali(selectedYear, selectedMonth, selectedDay)),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Text('تأیید ✓',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'برای دیدن جزئیات هر روز ، روی آن بزنید',
            style: TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w600),
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
              childAspectRatio: 1.05,
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
                  padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 1),
                  alignment: Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _toPersianDigits(day.toString()),
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: fg),
                        ),
                        const SizedBox(height: 1),
                        Text(DateFormat('MMM d').format(gDate),
                            style: TextStyle(fontSize: 10, color: fg.withOpacity(0.8))),
                        Text(
                          '${_toPersianDigits(hijri.hDay.toString())} ${hijriMonthNamesFa[hijri.hMonth - 1]}',
                          style: TextStyle(fontSize: 10, color: fg.withOpacity(0.8)),
                        ),
                      ],
                    ),
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
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFDE1EC),
                Color(0xFFFFE8CC),
                Color(0xFFE3F3FF),
              ],
            ),
            boxShadow: [
              BoxShadow(color: Colors.purple.withOpacity(0.25), blurRadius: 24, offset: const Offset(0, 10)),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF8E24AA), Color(0xFFEC407A)]),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(color: Colors.pink.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 5)),
                    ],
                  ),
                  child: const Text('✨ مناسبت جدید ✨',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '📅 شمسی: ${_toPersianDigits(jPicked.day.toString())} ${jPicked.formatter.mN} ${_toPersianDigits(jPicked.year.toString())}',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.blue.shade800),
                    ),
                    const SizedBox(height: 10),
                    Text('🌍 میلادی: ${DateFormat('d MMMM y').format(gDate)}',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.teal.shade700)),
                    const SizedBox(height: 10),
                    Text(
                      '🌙 قمری: ${_toPersianDigits(hPicked.hDay.toString())} ${hijriMonthNamesFa[hPicked.hMonth - 1]} ${_toPersianDigits(hPicked.hYear.toString())}',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.orange.shade800),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              TextField(
                controller: titleController,
                autofocus: true,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: Colors.deepPurple),
                decoration: InputDecoration(
                  hintText: 'عنوان مناسبت را بنویسید...',
                  hintStyle: TextStyle(color: Colors.deepPurple.shade200, fontSize: 17),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.deepPurple.shade100, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('انصراف', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF8E24AA), Color(0xFFEC407A)]),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(color: Colors.pink.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 5)),
                          ],
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () async {
                            if (titleController.text.trim().isEmpty) return;
                            await widget.eventsService.addPrivateEvent(jPicked, titleController.text.trim());
                            if (dialogContext.mounted) Navigator.pop(dialogContext);
                            // شناسه‌ی موقت برای پیدا کردن مناسبت تازه اضافه‌شده بعد از رفرش لیست
                            _lastAddedKey = '${jPicked.month}-${jPicked.day}-${titleController.text.trim()}';
                            await _load();
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text('افزودن 🎉',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ),
                      ),
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
                    return Container(
                      key: _itemKeys[_eventKey(e)],
                      margin: isJustAdded ? const EdgeInsets.symmetric(horizontal: 6, vertical: 3) : EdgeInsets.zero,
                      decoration: isJustAdded
                          ? BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.deepOrange.shade300, width: 2),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.orange.withOpacity(0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3)),
                              ],
                            )
                          : null,
                      child: ListTile(
                        leading: Icon(e.isPublic ? Icons.public : Icons.star,
                            color: e.isPublic ? Colors.grey : Colors.purple),
                        title: Text(e.title, style: TextStyle(fontWeight: isJustAdded ? FontWeight.bold : FontWeight.normal)),
                        subtitle: Text(
                            '${_toPersianDigits(e.day.toString())} ${Jalali(1400, e.month, 1).formatter.mN}${e.year != null ? ' ${_toPersianDigits(e.year.toString())}' : ''}'),
                        trailing: isJustAdded
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.deepOrange,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text('جدید',
                                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteEvent(e),
                                  ),
                                ],
                              )
                            : IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteEvent(e),
                              ),
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
