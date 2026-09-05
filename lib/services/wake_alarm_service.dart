import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

/// یک گزینه‌ی صدا برای زنگِ بیدارباش.
///
/// نکته‌ی مهم: چون امکانِ ساختن یا دانلودِ فایلِ موسیقیِ واقعی برای این
/// سرویس وجود ندارد (بدون دسترسی به اینترنتِ عمومی/فروشگاه‌های صدا)، این سه
/// گزینه به‌جای موسیقیِ اختصاصی، از صداهای پیش‌فرضِ خودِ گوشی (که روی هر
/// اندرویدی از قبل وجود دارند) استفاده می‌کنند. اگر بعداً خواستی یک موسیقیِ
/// آرامِ واقعی جایگزین کنی، کافی است یک فایلِ mp3 کوتاه (مثلاً ۱۵ تا ۳۰
/// ثانیه) را در پوشه‌ی
/// android/app/src/main/kotlin/../../res/raw/  («android/app/src/main/res/raw/»)
/// با یک اسمِ ساده مثلِ wake_calm_1.mp3 بگذاری، و پایینِ همین فایل، به‌جای
/// یکی از uriهای زیر، این خط را جایگزین کنی:
/// `sound: RawResourceAndroidNotificationSound('wake_calm_1')`.
class WakeAlarmSound {
  final String label;
  final String androidUri;

  const WakeAlarmSound(this.label, this.androidUri);
}

const List<WakeAlarmSound> wakeAlarmSounds = [
  WakeAlarmSound('صدای پیش‌فرض اعلان (ملایم‌تر)', 'content://settings/system/notification_sound'),
  WakeAlarmSound('صدای پیش‌فرض زنگ هشدار', 'content://settings/system/alarm_alert'),
  WakeAlarmSound('صدای پیش‌فرض رینگ‌تون', 'content://settings/system/ringtone'),
];

class WakeAlarmSettings {
  final bool enabled;
  final int hour;
  final int minute;
  final int soundIndex;

  const WakeAlarmSettings({
    required this.enabled,
    required this.hour,
    required this.minute,
    required this.soundIndex,
  });

  String get timeLabel => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  WakeAlarmSound get sound => wakeAlarmSounds[soundIndex.clamp(0, wakeAlarmSounds.length - 1)];
}

/// زمان‌بندیِ یک اعلانِ روزانه (با استفاده از همان زیرساختِ
/// flutter_local_notifications که برای بقیه‌ی یادآوری‌ها استفاده می‌شود) که
/// به‌عنوان زنگِ بیدارباش عمل می‌کند. کاملاً مستقل از سیستمِ یادآوریِ عادی
/// است تا به کدِ آن دست نخورد.
class WakeAlarmService {
  static const _keyEnabled = 'wake_alarm_enabled';
  static const _keyHour = 'wake_alarm_hour';
  static const _keyMinute = 'wake_alarm_minute';
  static const _keySoundIndex = 'wake_alarm_sound_index';

  /// شناسه‌ی ثابتِ اعلانِ بیدارباش (خارج از محدوده‌ی شناسه‌های یادآوری‌های عادی)
  static const int _notificationId = 999900001;
  static const int _testNotificationId = 999900002;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<WakeAlarmSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return WakeAlarmSettings(
      enabled: prefs.getBool(_keyEnabled) ?? false,
      hour: prefs.getInt(_keyHour) ?? 7,
      minute: prefs.getInt(_keyMinute) ?? 0,
      soundIndex: prefs.getInt(_keySoundIndex) ?? 0,
    );
  }

  Future<void> save(WakeAlarmSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, settings.enabled);
    await prefs.setInt(_keyHour, settings.hour);
    await prefs.setInt(_keyMinute, settings.minute);
    await prefs.setInt(_keySoundIndex, settings.soundIndex);

    if (settings.enabled) {
      await _schedule(settings);
    } else {
      await _plugin.cancel(_notificationId);
    }
  }

  /// دوباره زمان‌بندی‌کردنِ بیدارباشِ ذخیره‌شده (برای بعد از باز شدنِ برنامه
  /// یا روشن‌شدنِ گوشی، دقیقاً مثلِ بقیه‌ی یادآوری‌ها)
  Future<void> reschedule() async {
    final settings = await load();
    if (settings.enabled) {
      await _schedule(settings);
    }
  }

  Future<void> _schedule(WakeAlarmSettings settings) async {
    // شناسه‌ی کانال باید شاملِ ایندکسِ صدا باشد، چون در اندروید ۸ به بعد
    // صدای یک کانال فقط در اولین ساختش قابل تعیین است.
    final channelId = 'wake_alarm_channel_${settings.soundIndex}';
    final androidDetails = AndroidNotificationDetails(
      channelId,
      'زنگ بیدارباش',
      channelDescription: 'زنگِ روزانه‌ی بیدار کردن',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: UriAndroidNotificationSound(settings.sound.androidUri),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 400, 250, 400, 250, 400]),
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
    );
    final details = NotificationDetails(android: androidDetails);

    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, settings.hour, settings.minute);
    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }
    final scheduledDate = tz.TZDateTime.from(next, tz.local);

    final androidImpl =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final canExact = await androidImpl?.canScheduleExactNotifications() ?? true;

    await _plugin.zonedSchedule(
      _notificationId,
      '⏰ وقتِ بیدار شدنه',
      'زنگِ بیدارباشِ شما به صدا در آمد',
      scheduledDate,
      details,
      androidScheduleMode:
          canExact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// پخشِ آزمایشیِ یکی از صداها، ۳ ثانیه دیگر، تا کاربر قبل از انتخابِ
  /// نهایی بتواند صدا را بشنود.
  Future<void> testSound(int soundIndex) async {
    final sound = wakeAlarmSounds[soundIndex.clamp(0, wakeAlarmSounds.length - 1)];
    final androidDetails = AndroidNotificationDetails(
      'wake_alarm_test_channel_$soundIndex',
      'تستِ صدای بیدارباش',
      channelDescription: 'پخشِ آزمایشیِ صدای انتخاب‌شده',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: UriAndroidNotificationSound(sound.androidUri),
      category: AndroidNotificationCategory.alarm,
    );
    final details = NotificationDetails(android: androidDetails);
    final scheduledDate = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 3));

    final androidImpl =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final canExact = await androidImpl?.canScheduleExactNotifications() ?? true;

    await _plugin.zonedSchedule(
      _testNotificationId,
      'تستِ صدا',
      sound.label,
      scheduledDate,
      details,
      androidScheduleMode:
          canExact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
