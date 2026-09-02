import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import '../models/reminder.dart';

/// این سرویس اعلان‌ها را با استفاده از AlarmManager/UNUserNotification در سطح
/// سیستم‌عامل زمان‌بندی می‌کند، به همین دلیل حتی وقتی برنامه به‌طور کامل بسته
/// باشد هم نمایش داده می‌شوند. برای باقی‌ماندن بعد از ری‌استارت گوشی، پرمیشن
/// RECEIVE_BOOT_COMPLETED در AndroidManifest تعریف شده و هنگام بوت، لیست
/// یادآوری‌های ذخیره‌شده دوباره زمان‌بندی می‌شوند (به main.dart مراجعه کنید).
///
/// نکته درباره‌ی دقت پس‌زمینه: نوع «روزانه» با matchDateTimeComponents به
/// خودِ سیستم‌عامل سپرده می‌شود و همیشه دقیق است. انواع «یک‌بار»، «هر چند
/// روز» و «هر چند ساعت» هر بار فقط برای وقوع بعدی زمان‌بندی می‌شوند و با هر
/// بار باز شدن برنامه یا روشن‌شدن گوشی (rescheduleAll) به جلو هدایت می‌شوند؛
/// یعنی اگر برنامه برای چند روز اصلاً باز نشود، ممکن است این سه نوع تا باز
/// شدن بعدی برنامه یک قدم عقب بمانند.
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

  /// شناسه‌ی کانال بر اساس دسته + ترکیب صدا/لرزش ساخته می‌شود، چون در
  /// اندروید ۸ به بعد، تنظیمات صدا/لرزشِ یک کانال فقط در اولین بار ساختنش
  /// قابل تعیین است و بعدش دیگر قابل تغییر برنامه‌ای نیست؛ پس هر ترکیب باید
  /// کانال مخصوص به خودش را داشته باشد.
  String _channelId(Reminder r) {
    final base = r.category == ReminderCategory.medication ? 'reminders_med' : 'reminders_daily';
    final soundPart = r.soundEnabled ? 'snd' : 'nosnd';
    final vibratePart = r.vibrationEnabled ? 'vib' : 'novib';
    return '${base}_${soundPart}_${vibratePart}_channel';
  }

  String _channelName(Reminder r) {
    final categoryLabel = r.category == ReminderCategory.medication ? 'یادآوری داروها' : 'یادآوری‌های روزمره';
    final parts = <String>[];
    parts.add(r.soundEnabled ? 'با صدا' : 'بی‌صدا');
    parts.add(r.vibrationEnabled ? 'با لرزش' : 'بی‌لرزش');
    return '$categoryLabel (${parts.join(' - ')})';
  }

  String _bodyFor(Reminder r) {
    if (r.category == ReminderCategory.medication) {
      return r.dose.isNotEmpty ? r.dose : 'زمان مصرف دارو رسید';
    }
    return r.note.isNotEmpty ? r.note : 'یادآوری فرا رسید';
  }

  Future<void> scheduleReminder(Reminder reminder) async {
    if (!reminder.isActive) return;
    await init();

    final scheduledDate = tz.TZDateTime.from(reminder.nextOccurrence(), tz.local);

    final androidDetails = AndroidNotificationDetails(
      _channelId(reminder),
      _channelName(reminder),
      channelDescription: 'اعلان‌های یادآوری MyAssistant',
      importance: Importance.max,
      priority: Priority.high,
      playSound: reminder.soundEnabled,
      enableVibration: reminder.vibrationEnabled,
      vibrationPattern: reminder.vibrationEnabled ? Int64List.fromList([0, 400, 250, 400]) : null,
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(presentSound: reminder.soundEnabled),
    );

    // اگر گوشی مجوز «هشدار دقیق» (Alarms & reminders) را به برنامه نداده
    // باشد، حالت exactAllowWhileIdle بی‌سروصدا رد می‌شود و هیچ اعلانی هرگز
    // شلیک نمی‌شود. به‌جای آن، ابتدا وضعیت مجوز چک می‌شود؛ اگر داده نشده،
    // با حالت غیردقیق زمان‌بندی می‌کنیم تا لااقل با کمی تاخیر (معمولاً چند
    // دقیقه، به‌دست خودِ سیستم‌عامل) اعلان برسد، به‌جای اینکه اصلاً نیاید.
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final canExact = await androidImpl?.canScheduleExactNotifications() ?? true;
    final scheduleMode = canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    await _plugin.zonedSchedule(
      reminder.id,
      reminder.title,
      _bodyFor(reminder),
      scheduledDate,
      details,
      androidScheduleMode: scheduleMode,
      matchDateTimeComponents: reminder.repeatType == RepeatType.daily ? DateTimeComponents.time : null,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelReminder(int id) async {
    await init();
    await _plugin.cancel(id);
  }

  /// یک اعلانِ آزمایشی، ۵ ثانیه دیگر، با صدا و لرزش کامل شلیک می‌کند. برای
  /// تشخیص سریع اینکه آیا اعلان‌ها/صدا/لرزش روی این گوشی درست کار می‌کنند،
  /// بدون نیاز به منتظر ماندن تا سرِ ساعت یک یادآوری واقعی.
  Future<void> sendTestNotification() async {
    await init();
    const androidDetails = AndroidNotificationDetails(
      'test_channel',
      'اعلان آزمایشی',
      channelDescription: 'برای تست فوری صدا و لرزش',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      vibrationPattern: null,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(presentSound: true),
    );
    final scheduledDate = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5));

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final canExact = await androidImpl?.canScheduleExactNotifications() ?? true;

    await _plugin.zonedSchedule(
      999999999,
      'اعلان آزمایشی',
      'اگه این رو با صدا و لرزش دیدی، یعنی تنظیمات گوشی درسته ✅',
      scheduledDate,
      details,
      androidScheduleMode:
          canExact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// دوباره زمان‌بندی کردن همه یادآوری‌های فعال (بعد از بوت گوشی یا باز شدن برنامه)
  Future<void> rescheduleAll(List<Reminder> reminders) async {
    await init();
    for (final r in reminders) {
      if (r.isActive) {
        await scheduleReminder(r);
      }
    }
  }
}
