enum ReminderCategory { medication, daily }

enum RepeatType { once, daily, everyXDays, everyXHours }

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
  }) : createdAt = createdAt ?? DateTime.now();

  String get timeLabel =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  String get repeatLabel => repeatType.label(interval: repeatInterval);

  /// نزدیک‌ترین لحظه‌ی وقوع بعدی این یادآوری، نسبت به زمان داده‌شده.
  DateTime nextOccurrence({DateTime? from}) {
    final base = from ?? DateTime.now();
    switch (repeatType) {
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
      );
}
