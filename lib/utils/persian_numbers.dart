/// توابع مشترکِ تبدیل ارقام فارسی↔انگلیسی.
///
/// این منطق پیش از این، عیناً (کاراکتر به کاراکتر یکسان) در حدود ۷ فایل
/// مختلف کپی شده بود (calendar_screen.dart، reminder_screen.dart،
/// home_screen.dart، hourly_forecast_screen.dart، ten_day_forecast_screen.dart،
/// date_converter_screen.dart، weather_card.dart). همه‌ی آن‌ها به این فایل
/// اشاره می‌کنند تا یک نسخه‌ی واحد و قابل‌نگهداری وجود داشته باشد.
library persian_numbers;

const _westernDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
const _persianDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
const _arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

/// اعداد انگلیسیِ داخل یک رشته را به معادل فارسی تبدیل می‌کند.
String toPersianDigits(String input) {
  var result = input;
  for (var i = 0; i < _westernDigits.length; i++) {
    result = result.replaceAll(_westernDigits[i], _persianDigits[i]);
  }
  return result;
}

/// ارقام فارسی یا عربی داخل یک رشته را به معادل انگلیسی تبدیل می‌کند
/// (برای پردازش داخلی، مثلاً قبل از `int.tryParse`/`double.tryParse`).
/// ممیزِ عربی («٫») هم به نقطه‌ی معمولی تبدیل می‌شود.
String normalizeDigitsToAscii(String input) {
  var result = input;
  for (var i = 0; i < _westernDigits.length; i++) {
    result = result.replaceAll(_persianDigits[i], _westernDigits[i]);
    result = result.replaceAll(_arabicDigits[i], _westernDigits[i]);
  }
  return result.replaceAll('٫', '.');
}
