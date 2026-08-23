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
import '../services/notification_service.dart';
import '../services/events_service.dart';
import '../services/widget_service.dart';
import '../data/iranian_holidays.dart';
import '../widgets/weather_card.dart';
import 'weather_settings_screen.dart';
import 'ten_day_forecast_screen.dart';
import 'chart_maker_screen.dart';
import 'calendar_screen.dart';
import 'reminder_screen.dart';
import 'about_screen.dart';

String _toPersianDigits(String input) {
  const western = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  var result = input;
  for (var i = 0; i < western.length; i++) {
    result = result.replaceAll(western[i], persian[i]);
  }
  return result;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _weatherService = WeatherService();
  final _locationStorage = LocationStorageService();
  final _reminderStorage = ReminderStorageService();
  final _eventsService = EventsService();

  List<WeatherLocation> _locations = [];
  final Map<String, WeatherData?> _weatherByLocation = {};
  final Map<String, String?> _errorByLocation = {};
  bool _loading = true;
  int _activeReminderCount = 0;
  List<CalendarEvent> _todayEvents = [];
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
    setState(() {
      _locations = locations;
      _activeReminderCount = reminders.where((r) => r.isActive).length;
      _todayEvents = todayEvents;
      _loading = false;
    });
    await _refreshAllWeather();
    await _updateWidget(reminders);
    await _maybePromptAddWidget();
  }

  Future<void> _updateWidget(List<Reminder> reminders) async {
    if (_locations.isEmpty) return;
    final firstLoc = _locations.first;
    await WidgetService.updateWidgetData(
      location: firstLoc,
      weather: _weatherByLocation[firstLoc.id],
      reminders: reminders,
    );
  }

  Future<void> _maybePromptAddWidget() async {
    final alreadyPrompted = await WidgetService.hasPromptedBefore();
    if (alreadyPrompted || !mounted) return;

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('افزودن ویجت'),
        content: const Text('آیا می‌خواهید ویجت آب‌وهوا و ساعت را به صفحه اصلی گوشی اضافه کنید؟'),
        actions: [
          TextButton(
            onPressed: () async {
              await WidgetService.markPrompted();
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('نه، متشکرم'),
          ),
          ElevatedButton(
            onPressed: () async {
              await WidgetService.markPrompted();
              await WidgetService.requestPinWidget();
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('بله، اضافه کن'),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshAllWeather() async {
    final connectivity = await Connectivity().checkConnectivity();
    final hasInternet = !connectivity.contains(ConnectivityResult.none);

    for (final loc in _locations) {
      if (!hasInternet) {
        setState(() {
          _errorByLocation[loc.id] = 'اینترنت در دسترس نیست';
        });
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
    if (data == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TenDayForecastScreen(location: loc, data: data)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'MyAssistant',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
            letterSpacing: 0.5,
            color: Color(0xFF6366F1),
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
                  // بخش «آب و هوا»: عنوان + کارت(های) آب‌وهوا + نوار «وضعیت ده روز آینده»
                  // + نوار «تنظیمات آب و هوا»، همگی داخل یک مستطیل واحد
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green.shade100),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('🌤️ آب و هوا',
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
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
                                      icon: Icons.calendar_view_week,
                                      label: 'وضعیت هوای ده روز آینده ${loc.name}',
                                      onTap: () => _openTenDayForecast(loc),
                                      backgroundColor: Colors.blue.shade50,
                                      foregroundColor: Colors.yellow.shade600,
                                      showArrow: false,
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ],
                                )),
                          const SizedBox(height: 8),
                          _NavButton(
                            icon: Icons.settings,
                            label: 'تنظیمات آب و هوا',
                            onTap: _openWeatherSettings,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('🗓️ تقویم',
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
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
                            icon: Icons.calendar_month,
                            label: 'مشاهده تقویم کامل و تنظیم مناسبت‌ها',
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
                  const SizedBox(height: 16),

                  _SectionHeader(emoji: '🔔', title: 'یادآوری'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _NavButton(
                      icon: Icons.notifications,
                      label: _activeReminderCount == 0
                          ? 'یادآوری ثبت نشده است'
                          : '$_activeReminderCount یادآوری فعال — تنظیمات یادآوری',
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ReminderScreen()),
                        );
                        await _loadEverything();
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  _SectionHeader(emoji: '📊', title: 'نمودار ساز'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _NavButton(
                      icon: Icons.bar_chart,
                      label: 'ساخت نمودار',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ChartMakerScreen()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Material(
                      color: Colors.green.shade800,
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
                                child: Text('اطلاعات برنامه و تنظیمات کلی',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                              Icon(Icons.chevron_left, color: Colors.white),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String emoji;
  final String title;
  const _SectionHeader({required this.emoji, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text('$emoji $title',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool showArrow;
  final double? fontSize;
  final FontWeight? fontWeight;
  const _NavButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.backgroundColor,
    this.foregroundColor,
    this.showArrow = false,
    this.fontSize,
    this.fontWeight,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? Colors.purple.shade50;
    final fg = foregroundColor ?? Colors.purple;
    return Material
