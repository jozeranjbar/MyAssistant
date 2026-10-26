enum ReminderCategory { medication, daily }

enum RepeatType { once, daily, everyXDays, everyXHours, cycle }

extension ReminderCategoryX on ReminderCategory {
  String get storageKey => this == ReminderCategory.medication ? 'med' : 'daily';

  static ReminderCategory fromStorageKey(String key) =>
      key == 'med' ? ReminderCategory.medication : ReminderCategory.daily;
}

extension RepeatTypeX on RepeatType {
  String get storageKey {
    switch (this) {
      case RepeatType.once:
        return 'once';
      case RepeatType.daily:
        return 'daily';
      case RepeatType.everyXDays:
        return 'every_x_days';
      case RepeatType.everyXHours:
        return 'every_x_hours';
      case RepeatType.cycle:
        return 'cycle';
    }
  }

  static RepeatType fromStorageKey(String key) {
    switch (key) {
      case 'once':
        return RepeatType.once;
      case 'every_x_days':
        return RepeatType.everyXDays;
      case 'every_x_hours':
        return RepeatType.everyXHours;
      case 'cycle':
        return RepeatType.cycle;
      case 'daily':
      default:
        return RepeatType.daily;
    }
  }

  /// برچسب نمایشی روی کارت (شامل عدد تکرار برای انواع فاصله‌دار)
  String label({int? interval}) {
    switch (this) {
      case RepeatType.once:
        return 'یک‌بار';
      case RepeatType.daily:
        return 'روزانه';
      case RepeatType.everyXDays:
        return 'هر ${interval ?? ''} روز یک‌بار';
      case RepeatType.everyXHours:
        return 'هر ${interval ?? ''} ساعت یک‌بار';
      case RepeatType.cycle:
        return 'برنامه ${interval ?? ''} روزه (تکرارشونده)';
    }
  }

  /// برچسب داخل دراپ‌داون انتخاب نوع تکرار
  String get optionLabel {
    switch (this) {
      case RepeatType.once:
        return 'یک‌بار';
      case RepeatType.daily:
        return 'روزانه';
      case RepeatType.everyXDays:
        return 'هر چند روز یک‌بار';
      case RepeatType.everyXHours:
        return 'هر چند ساعت یک‌بار';
      case RepeatType.cycle:
        return 'برنامه چندروزه (هر روز یک ساعت متفاوت)';
    }
  }
}

class Reminder {
  final int id; // برای شناسه اعلان محلی هم استفاده می‌شود
  ReminderCategory category;
  String title; // نام دارو یا عنوان یادآوری روزمره
  String dose; // فقط دسته‌ی دارو: توضیح کوتاه (مثل «قبل از غذا»)
  String note; // فقط دسته‌ی روزمره: یادداشت تکمیلی
  int hour; // ساعت یادآوری (۰ تا ۲۳)
  int minute; // دقیقه (۰ تا ۵۹)
  RepeatType repeatType;
  int? repeatInterval; // برای «هر چند روز» / «هر چند ساعت»
  bool isActive;
  DateTime createdAt; // مبنای محاسبه‌ی «هر چند روز یک‌بار»
  DateTime? lastFiredAt; // آخرین لحظه‌ی شلیک (برای «هر چند ساعت»)
  bool soundEnabled; // پخش صدا هنگام اعلان
  bool vibrationEnabled; // لرزش هنگام اعلان

  /// فقط برای [RepeatType.cycle]: ساعتِ هر روزِ برنامه، به‌صورت «دقیقه از
  /// نیمه‌شب» (مثلاً ۰۷:۰۰ → ۴۲۰). طولِ این لیست = تعداد روزهای چرخه است و
  /// چرخه بعد از روزِ آخر دوباره از روزِ اول شروع می‌شود.
  ///
  /// مقدارِ [pausedDay] (یعنی -۱) برای یک روز یعنی آن روزِ برنامه «متوقف» است:
  /// در آن روز اعلانی نمی‌آید و روز بعد، برنامه مثل قبل ادامه پیدا می‌کند.
  List<int> cycleMinutes;

  /// نشانه‌ی «روزِ متوقف» داخل [cycleMinutes]
  static const int pausedDay = -1;

  /// فقط برای [RepeatType.cycle]: تاریخِ «روز اول» چرخه (ساعت ۰۰:۰۰).
  DateTime? cycleStart;

  Reminder({
    required this.id,
    required this.category,
    required this.title,
    this.dose = '',
    this.note = '',
    required this.hour,
    required this.minute,
    this.repeatType = RepeatType.daily,
    this.repeatInterval,
    this.isActive = true,
    DateTime? createdAt,
    this.lastFiredAt,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    List<int>? cycleMinutes,
    this.cycleStart,
  })  : cycleMinutes = cycleMinutes ?? <int>[],
        createdAt = createdAt ?? DateTime.now();

  String get timeLabel =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  String get repeatLabel => repeatType == RepeatType.cycle
      ? repeatType.label(interval: cycleMinutes.length)
      : repeatType.label(interval: repeatInterval);

  /// متنِ ساعت‌های برنامه‌ی چندروزه، مثل «۰۱:۰۰ ← ۰۷:۰۰ ← ۱۱:۰۰ ← ۱۷:۰۰»
  String get cycleSummary => cycleMinutes.map(formatMinutesOfDay).join(' ← ');

  static String formatMinutesOfDay(int m) => m == pausedDay
      ? 'توقف'
      : '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

  /// آیا [day] یک روزِ متوقف در برنامه‌ی چندروزه است؟
  bool isCycleDayPaused(DateTime day) {
    if (repeatType != RepeatType.cycle || cycleMinutes.isEmpty) return false;
    return cycleMinutes[cycleDayNumberFor(day) - 1] == pausedDay;
  }

  /// روزِ چندمِ چرخه است [day] (از ۱ شروع می‌شود)
  int cycleDayNumberFor(DateTime day) {
    final n = cycleMinutes.length;
    if (n == 0) return 1;
    final start = cycleStart ?? createdAt;
    final startDate = DateTime.utc(start.year, start.month, start.day);
    final d = DateTime.utc(day.year, day.month, day.day);
    final diff = d.difference(startDate).inDays;
    return ((diff % n) + n) % n + 1;
  }

  /// ساعتِ نوبتِ «امروز» در برنامه‌ی چندروزه (حتی اگر ساعتش گذشته باشد)؛ برای
  /// نمایش روی کارت و صفحه‌ی اصلی. برای انواعِ غیرچرخه‌ای null است.
  DateTime? cycleTodaySlot({DateTime? now}) {
    if (repeatType != RepeatType.cycle || cycleMinutes.isEmpty) return null;
    final base = now ?? DateTime.now();
    final m = cycleMinutes[cycleDayNumberFor(base) - 1];
    if (m == pausedDay) return null; // امروز متوقف است
    return DateTime(base.year, base.month, base.day, m ~/ 60, m % 60);
  }

  /// وقوعِ «در انتظار» برای نمایش در صفحه‌ی اصلی و ویجت: زمانی که هنوز نرسیده
  /// یا حداکثر [grace] از آن گذشته است و تا پایانِ امروز می‌افتد. بعد از
  /// گذشتنِ [grace] (پیش‌فرض ۲ ساعت) از وقتِ مقرر، null برمی‌گردد یعنی
  /// اعلان از نمایش برداشته می‌شود.
  DateTime? pendingOccurrence({DateTime? now, Duration grace = const Duration(hours: 2)}) {
    final base = now ?? DateTime.now();
    final endOfToday = DateTime(base.year, base.month, base.day + 1);
    if (isCycleDayPaused(base)) return null;
    final DateTime t = cycleTodaySlot(now: base) ?? nextOccurrence(from: base.subtract(grace));
    if (base.difference(t) > grace) return null;
    if (!t.isBefore(endOfToday)) return null;
    return t;
  }

  /// چند وقوعِ بعدیِ این یادآوری (به ترتیب زمان). برای انواع غیرچرخه‌ای فقط
  /// یک مورد برمی‌گرداند؛ برای [RepeatType.cycle] تا [maxCount] مورد در
  /// [horizonDays] روزِ آینده، تا چند روز پشت‌سرهم همه‌شان یک‌جا زمان‌بندی
  /// شوند و حتی اگر برنامه چند روز باز نشود، اعلان‌ها بیایند.
  List<DateTime> upcomingOccurrences({DateTime? from, int horizonDays = 14, int maxCount = 30}) {
    final base = from ?? DateTime.now();
    if (repeatType != RepeatType.cycle || cycleMinutes.isEmpty) {
      return [nextOccurrence(from: base)];
    }
    final result = <DateTime>[];
    for (var i = 0; i <= horizonDays && result.length < maxCount; i++) {
      final day = DateTime(base.year, base.month, base.day + i);
      final minutes = cycleMinutes[cycleDayNumberFor(day) - 1];
      if (minutes == pausedDay) continue; // روزِ متوقف: اعلانی زمان‌بندی نمی‌شود
      final t = DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);
      if (t.isAfter(base)) result.add(t);
    }
    return result;
  }

  /// نزدیک‌ترین لحظه‌ی وقوع بعدی این یادآوری، نسبت به زمان داده‌شده.
  DateTime nextOccurrence({DateTime? from}) {
    final base = from ?? DateTime.now();
    switch (repeatType) {
      case RepeatType.cycle:
        if (cycleMinutes.isEmpty) {
          return DateTime(base.year, base.month, base.day, hour, minute).add(const Duration(days: 1));
        }
        // حداکثر یک دورِ کامل (+۱ روز) جلو می‌رویم تا اولین زمانِ بعدی پیدا شود.
        for (var i = 0; i <= cycleMinutes.length + 1; i++) {
          final day = DateTime(base.year, base.month, base.day + i);
          final m = cycleMinutes[cycleDayNumberFor(day) - 1];
          if (m == pausedDay) continue;
          final t = DateTime(day.year, day.month, day.day, m ~/ 60, m % 60);
          if (t.isAfter(base)) return t;
        }
        return base.add(const Duration(days: 1));
      case RepeatType.once:
      case RepeatType.daily:
        var candidate = DateTime(base.year, base.month, base.day, hour, minute);
        if (!candidate.isAfter(base)) {
          candidate = candidate.add(const Duration(days: 1));
        }
        return candidate;
      case RepeatType.everyXDays:
        final interval = (repeatInterval ?? 1).clamp(1, 3650);
        var candidate = DateTime(createdAt.year, createdAt.month, createdAt.day, hour, minute);
        while (!candidate.isAfter(base)) {
          candidate = candidate.add(Duration(days: interval));
        }
        return candidate;
      case RepeatType.everyXHours:
        final interval = (repeatInterval ?? 1).clamp(1, 240);
        final anchor = lastFiredAt ?? createdAt;
        var candidate = DateTime(anchor.year, anchor.month, anchor.day, anchor.hour, anchor.minute);
        while (!candidate.isAfter(base)) {
          candidate = candidate.add(Duration(hours: interval));
        }
        return candidate;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category.storageKey,
        'title': title,
        'dose': dose,
        'note': note,
        'hour': hour,
        'minute': minute,
        'repeatType': repeatType.storageKey,
        'repeatInterval': repeatInterval,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
        'lastFiredAt': lastFiredAt?.toIso8601String(),
        'soundEnabled': soundEnabled,
        'vibrationEnabled': vibrationEnabled,
        'cycleMinutes': cycleMinutes,
        'cycleStart': cycleStart?.toIso8601String(),
      };

  factory Reminder.fromJson(Map<String, dynamic> json) => Reminder(
        id: json['id'],
        category: ReminderCategoryX.fromStorageKey(json['category'] ?? 'daily'),
        title: json['title'] ?? '',
        dose: json['dose'] ?? '',
        note: json['note'] ?? '',
        hour: json['hour'] ?? 8,
        minute: json['minute'] ?? 0,
        repeatType: RepeatTypeX.fromStorageKey(json['repeatType'] ?? 'daily'),
        repeatInterval: json['repeatInterval'],
        isActive: json['isActive'] ?? true,
        createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
        lastFiredAt: json['lastFiredAt'] != null ? DateTime.parse(json['lastFiredAt']) : null,
        // فیلدهای جدید؛ یادآوری‌های قدیمی‌ترِ ذخیره‌شده آن‌ها را ندارند، پس
        // پیش‌فرض هردو «روشن» است (دقیقاً همان رفتاری که قبلاً بدون تنظیم داشتند)
        soundEnabled: json['soundEnabled'] ?? true,
        vibrationEnabled: json['vibrationEnabled'] ?? true,
        cycleMinutes: (json['cycleMinutes'] as List?)?.map((e) => (e as num).toInt()).toList() ?? <int>[],
        cycleStart: json['cycleStart'] != null ? DateTime.parse(json['cycleStart']) : null,
      );
}
