# MyAssistant

اپلیکیشن فلاتر (Flutter) با سه بخش اصلی: 🌤️ آب و هوا، 📅 تقویم، 🔔 یادآوری.

## ساختار پروژه

```
lib/
  main.dart                        نقطه ورود برنامه
  models/                          مدل‌های داده (Location / WeatherData / Reminder)
  services/
    weather_service.dart           دریافت آب‌وهوا از API رایگان Open-Meteo (بدون نیاز به کلید)
    location_storage_service.dart  ذخیره‌سازی دائمی لوکیشن‌ها + کش آب‌وهوا
    reminder_storage_service.dart  ذخیره‌سازی دائمی یادآوری‌ها
    notification_service.dart      زمان‌بندی اعلان سیستمی (کار می‌کند حتی وقتی برنامه بسته است)
    background_service.dart        WorkManager: بروزرسانی دوره‌ای + بازتنظیم بعد از بوت
  data/iran_locations.dart         دیتاست استان‌ها و شهرهای ایران (قابل گسترش)
  screens/                         صفحات: خانه، تنظیمات آب‌وهوا، تقویم، یادآوری
  widgets/weather_card.dart        کارت نمایش آب‌وهوا (مطابق طرح ارسالی)
android/                           تنظیمات پروژه اندروید + Manifest با پرمیشن‌های لازم
.github/workflows/build-apk.yml    ساخت خودکار APK با GitHub Actions
```

## چرا Open-Meteo؟
رایگان است، نیازی به ثبت‌نام/کلید API ندارد و داده‌های دما، احساس دما، رطوبت،
بارندگی، سرعت باد و شاخص UV (همان فیلدهایی که در عکس نمونه بود) را دارد.
اگر ترجیح می‌دهید از سرویس دیگری (مثل OpenWeatherMap) استفاده کنید، فقط کافیست
`lib/services/weather_service.dart` را با endpoint و کلید API آن جایگزین کنید.

## چگونگی پوشش هر یک از نیازمندی‌ها

| نیاز | پیاده‌سازی |
|---|---|
| صفحه اول با ۳ بخش پشت سر هم | `home_screen.dart` |
| تنظیمات آب‌وهوا با ۲ روش افزودن + حداکثر ۴ لوکیشن | `weather_settings_screen.dart` + `location_storage_service.dart` |
| بروزرسانی دستی با کشیدن به پایین (Pull-to-refresh) | `RefreshIndicator` در `home_screen.dart` |
| نمایش زمان بروزرسانی | فیلد `updatedAt` در `WeatherData` و `weather_card.dart` |
| حذف/افزودن/جابه‌جایی لوکیشن به ابتدای لیست | `weather_settings_screen.dart` |
| ماندگاری لوکیشن‌ها بعد از بستن برنامه | `SharedPreferences` در `location_storage_service.dart` |
| ماندگاری یادآوری‌ها بعد از ری‌استارت گوشی | `SharedPreferences` + `ScheduledNotificationBootReceiver` در Manifest |
| اعلان‌ها وقتی برنامه بسته است | `flutter_local_notifications` (زمان‌بندی در سطح سیستم‌عامل، نه در Dart runtime) |
| کش موقت آب‌وهوا | `cacheWeather` / `getCachedWeather` |
| کارکرد بدون قطعی هنگام نبود اینترنت | بررسی `connectivity_plus` + نمایش آخرین داده کش‌شده + پیام خطا به‌جای کرش |
| پیام مناسب برای خطای API | کلاس `WeatherException` و نمایش آن در `weather_card.dart` |
| ریسپانسیو برای موبایل/تبلت و چرخش صفحه | استفاده از `ListView`/`GridView` نسبی + `MediaQuery`؛ از عرض ثابت پرهیز شده |
| تولید خودکار APK با هر تغییر کد | `.github/workflows/build-apk.yml` |

## اجرای محلی

پیش‌نیاز: نصب [Flutter SDK](https://docs.flutter.dev/get-started/install) (کانال stable).

```bash
flutter pub get
flutter run
```

## ساخت APK به‌صورت محلی

```bash
flutter build apk --release
# خروجی: build/app/outputs/flutter-apk/app-release.apk
```

## ساخت خودکار با GitHub Actions

1. یک ریپازیتوری در گیت‌هاب بسازید و این پروژه را push کنید.
2. با هر push، ورک‌فلو `build-apk.yml` به‌صورت خودکار اجرا می‌شود و:
   - پروژه را `flutter pub get` و `flutter build apk --release --split-per-abi` می‌کند.
   - APK های خروجی را به‌عنوان **Artifact** در تب Actions همان اجرا آپلود می‌کند (قابل دانلود).
   - اگر push روی برنچ `main` باشد، یک **Release** جدید هم با APK پیوست‌شده در گیت‌هاب می‌سازد.
3. برای نصب روی گوشی: از تب Actions یا Releases، فایل APK را دانلود و روی گوشی نصب کنید
   (نیاز به فعال‌سازی «نصب از منابع ناشناس» دارید، چون امضای اپ فعلاً امضای دیباگ است).

> نکته امضا: برای انتشار در Google Play باید یک keystore واقعی بسازید و
> `signingConfig` در `android/app/build.gradle` را به آن اشاره دهید (و کلید را
> به‌صورت GitHub Secret اضافه کنید). نسخه فعلی برای نصب مستقیم/تست کاملاً کار
> می‌کند اما برای انتشار در Play مناسب نیست.

## گسترش لیست شهرهای ایران
برای افزودن شهر جدید، کافیست یک آیتم به `lib/data/iran_locations.dart` اضافه کنید:
```dart
IranCity('نام شهر', عرض_جغرافیایی, طول_جغرافیایی),
```

## محدودیت‌های شناخته‌شده / قدم بعدی
- این پروژه به‌عنوان یک **اسکلت کامل و قابل‌اجرا** نوشته شده؛ چون در محیط فعلی
  امکان اجرای Flutter/Gradle برای build و تست واقعی وجود ندارد، توصیه می‌شود
  بعد از دریافت پروژه، یک‌بار `flutter pub get` و `flutter run` را روی سیستم
  خودتان (یا از طریق همین GitHub Actions) اجرا کنید تا از عدم وجود خطای
  کامپایل مطمئن شوید. اگر خطایی دیدید، برایم بفرستید تا برطرفش کنم.
- تقویم فعلی یک نمای گرید ماهانه ساده شمسی است؛ در صورت نیاز به قابلیت‌های
  پیشرفته‌تر (رویدادهای تکرارشونده، مناسبت‌های رسمی از پیش‌تعریف‌شده) می‌توان
  گسترشش داد.
