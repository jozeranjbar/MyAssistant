import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import '../models/reminder.dart';
import '../utils/persian_numbers.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'wake_alarm_service.dart';
import 'calendar_update_service.dart';

/// وقتی دکمه‌ی «قطع زنگ» روی اعلانِ بیدارباش زده شود (چه با برنامه‌ی باز، چه
/// از پس‌زمینه)، هر دو نوبتِ زنگ (اصلی و تکرار) را کنسل می‌کند تا صدا فوری
/// قطع شود. باید یک تابعِ سطحِ بالا (top-level) باشد تا هم به‌عنوانِ
/// callback معمولی و هم به‌عنوانِ callback پس‌زمینه قابلِ استفاده باشد.
void _handleNotificationResponse(NotificationResponse response) {
  if (response.actionId == wakeAlarmStopActionId) {
    final plugin = FlutterLocalNotificationsPlugin();
    plugin.cancel(WakeAlarmService.notificationId);
    plugin.cancel(WakeAlarmService.notificationIdEcho);
  } else if (response.payload == CalendarUpdateService.payload) {
    // زدن روی اعلانِ «بروزرسانی تقویم» (برنامه باز یا در پس‌زمینه است)
    CalendarUpdateService.updateWithFeedback();
  }
}

/// نسخه‌ی پس‌زمینه‌ی همان تابع؛ چون اندروید برای اجرای کد در حالتی که برنامه
/// کاملاً بسته است، به یک entry-point جداگانه نیاز دارد.
@pragma('vm:entry-point')
void _handleNotificationResponseBackground(NotificationResponse response) {
  _handleNotificationResponse(response);
}

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
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _handleNotificationResponseBackground,
    );

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

  /// ساعتِ نمایشی مثل انتخاب‌گرِ ساعتِ برنامه (۰۰ تا ۲۳)
  String _timeText(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    return toPersianDigits('$h:${t.minute.toString().padLeft(2, '0')}');
  }

  String _bodyFor(Reminder r, [DateTime? when]) {
    final time = when ?? r.nextOccurrence();
    String text;
    if (r.category == ReminderCategory.medication) {
      text = 'زمان مصرف ${r.title} — ساعت ${_timeText(time)}';
      if (r.dose.isNotEmpty) text += ' (${r.dose})';
    } else {
      text = 'ساعت ${_timeText(time)}';
      if (r.note.isNotEmpty) text += ' — ${r.note}';
    }
    return text;
  }

  /// برای برنامه‌ی چندروزه چند اعلانِ پشت‌سرهم زمان‌بندی می‌شود؛ شناسه‌ی
  /// اعلانِ k‌ام برابر `id + k` است. [_maxSlots] حداکثر تعداد این اعلان‌هاست.
  static const int _maxSlots = 30;

  Future<void> scheduleReminder(Reminder reminder) async {
    if (!reminder.isActive) return;
    await init();

    final occurrences = reminder.upcomingOccurrences(maxCount: _maxSlots);

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

    for (var k = 0; k < occurrences.length; k++) {
      await _plugin.zonedSchedule(
        reminder.id + k,
        reminder.title,
        _bodyFor(reminder, occurrences[k]),
        tz.TZDateTime.from(occurrences[k], tz.local),
        details,
        androidScheduleMode: scheduleMode,
        matchDateTimeComponents: reminder.repeatType == RepeatType.daily ? DateTimeComponents.time : null,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> cancelReminder(int id) async {
    await init();
    await _plugin.cancel(id);
    // اعلان‌های اضافیِ برنامه‌ی چندروزه (id+1 تا id+_maxSlots)
    for (var k = 1; k < _maxSlots; k++) {
      await _plugin.cancel(id + k);
    }
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

  /// شناسه‌های ثابتِ اعلان‌های «بروزرسانی تقویم» (بالاتر از شناسه‌ی یادآوری‌ها)
  static const int _calendarUpdateBaseId = 2100000001;

  /// اعلانِ «تقویم را بروزرسانی کنید» را برای اول و پانزدهمِ اسفندِ امسال و
  /// سالِ بعد (هر کدام که هنوز نیامده)، ساعت ۱۰ صبح زمان‌بندی می‌کند. چون
  /// تاریخِ میلادیِ اول اسفند هر سال فرق می‌کند، هر بار تاریخ‌ها از نو محاسبه
  /// می‌شوند (با هر بار باز شدنِ برنامه).
  Future<void> scheduleCalendarUpdateReminders() async {
    await init();
    for (var i = 0; i < 4; i++) {
      await _plugin.cancel(_calendarUpdateBaseId + i);
    }

    final now = DateTime.now();
    final jNow = Jalali.now();
    final dates = <DateTime>[];
    for (final y in [jNow.year, jNow.year + 1]) {
      for (final d in [1, 15]) {
        final g = Jalali(y, 12, d).toDateTime();
        final t = DateTime(g.year, g.month, g.day, 10, 0);
        if (t.isAfter(now)) dates.add(t);
      }
    }

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final canExact = await androidImpl?.canScheduleExactNotifications() ?? true;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'calendar_update_channel',
        'بروزرسانی تقویم',
        channelDescription: 'یادآوری بروزرسانی تعطیلات رسمی تقویم',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    for (var i = 0; i < dates.length && i < 4; i++) {
      await _plugin.zonedSchedule(
        _calendarUpdateBaseId + i,
        'بروزرسانی تقویم',
        'تقویم را بروزرسانی کنید؛ برای دریافت تعطیلات رسمی جدید روی این اعلان بزنید.',
        tz.TZDateTime.from(dates[i], tz.local),
        details,
        payload: CalendarUpdateService.payload,
        androidScheduleMode:
            canExact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  /// اگر برنامه با زدن روی یک اعلان از حالتِ کاملاً بسته باز شده باشد،
  /// payload آن اعلان را برمی‌گرداند (وگرنه null).
  Future<String?> launchPayload() async {
    await init();
    final d = await _plugin.getNotificationAppLaunchDetails();
    if (d?.didNotificationLaunchApp ?? false) return d?.notificationResponse?.payload;
    return null;
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
