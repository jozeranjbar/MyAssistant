import 'package:flutter/material.dart';
import '../services/wake_alarm_service.dart';
import '../utils/persian_numbers.dart';
import 'reminder_screen.dart' show showBigHourTimePicker;

/// صفحه‌ی تنظیمِ «زنگِ بیدارباش»: یک ساعتِ روزانه که مستقل از یادآوری‌های
/// عادی، هر روز در همان ساعت زنگ می‌زند؛ همراه با انتخابِ صدا از میان چند
/// گزینه (نگاه کنید به توضیحِ بالای wake_alarm_service.dart درباره‌ی
/// محدودیتِ نداشتنِ فایلِ موسیقیِ واقعی).
class WakeAlarmScreen extends StatefulWidget {
  const WakeAlarmScreen({super.key});

  @override
  State<WakeAlarmScreen> createState() => _WakeAlarmScreenState();
}

class _WakeAlarmScreenState extends State<WakeAlarmScreen> {
  final _service = WakeAlarmService();
  bool _loading = true;
  bool _enabled = false;
  TimeOfDay _time = const TimeOfDay(hour: 7, minute: 0);
  int _soundIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await _service.load();
    if (!mounted) return;
    setState(() {
      _enabled = settings.enabled;
      _time = TimeOfDay(hour: settings.hour, minute: settings.minute);
      _soundIndex = settings.soundIndex;
      _loading = false;
    });
  }

  Future<void> _persist() async {
    await _service.save(WakeAlarmSettings(
      enabled: _enabled,
      hour: _time.hour,
      minute: _time.minute,
      soundIndex: _soundIndex,
    ));
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickTime() async {
    final picked = await showBigHourTimePicker(context, initial: _time);
    if (picked == null) return;
    setState(() => _time = picked);
    await _persist();
  }

  Future<void> _testSound(int index) async {
    try {
      await _service.testSound(index);
      if (mounted) _showSnack('تا ۳ ثانیه دیگر پخش می‌شود…');
    } catch (e) {
      if (mounted) _showSnack('خطا در پخشِ آزمایشی: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '⏰ تنظیم زمان بیدار کردن',
          style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.deepPurple.shade100),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeColor: Colors.deepPurple,
                        title: const Text('روشن باشد', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('هر روز در ساعتِ زیر زنگ می‌زند'),
                        value: _enabled,
                        onChanged: (v) async {
                          setState(() => _enabled = v);
                          await _persist();
                        },
                      ),
                      const Divider(height: 24),
                      InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: _pickTime,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time, color: Colors.deepPurple),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text('ساعتِ بیدار کردن', style: TextStyle(fontSize: 15)),
                              ),
                              Text(
                                toPersianDigits(
                                  '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
                                ),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.chevron_left, color: Colors.deepPurple),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text('صدای زنگ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.deepPurple.shade100),
                  ),
                  child: Column(
                    children: [
                      for (int i = 0; i < wakeAlarmSounds.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        RadioListTile<int>(
                          activeColor: Colors.deepPurple,
                          value: i,
                          groupValue: _soundIndex,
                          title: Text(wakeAlarmSounds[i].label),
                          secondary: IconButton(
                            icon: const Icon(Icons.play_circle_outline, color: Colors.deepPurple),
                            tooltip: 'پخشِ آزمایشی',
                            onPressed: () => _testSound(i),
                          ),
                          onChanged: (v) async {
                            setState(() => _soundIndex = v!);
                            await _persist();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'این سه گزینه صداهای پیش‌فرضِ خودِ گوشی‌اند (چون امکانِ افزودنِ '
                    'فایلِ موسیقیِ اختصاصی وجود نداشت). با دکمه‌ی ▶ می‌توانید هرکدام را '
                    'قبل از انتخاب بشنوید.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
    );
  }
}
