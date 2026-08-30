import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static const _pageBg = Color(0xFF2C3E50);
  static const _cardBg = Color(0xFF1A6CB9);
  static const _yellow = Color(0xFFFFEB3B);

  @override
  Widget build(BuildContext context) {
    const headerStyle = TextStyle(
      fontSize: 19,
      fontWeight: FontWeight.bold,
      color: _yellow,
    );
    const featureTitleStyle = TextStyle(
      fontSize: 14.5,
      fontWeight: FontWeight.bold,
      color: _yellow,
      height: 1.6,
    );
    const featureBodyStyle = TextStyle(
      fontSize: 13.5,
      color: Colors.white,
      height: 1.6,
    );
    const contactTextStyle = TextStyle(
      fontSize: 13.5,
      color: Colors.white,
      height: 1.7,
    );
    const linkStyle = TextStyle(
      fontSize: 13.5,
      color: _yellow,
      fontWeight: FontWeight.bold,
      decoration: TextDecoration.none,
    );

    final features = <(String, String)>[
      (
        '🌤️ آب‌وهوای زنده',
        'تا ۴ نقطه انتخابی با دما، احساس دما، رطوبت، باد، UV و پیش‌بینی ۱۰ روزه. '
            'هم می‌توان از داخل برنامه، هر شهری را انتخاب کرد و هم می‌توان با هوش مصنوعی و یا گوگل مپ، '
            'طول و عرض جغرافیایی آن نقطه را به دست آورد و وارد برنامه کرد تا همیشه آب‌وهوای ده‌روزه‌ی آنجا را در گوشی داشته باشیم.',
      ),
      (
        '🗓️ تقویم کامل',
        'تقویم کامل شمسی با مناسبت‌های ایرانی و بین‌المللی و تعطیلات رسمی و امکان اضافه‌کردن مناسبت.',
      ),
      (
        '💊🔔 یادآوری دارو و امور روزمره',
        'با تکرار روزانه / هفتگی / ساعتی و اعلان آن.',
      ),
      (
        '📈 نمودار ساز برنامه',
        'تمام متغیرهای شما را در طول یک دوره به‌صورت نمودار خطی نشان می‌دهد و ثبت می‌کند.',
      ),
      (
        '📌 ویجت صفحه اصلی',
        'ویجت صفحه اصلی گوشی با ساعت، تاریخ، دما و یادآوری‌ها و امکان تعیین عرض و ارتفاع آن.',
      ),
    ];

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _pageBg,
        elevation: 0,
        foregroundColor: Colors.white,
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
              child: Container(
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
                    // عنوان اصلی
                    Container(
                      padding: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: _yellow.withOpacity(0.3), width: 2),
                        ),
                      ),
                      child: const Text(
                        'درباره دستیار من MyAssistant',
                        textAlign: TextAlign.center,
                        style: headerStyle,
                      ),
                    ),
                    const SizedBox(height: 15),

                    // فهرست امکانات
                    ...features.map((f) => Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.white.withOpacity(0.15), width: 1),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(f.$1, style: featureTitleStyle),
                              const SizedBox(height: 3),
                              Text(f.$2, style: featureBodyStyle),
                            ],
                          ),
                        )),

                    // بخش تماس
                    Container(
                      margin: const EdgeInsets.only(top: 15),
                      padding: const EdgeInsets.only(top: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Colors.white.withOpacity(0.2), width: 1),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'برای اطلاع از گسترش برنامه و آپدیت جدید با ما در ارتباط باشید',
                            textAlign: TextAlign.center,
                            style: contactTextStyle,
                          ),
                          const SizedBox(height: 4),
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: contactTextStyle,
                              children: [
                                const TextSpan(text: 'ایمیل: '),
                                TextSpan(
                                  text: 'ranjberan@gmail.com',
                                  style: linkStyle,
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () => _openUrl('mailto:ranjberan@gmail.com'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: contactTextStyle,
                              children: [
                                const TextSpan(text: 'تلگرام: '),
                                TextSpan(
                                  text: 'wajehha@',
                                  style: linkStyle,
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () => _openUrl('https://t.me/wajehha'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // دکمه‌ی بستن
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
            ),
          ),
        ),
      ),
    );
  }
}
