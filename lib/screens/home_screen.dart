import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/weather_location.dart';
import '../models/weather_data.dart';
import '../services/weather_service.dart';
import '../services/location_storage_service.dart';
import '../services/reminder_storage_service.dart';
import '../services/notification_service.dart';
import '../widgets/weather_card.dart';
import 'weather_settings_screen.dart';
import 'calendar_screen.dart';
import 'reminder_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _weatherService = WeatherService();
  final _locationStorage = LocationStorageService();
  final _reminderStorage = ReminderStorageService();

  List<WeatherLocation> _locations = [];
  final Map<String, WeatherData?> _weatherByLocation = {};
  final Map<String, String?> _errorByLocation = {};
  bool _loading = true;
  int _activeReminderCount = 0;

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
    setState(() {
      _locations = locations;
      _activeReminderCount = reminders.where((r) => r.isActive).length;
      _loading = false;
    });
    await _refreshAllWeather();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MyAssistant')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshAllWeather,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  _SectionHeader(emoji: '🌤️', title: 'آب و هوا'),
                  if (_locations.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
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
                    )
                  else
                    ..._locations.map((loc) => WeatherCard(
                          location: loc,
                          data: _weatherByLocation[loc.id],
                          loading: _loading,
                          error: _errorByLocation[loc.id],
                        )),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _NavButton(
                      icon: Icons.settings,
                      label: 'تنظیمات آب و هوا',
                      onTap: _openWeatherSettings,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _SectionHeader(emoji: '📅', title: 'تقویم'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _NavButton(
                      icon: Icons.calendar_month,
                      label: 'مشاهده تقویم کامل و تنظیم مناسبت‌ها',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CalendarScreen()),
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
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _NavButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.purple.shade50,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: Colors.purple),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: const TextStyle(color: Colors.purple))),
              const Icon(Icons.chevron_left, color: Colors.purple),
            ],
          ),
        ),
      ),
    );
  }
}
