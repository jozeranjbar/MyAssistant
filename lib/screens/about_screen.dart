import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';

/// صفحه‌ی «درباره برنامه» با دو تب: «اطلاعات برنامه» و «آموزش برنامه».
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  bool _showInfo = true; // true: اطلاعات برنامه ، false: آموزش برنامه

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static const _pageBg = Color(0xFF2C3E50);
  static const _cardBg = Color(0xFF1A6CB9);
  static const _yellow = Color(0xFFFFEB3B);

  static const _featureTitleStyle = TextStyle(
    fontSize: 14.5,
    fontWeight: FontWeight.bold,
    color: _yellow,
    height: 1.6,
  );
  static const _featureBodyStyle = TextStyle(
    fontSize: 13.5,
    color: Colors.white,
    height: 1.7,
  );
  static const _contactTextStyle = TextStyle(
    fontSize: 13.5,
    color: Colors.white,
    height: 1.7,
  );
  static const _linkStyle = TextStyle(
    fontSize: 13.5,
    color: _yellow,
    fontWeight: FontWeight.bold,
    decoration: TextDecoration.none,
  );

  // ---------------------------------------------------------------------
  // متن «اطلاعات برنامه»
  // ---------------------------------------------------------------------
  static const _infoSections = <(String, String)>[
    (
      '🌦️ آب‌وهوای زنده',
      'انتخاب و نمایش آب‌وهوای تا ۴ نقطه، شامل دما، حداقل و حداکثر دما، دمای احساسی، احتمال بارش، رطوبت، سرعت باد، شاخص UV و پیش‌بینی ساعتی و ۱۰ روزه.',
    ),
    (
      '📅 تقویم',
      'تقویم کامل شمسی همراه با مناسبت‌های ایرانی و بین‌المللی، تعطیلات رسمی و امکان افزودن مناسبت‌های دلخواه.',
    ),
    (
      '💊 یادآوری',
      'یادآوری داروها و امور روزمره با قابلیت تکرار روزانه، هفتگی یا ساعتی و اعلان آنها.',
    ),
    (
      '📊 نمودارساز',
      'ثبت مقادیر و نمایش تغییرات آن‌ها در طول زمان به‌صورت نمودار خطی.',
    ),
    (
      '📱 ویجت',
      'ویجت صفحه گوشی با نمایش ساعت، تاریخ، دما و یادآوری‌ها و امکان تنظیم عرض و ارتفاع آن.',
    ),
    (
      '💾 ذخیره',
      'اطلاعات برنامه به‌صورت خودکار ذخیره می‌شوند. همچنین می‌توانید فایل ذخیره اطلاعات را انتقال دهید و در دستگاه یا برنامه دیگری وارد کنید.',
    ),
  ];

  // ---------------------------------------------------------------------
  // متن «آموزش برنامه»
  // ---------------------------------------------------------------------
  static const _helpSections = <(String, String)>[
    (
      '🌦️ آب‌وهوا',
      'برای به‌روزرسانی آب‌وهوا، صفحه را از بالا به پایین بکشید.\n'
          'می‌توانید شهرهای ایران را مستقیماً از داخل برنامه انتخاب کنید یا با کمک هوش مصنوعی و Google موقعیت جغرافیایی هر نقطه را بدست اورد و آن را بعنوان مکان موردنظر انتخاب کرد.\n'
          'اگر موقعیت جغرافیایی منفی بود اول کلمه منفی یا علامت "-" را بنویسید بعد عدد را با دو یا سه رقم اعشار.\n'
          'پس از دریافت مختصات، آن‌ها را وارد برنامه کنید تا آب‌وهوای آن نقطه را همیشه در اختیار داشته باشید.\n'
          'با انتقال مکان انتخابی به بالای فهرست، دما و وضعیت هوای آنجا را در ویجت هم خواهید داشت.\n'
          'برای بازگشت از صفحه تنظیمات به صفحه اصلی، صفحه را به چپ یا راست بکشید.',
    ),
    (
      '📅 تقویم',
      '• در تنظیمات تقویم، ابتدا تاریخ مناسبت موردنظر و سپس عنوان آن را وارد کنید.\n'
          '• در بخش «تبدیل تاریخ»، گزینه اول برای تبدیل تاریخ شمسی به میلادی و گزینه دوم برای تبدیل تاریخ میلادی به شمسی است.',
    ),
    (
      '💊 یادآوری',
      '• می‌توانید برای داروها و امور روزمره یادآوری ایجاد کنید و زمان اعلام آن را خودتان تعیین کنید.\n'
          '• تعداد یادآوری‌های فعال نیز در ویجت نمایش داده می‌شود.',
    ),
    (
      '📊 نمودارساز',
      '• در قسمت «مقدار»، عدد و واحد موردنظر را وارد کنید. برنامه مقدار عددی را تشخیص داده و آن را در نمودار ثبت می‌کند.\n'
          '• با لمس نام هر فرد که چراغی کنار آن قرار دارد، می‌توانید نمودار مربوط به او را روشن یا خاموش کنید.',
    ),
    (
      '📱 ویجت',
      'با نگه داشتن چندثانیه انگشت روی ویجت و ظاهر شدن کادر اطراف آن، می‌توان عرض و ارتفاع و مکان آن را تغییر داد.',
    ),
  ];

  Widget _buildTabButton(String label, bool selected, VoidCallback onTap) {
    return Material(
      color: selected ? _yellow : Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? _cardBg : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sections = _showInfo ? _infoSections : _helpSections;

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _pageBg,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text('درباره برنامه'),
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0).abs() > 200) {
            Navigator.of(context).maybePop();
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildTabButton('اطلاعات برنامه', _showInfo, () => setState(() => _showInfo = true))),
                      const SizedBox(width: 10),
                      Expanded(child: _buildTabButton('آموزش برنامه', !_showInfo, () => setState(() => _showInfo = false))),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _cardBg,
                      border: Border.all(color: _yellow, width: 3),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ...sections.map((f) => Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: Colors.white.withOpacity(0.15), width: 1),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(f.$1, style: _featureTitleStyle),
                                  const SizedBox(height: 3),
                                  Text(f.$2, style: _featureBodyStyle),
                                ],
                              ),
                            )),
                        if (_showInfo)
                          Container(
                            margin: const EdgeInsets.only(top: 5),
                            padding: const EdgeInsets.only(top: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('📬 ارتباط با ما', style: _featureTitleStyle),
                                const SizedBox(height: 3),
                                const Text(
                                  'برای اطلاع از توسعه برنامه و دریافت آپدیت، با ما در ارتباط باشید',
                                  style: _contactTextStyle,
                                ),
                                const SizedBox(height: 6),
                                RichText(
                                  text: TextSpan(
                                    style: _contactTextStyle,
                                    children: [
                                      const TextSpan(text: '📧 ایمیل:   '),
                                      TextSpan(
                                        text: 'ranjberan@gmail.com',
                                        style: _linkStyle,
                                        recognizer: TapGestureRecognizer()
                                          ..onTap = () => _openUrl('mailto:ranjberan@gmail.com'),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                RichText(
                                  text: TextSpan(
                                    style: _contactTextStyle,
                                    children: [
                                      const TextSpan(text: '✈️ تلگرام:   '),
                                      TextSpan(
                                        text: 'wajehha@',
                                        style: _linkStyle,
                                        recognizer: TapGestureRecognizer()
                                          ..onTap = () => _openUrl('https://t.me/wajehha'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(top: 15),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => Navigator.of(context).maybePop(),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  'بستن',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
