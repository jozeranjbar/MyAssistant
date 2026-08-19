import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import '../models/reminder.dart';

/// این سرویس اعلان‌ها را با استفاده از AlarmManager/UNUserNotification در سطح
/// سیستم‌عامل زمان‌بندی می‌کند، به همین دلیل حتی وقتی برنامه به‌طور کامل بسته
/// باشد هم نمایش داده می‌شوند. برای باقی‌ماندن بعد از ری‌استارت گوشی، پرمیشن
/// RECEIVE_BOOT_COMPLETED در AndroidManifest تعریف شده و هنگام بوت، لیست
/// یادآوری‌های ذخیره‌شده دوباره زمان‌بندی می‌شوند (به main.dart مراجعه کنید).
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
    await _plugin.initialize(initSettings);

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.requestExactAlarmsPermission();

    _initialized = true;
  }

  Future<void> scheduleReminder(Reminder reminder) async {
    if (!reminder.isActive) return;
    await init();

    final scheduledDate = tz.TZDateTime.from(reminder.dateTime, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'reminders_channel',
      'یادآوری‌ها',
      channelDescription: 'اعلان‌های یادآوری MyAssistant',
      importance: Importance.max,
      priority: Priority.high,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      reminder.id,
      reminder.title,
      reminder.note,
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: reminder.repeatDaily ? DateTimeComponents.time : null,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelReminder(int id) async {
    await init();
    await _plugin.cancel(id);
  }

  /// دوباره زمان‌بندی کردن همه یادآوری‌های فعال (بعد از بوت گوشی یا باز شدن برنامه)
  Future<void> rescheduleAll(List<Reminder> reminders) async {
    await init();
    for (final r in reminders) {
      if (r.isActive && r.dateTime.isAfter(DateTime.now())) {
        await scheduleReminder(r);
      } else if (r.isActive && r.repeatDaily) {
        await scheduleReminder(r);
      }
    }
  }
}
