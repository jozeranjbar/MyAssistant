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

  @override
  Widget build(BuildContext context) {
    const bodyStyle = TextStyle(fontSize: 15, height: 1.9, color: Colors.black87);
    const linkStyle = TextStyle(
      fontSize: 15,
      height: 1.9,
      color: Colors.blue,
      decoration: TextDecoration.underline,
      fontWeight: FontWeight.bold,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFE8F5D8), // سبز چمنی روشن
      appBar: AppBar(
        title: const Text('اطلاعات برنامه'),
        backgroundColor: const Color(0xFFE8F5D8),
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'دستیار من MyAssistant، یک دستیار همه‌کاره‌ی فارسی برای گوشی شماست.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, height: 1.9),
            ),
            const SizedBox(height: 20),

            const Text('🌤️ آب‌وهوای زنده تا ۴ نقطه انتخابی با دما، احساس دما، رطوبت، باد، UV و پیش‌بینی ۱۰ روزه',
                style: bodyStyle),
            const SizedBox(height: 8),
            const Text(
              'هم می‌توان از داخل برنامه هر شهری را انتخاب کرد و هم می‌توان با وارد کردن طول و عرض جغرافیایی یک نقطه از هر کجای جهان، همیشه آب‌وهوای آنجا را چک کرد.',
              style: bodyStyle,
            ),
            const SizedBox(height: 8),
            const Text(
              'با نگه داشتن چند ثانیه انگشت خود روی یک نقطه از نقشه گوگل مپ، دو عدد را نشان می‌دهد؛ عدد اول عرض جغرافیایی (N) و عدد دوم طول جغرافیایی (E) آن نقطه است.',
              style: bodyStyle,
            ),
            const SizedBox(height: 20),

            const Text('🗓️ تقویم کامل شمسی با مناسبت‌های ایرانی و بین‌المللی و تعطیلات رسمی و امکان بروزرسانی سالانه',
                style: bodyStyle),
            const SizedBox(height: 20),

            const Text('💊🔔 یادآوری دارو و امور روزمره، با تکرار روزانه/هفتگی/ساعتی و صدا و ویبره‌ی واقعی',
                style: bodyStyle),
            const SizedBox(height: 20),

            const Text('📌 ویجت صفحه اصلی گوشی با ساعت، تاریخ، دما و یادآوری‌ها', style: bodyStyle),
            const SizedBox(height: 28),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.support_agent, color: Colors.green, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: bodyStyle,
                      children: [
                        const TextSpan(text: 'پشتیبانی از طریق ایمیل '),
                        TextSpan(
                          text: 'ranjberan@gmail.com',
                          style: linkStyle,
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => _openUrl('mailto:ranjberan@gmail.com'),
                        ),
                        const TextSpan(text: ' و کانال '),
                        TextSpan(
                          text: '@wajehha',
                          style: linkStyle,
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => _openUrl('https://t.me/wajehha'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
