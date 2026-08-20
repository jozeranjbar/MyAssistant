/// فهرست تعطیلات رسمی ایران.
///
/// تعطیلات شمسی (مانند نوروز) هر سال در همان روز و ماه شمسی ثابت هستند و
/// نیازی به بروزرسانی ندارند.
///
/// تعطیلات قمری (مانند عید فطر، عاشورا) بر اساس محاسبه نجومی تقویم هجری
/// قمری تعیین می‌شوند. این محاسبه ممکن است در برخی سال‌ها با اعلام رسمی
/// رویت هلال ماه (که توسط مراجع دینی اعلام می‌شود) یک روز اختلاف داشته باشد.
class SolarHoliday {
  final int month; // ماه شمسی ۱ تا ۱۲
  final int day;
  final String title;
  const SolarHoliday(this.month, this.day, this.title);
}

class LunarHoliday {
  final int month; // ماه قمری ۱ تا ۱۲
  final int day;
  final String title;
  const LunarHoliday(this.month, this.day, this.title);
}

const List<SolarHoliday> solarHolidays = [
  SolarHoliday(1, 1, 'نوروز'),
  SolarHoliday(1, 2, 'نوروز'),
  SolarHoliday(1, 3, 'نوروز'),
  SolarHoliday(1, 4, 'نوروز'),
  SolarHoliday(1, 12, 'روز جمهوری اسلامی ایران'),
  SolarHoliday(1, 13, 'سیزده‌بدر'),
  SolarHoliday(3, 14, 'رحلت امام خمینی (ره)'),
  SolarHoliday(3, 15, 'قیام ۱۵ خرداد'),
  SolarHoliday(11, 22, 'پیروزی انقلاب اسلامی'),
  SolarHoliday(12, 29, 'روز ملی شدن صنعت نفت'),
];

const List<LunarHoliday> lunarHolidays = [
  LunarHoliday(1, 9, 'تاسوعای حسینی'),
  LunarHoliday(1, 10, 'عاشورای حسینی'),
  LunarHoliday(2, 20, 'اربعین حسینی'),
  LunarHoliday(2, 28, 'رحلت رسول اکرم (ص) و شهادت امام حسن مجتبی (ع)'),
  LunarHoliday(2, 30, 'شهادت امام رضا (ع)'),
  LunarHoliday(3, 8, 'شهادت امام حسن عسکری (ع)'),
  LunarHoliday(3, 17, 'میلاد رسول اکرم (ص) و امام جعفر صادق (ع)'),
  LunarHoliday(6, 3, 'شهادت حضرت فاطمه زهرا (س)'),
  LunarHoliday(7, 13, 'میلاد امام علی (ع)'),
  LunarHoliday(7, 27, 'مبعث رسول اکرم (ص)'),
  LunarHoliday(8, 15, 'میلاد امام زمان (عج)'),
  LunarHoliday(9, 21, 'شهادت امام علی (ع)'),
  LunarHoliday(10, 1, 'عید سعید فطر'),
  LunarHoliday(10, 2, 'عید سعید فطر'),
  LunarHoliday(12, 10, 'عید سعید قربان'),
  LunarHoliday(12, 18, 'عید سعید غدیر خم'),
];

const List<String> hijriMonthNamesFa = [
  'محرم',
  'صفر',
  'ربیع‌الاول',
  'ربیع‌الثانی',
  'جمادی‌الاول',
  'جمادی‌الثانی',
  'رجب',
  'شعبان',
  'رمضان',
  'شوال',
  'ذیقعده',
  'ذیحجه',
];
