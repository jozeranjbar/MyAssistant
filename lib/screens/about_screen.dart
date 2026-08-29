import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'calendar_screen.dart' show showManageHolidaysDialog;

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
    const bgColor = Color(0xFFE8F5D8); // سبز چمنی روشن
    const bodyStyle = TextStyle(fontSize: 15, height: 1.9, color: Colors.black87);
    const titleStyle = TextStyle(fontSize: 17, fontWeight: FontWeight.bold, height: 1.9, color: Colors.green);
    const linkStyle = TextStyle(
      fontSize: 15,
      height: 1.9,
      color: Colors.blue,
      decoration: TextDecoration.underline,
      fontWeight: FontWeight.bold,
    );

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('اطلاعات برنامه'),
        backgroundColor: bgColor,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0).abs() > 200) {
            Navigator.of(context).maybePop();
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'دستیار من MyAssistant، یک دستیار همه‌کاره‌ی فارسی برای گوشی شماست.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, height: 1.9),
              ),
              const SizedBox(height: 20),

              const Text('🌤️ آب و هوا', style: titleStyle),
              const SizedBox(height: 6),
              const Text(
                'آب‌وهوای زنده تا ۴ نقطه انتخابی، با دما، احساس دما، رطوبت، باد، شاخص UV و پیش‌بینی ۱۰ روزه.\n'
                '📍 از داخل برنامه می‌توانید هر شهری را انتخاب کنید.\n'
                '🗺️ یا با نگه داشتن انگشت روی هر نقطه از نقشه گوگل مپ، مختصات آن نقطه را بردارید (عدد اول کوچک‌تر از ۹۰ و عدد دوم کوچک‌تر از ۱۸۰).\n'
                '📝 سپس مختصات را با سه رقم اعشار در برنامه وارد کنید تا همیشه آب‌وهوای ده‌روزه‌ی همان نقطه را در گوشی داشته باشید.',
                style: bodyStyle,
              ),
              const SizedBox(height: 20),

              const Text('🗓️ تقویم', style: titleStyle),
              const SizedBox(height: 6),
              const Text(
                'تقویم کامل شمسی همراه با تاریخ میلادی و قمری، مناسبت‌های ایرانی و بین‌المللی، و تعطیلات رسمی. امکان بروزرسانی سالانه هم وجود دارد.',
                style: bodyStyle,
              ),
              const SizedBox(height: 10),
              _ActionButton(
                icon: Icons.event_repeat,
                label: 'بروزرسانی ماه‌های قمری و مناسبت‌های رسمی',
                color: Colors.deepPurple,
                onTap: () => showManageHolidaysDialog(context),
              ),
              const SizedBox(height: 20),

              const Text('💊🔔 یادآوری', style: titleStyle),
              const SizedBox(height: 6),
              const Text(
                'یادآوری دارو و کارهای روزمره، با تکرار روزانه، هفتگی یا ساعتی و اعلان آن.',
                style: bodyStyle,
              ),
              const SizedBox(height: 20),

              const Text('📊 نمودار ساز', style: titleStyle),
              const SizedBox(height: 6),
              const Text(
                'نمودارساز برنامه، تمام متغیرهای شما را در طول یک دوره به‌صورت نمودار خطی نشان می‌دهد و ثبت می‌کند.',
                style: bodyStyle,
              ),
              const SizedBox(height: 20),

              const Text('📌 ویجت صفحه اصلی', style: titleStyle),
              const SizedBox(height: 6),
              const Text(
                'ویجت صفحه اصلی گوشی با ساعت، تاریخ، دما و یادآوری‌ها و قابلیت تنظیم عرض و ارتفاع آن روی گوشی شما.',
                style: bodyStyle,
              ),
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
                          const TextSpan(text: 'برای اطلاع از گسترش برنامه و آپدیت جدید با ما در ارتباط باشید:\n'),
                          TextSpan(
                            text: 'ranjberan@gmail.com',
                            style: linkStyle,
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => _openUrl('mailto:ranjberan@gmail.com'),
                          ),
                          const TextSpan(text: '  |  '),
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
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final MaterialColor color;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.shade50,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: color.shade700),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: TextStyle(color: color.shade700, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
