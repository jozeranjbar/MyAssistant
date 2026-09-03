import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:hijri/hijri_calendar.dart';
import '../models/weather_location.dart';
import '../models/weather_data.dart';
import '../models/reminder.dart';
import '../services/weather_service.dart';
import '../services/location_storage_service.dart';
import '../services/reminder_storage_service.dart';
import '../services/chart_storage_service.dart';
import '../services/events_service.dart';
import '../services/widget_service.dart';
import '../data/iranian_holidays.dart';
import '../widgets/weather_card.dart';
import 'weather_settings_screen.dart';
import 'ten_day_forecast_screen.dart';
import 'hourly_forecast_screen.dart';
import 'chart_maker_screen.dart';
import 'calendar_screen.dart';
import 'reminder_screen.dart';
import 'about_screen.dart';
import '../utils/persian_numbers.dart';

// رنگ قهوه‌ای برای نام شهرها
const _kBrownCity = Color(0xFF6D4C29);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _weatherService = WeatherService();
  final _locationStorage = LocationStorageService();
  final _reminderStorage = ReminderStorageService();
  final _chartStorage = ChartStorageService();
  final _eventsService = EventsService();

  List<WeatherLocation> _locations = [];
  final Map<String, WeatherData?> _weatherByLocation = {};
  final Map<String, String?> _errorByLocation = {};
  bool _loading = true;
  int _activeReminderCount = 0;
  List<CalendarEvent> _todayEvents = [];
  List<String> _chartVariables = [];
  List<String> _chartPeople = [];
  final Jalali _today = Jalali.now();

  @override
  void initState() {
    super.initState();
    _loadEverything();
  }

  Future<void> _loadEverything() async {
    final locations = await _locationStorage.loadLocations();
    // بارگذاری فوری از کش (برای نمایش سریع/آفلاین)
    for (final loc in locations) {
      _weatherByLocation[loc.id] = await _locationStorage.getCachedWeather(loc.id);
    }
    final reminders = await _reminderStorage.loadReminders();
    final todayEvents = await _eventsService.getEventsForJalali(_today);
    final chartData = await _chartStorage.load();
    setState(() {
      _locations = locations;
      _activeReminderCount = reminders.where((r) => r.isActive).length;
      _todayEvents = todayEvents;
      _chartVariables = chartData.variables;
      _chartPeople = chartData.individuals;
      _loading = false;
    });
    await _refreshAllWeather();
    await _updateWidget(reminders);
    await _maybePromptAddWidget();
  }

  Future<void> _updateWidget(List<Reminder> reminders) async {
    // تاریخ، روز هفته و تعداد یادآوری‌ها باید همیشه در ویجت نمایش داده شوند،
    // حتی اگر کاربر هنوز هیچ شهری برای آب‌وهوا انتخاب نکرده باشد. فقط نام
    // شهر و دما به وجود لوکیشن بستگی دارند.
    final firstLoc = _locations.isNotEmpty ? _locations.first : null;
    await WidgetService.updateWidgetData(
      location: firstLoc,
      weather: firstLoc != null ? _weatherByLocation[firstLoc.id] : null,
      reminders: reminders,
    );
  }

  Future<void> _maybePromptAddWidget() async {
    final alreadyPrompted = await WidgetService.hasPromptedBefore();
    if (alreadyPrompted || !mounted) return;

    // دیالوگ سفارشی حذف شد؛ فقط تأییدیه‌ی رسمی خود اندروید نمایش داده می‌شود
    // تا کاربر دو بار پشت سر هم پیام نبیند.
    await WidgetService.markPrompted();
    await WidgetService.requestPinWidget();
  }

  Future<void> _refreshAllWeather() async {
    final connectivity = await Connectivity().checkConnectivity();
    final hasInternet = !connectivity.contains(ConnectivityResult.none);

    for (final loc in _locations) {
      if (!hasInternet) {
        continue;
      }
      try {
        final data = await _weatherService.fetchWeather(
          latitude: loc.latitude,
          longitude: loc.longitude,
        );
        await _locationStorage.cacheWeather(loc.id, data);
        if (!mounted) return;
        setState(() {
          _weatherByLocation[loc.id] = data;
          _errorByLocation[loc.id] = null;
        });
      } on WeatherException catch (e) {
        if (!mounted) return;
        setState(() => _errorByLocation[loc.id] = e.message);
      } catch (_) {
        if (!mounted) return;
        setState(() => _errorByLocation[loc.id] = 'خطای غیرمنتظره در دریافت آب‌وهوا');
      }
    }
  }

  Future<void> _openWeatherSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const WeatherSettingsScreen()),
    );
    await _loadEverything();
  }

  Future<void> _openTenDayForecast(WeatherLocation loc) async {
    final data = _weatherByLocation[loc.id];
    if (data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هنوز اطلاعاتی برای این لوکیشن ذخیره نشده است. لطفاً یک بار با اینترنت وصل شوید.')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TenDayForecastScreen(location: loc, data: data)),
    );
  }

  Future<void> _openHourlyForecast(WeatherLocation loc) async {
    final data = _weatherByLocation[loc.id];
    if (data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هنوز اطلاعاتی برای این لوکیشن ذخیره نشده است. لطفاً یک بار با اینترنت وصل شوید.')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HourlyForecastScreen(location: loc, data: data)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bannerHeight = screenWidth / (900 / 171) * 0.68; // ارتفاع کاهش‌یافته بنر

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: bannerHeight,
        titleSpacing: 0,
        flexibleSpace: ClipRect(
          child: OverflowBox(
            maxHeight: screenWidth / (900 / 171),
            child: Image.asset(
              'assets/images/app_banner.jpg',
              width: screenWidth,
              fit: BoxFit.fill,
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshAllWeather,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  // بخش «آب و هوا»: عنوان بیرون از مستطیل + کارت(های) آب‌وهوا + نوار «وضعیت ده روز آینده»
                  // + نوار «تنظیمات آب و هوا»، همگی داخل یک مستطیل واحد
                  _SectionHeader(title: 'آب و هوا', topPadding: 0),
                  Padding(
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green.shade100),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.18),
                            blurRadius: 10,
                            spreadRadius: 1,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_locations.isEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Column(
                                children: [
                                  const Text('هنوز هیچ لوکیشنی اضافه نکرده‌اید.'),
                                  const SizedBox(height: 8),
                                  ElevatedButton(
                                    onPressed: _openWeatherSettings,
                                    child: const Text('افزودن لوکیشن'),
                                  ),
                                ],
                              ),
                            ),
                          ] else
                            ..._locations.map((loc) => Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    if (_locations.indexOf(loc) > 0) const Divider(height: 24),
                                    WeatherCard(
                                      location: loc,
                                      data: _weatherByLocation[loc.id],
                                      loading: _loading,
                                      error: _errorByLocation[loc.id],
                                    ),
                                    const SizedBox(height: 8),
                                    _NavButton(
                                      icon: Icons.access_time,
                                      richLabel: RichText(
                                        textAlign: TextAlign.right,
                                        text: TextSpan(
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.indigo.shade900,
                                          ),
                                          children: [
                                            const TextSpan(text: 'وضعیت هوای ساعتی '),
                                            TextSpan(
                                              text: loc.name,
                                              style: const TextStyle(color: _kBrownCity, fontWeight: FontWeight.w900),
                                            ),
                                          ],
                                        ),
                                      ),
                                      onTap: () => _openHourlyForecast(loc),
                                      backgroundColor: Colors.indigo.shade50,
                                      foregroundColor: Colors.indigo.shade900,
                                      borderColor: const Color(0xFFE6E7FA),
                                      elevated: true,
                                      showArrow: false,
                                    ),
                                    const SizedBox(height: 8),
                                    _NavButton(
                                      icon: Icons.calendar_view_week,
                                      richLabel: RichText(
                                        textAlign: TextAlign.right,
                                        text: TextSpan(
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade900,
                                          ),
                                          children: [
                                            const TextSpan(text: 'وضعیت هوای ده روز آینده '),
                                            TextSpan(
                                              text: loc.name,
                                              style: const TextStyle(color: _kBrownCity, fontWeight: FontWeight.w900),
                                            ),
                                          ],
                                        ),
                                      ),
                                      onTap: () => _openTenDayForecast(loc),
                                      backgroundColor: Colors.blue.shade50,
                                      foregroundColor: Colors.blue.shade900,
                                      borderColor: const Color(0xFFE3F4FC),
                                      elevated: true,
                                      showArrow: false,
                                    ),
                                  ],
                                )),
                          const SizedBox(height: 8),
                          _NavButton(
                            icon: Icons.settings,
                            borderColor: const Color(0xFFF6EDFA),
                            elevated: true,
                            label: 'افزودن مکان ، حذف ، انتقال به بالا',
                            onTap: _openWeatherSettings,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),

                  _SectionHeader(title: 'تقویم'),
                  Padding(
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green.shade100),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.18),
                            blurRadius: 10,
                            spreadRadius: 1,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _TodayCalendarCard(
                            today: _today,
                            events: _todayEvents,
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const CalendarScreen()),
                              );
                              await _loadEverything();
                            },
                          ),
                          const SizedBox(height: 8),
                          _NavButton(
                            icon: Icons.settings,
                            borderColor: const Color(0xFFF6EDFA),
                            elevated: true,
                            label: 'تنظیمات و مشاهده تقویم سال',
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const CalendarScreen()),
                              );
                              await _loadEverything();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),

                  _SectionHeader(title: 'یادآوری'),
                  Padding(
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green.shade100),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.18),
                            blurRadius: 10,
                            spreadRadius: 1,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _NavButton(
                            emoji: '🔔',
                            emoji2: '💊',
                            label: _activeReminderCount == 0
                                ? 'یادآوری ثبت نشده است'
                                : '$_activeReminderCount یادآوری فعال',
                            backgroundColor: Colors.green.shade50,
                            foregroundColor: Colors.green.shade900,
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const ReminderScreen()),
                              );
                              await _loadEverything();
                            },
                          ),
                          const SizedBox(height: 8),
                          _NavButton(
                            icon: Icons.settings,
                            borderColor: const Color(0xFFF6EDFA),
                            elevated: true,
                            label: 'تنظیمات یادآوری',
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const ReminderScreen()),
                              );
                              await _loadEverything();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),

                  _SectionHeader(title: 'نمودار ساز'),
                  Padding(
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green.shade100),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.18),
                            blurRadius: 10,
                            spreadRadius: 1,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ChartSummaryBox(
                            variables: _chartVariables,
                            people: _chartPeople,
                          ),
                          const SizedBox(height: 8),
                          _NavButton(
                            icon: Icons.settings,
                            borderColor: const Color(0xFFF6EDFA),
                            elevated: true,
                            label: 'صفحه نمودار',
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const ChartMakerScreen()),
                              );
                              await _loadEverything();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Material(
                      color: Colors.lightGreen.shade600,
                      elevation: 4,
                      shadowColor: Colors.black45,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const AboutScreen()),
                          );
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.white),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text('درباره برنامه',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16 + MediaQuery.of(context).padding.bottom),
                ],
              ),
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final double topPadding;
  const _SectionHeader({required this.title, this.topPadding = 6});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, topPadding, 16, 4),
      child: Text(title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
    );
  }
}

/// نمایشِ غیرقابل‌کلیکِ خلاصه‌ی «نمودار ساز»: ردیف اول نام متغیرها (نمودارها)
/// و ردیف دوم نام افراد اضافه‌شده. برخلاف [_NavButton]، این ویجت لینک نیست.
class _ChartSummaryBox extends StatelessWidget {
  final List<String> variables;
  final List<String> people;

  const _ChartSummaryBox({required this.variables, required this.people});

  @override
  Widget build(BuildContext context) {
    final fg = Colors.green.shade900;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📊', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مقادیر وارد شده : ${variables.isEmpty ? 'هنوز متغیری اضافه نشده' : variables.join(' ، ')}',
                  style: TextStyle(color: fg, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'افراد ثبت شده : ${people.isEmpty ? 'هنوز فردی اضافه نشده' : people.join(' ، ')}',
                  style: TextStyle(color: fg.withOpacity(0.75)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData? icon;
  final String? emoji;
  final String? emoji2;
  final String? label;
  final Widget? richLabel;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;
  final bool showArrow;
  final double? fontSize;
  final FontWeight? fontWeight;
  final bool elevated;
  const _NavButton({
    this.icon,
    this.emoji,
    this.emoji2,
    this.label,
    this.richLabel,
    required this.onTap,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.showArrow = false,
    this.fontSize,
    this.fontWeight,
    this.elevated = false,
  }) : assert(label != null || richLabel != null, 'either label or richLabel must be provided');

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? Colors.purple.shade50;
    final fg = foregroundColor ?? Colors.purple;
    return Material(
      color: bg,
      elevation: elevated ? 4 : 0,
      shadowColor: Colors.black45,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          decoration: borderColor != null
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor!, width: 3),
                )
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              if (emoji != null) Text(emoji!, style: const TextStyle(fontSize: 22)),
              if (emoji2 != null) ...[
                const SizedBox(width: 4),
                Text(emoji2!, style: const TextStyle(fontSize: 22)),
              ],
              if (emoji == null && icon != null) Icon(icon, color: fg),
              const SizedBox(width: 12),
              Expanded(
                child: richLabel ??
                    Text(
                      label!,
                      style: TextStyle(color: fg, fontSize: fontSize, fontWeight: fontWeight),
                    ),
              ),
              if (showArrow) Icon(Icons.chevron_left, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayCalendarCard extends StatelessWidget {
  final Jalali today;
  final List<CalendarEvent> events;
  final VoidCallback onTap;

  const _TodayCalendarCard({required this.today, required this.events, required this.onTap});

  static const _weekdays = ['شنبه', 'یکشنبه', 'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنجشنبه', 'جمعه'];

  @override
  Widget build(BuildContext context) {
    final gDate = today.toDateTime();
    final hijri = HijriCalendar.fromDate(gDate);

    final jalaliStr = '${toPersianDigits(today.day.toString())} ${today.formatter.mN} ${toPersianDigits(today.year.toString())}';
    final gregorianStr = '${gDate.day} ${gregorianMonthNamesFa[gDate.month - 1]} ${gDate.year}';
    final hijriStr = '${toPersianDigits(hijri.hDay.toString())} ${hijriMonthNamesFa[hijri.hMonth - 1]} ${toPersianDigits(hijri.hYear.toString())}';

    final dateStr = '${_weekdays[today.weekDay - 1]}، $jalaliStr ، $gregorianStr ، $hijriStr';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🗓️', style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(dateStr,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (events.isEmpty)
                Text('امروز مناسبتی وجود ندارد',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13))
              else
                ...events.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${e.isPublic ? '•' : '★'} ${e.title}',
                        style: TextStyle(
                          color: Colors.green.shade900,
                          fontSize: 13,
                        ),
                      ),
                    )),
            ],
          ),
        ),
      ),
    );
  }
}
