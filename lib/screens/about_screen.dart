import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  // ۰ = اطلاعات کلی (پیش‌فرض)   ۱ = راهنمای برنامه
  int _tab = 0;

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFFE8F5D8); // سبز چمنی روشن

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('اطلاعات برنامه'),
        backgroundColor: bgColor,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: _TabButton(
                    label: 'اطلاعات کلی',
                    selected: _tab == 0,
                    onTap: () => setState(() => _tab = 0),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TabButton(
                    label: 'راهنمای برنامه',
                    selected: _tab == 1,
                    onTap: () => setState(() => _tab = 1),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _tab == 0 ? _GeneralInfoTab(onOpenUrl: _openUrl) : const _UserGuideTab(),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.green.shade700 : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.green.shade700, width: selected ? 0 : 1.5),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : Colors.green.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _GeneralInfoTab extends StatelessWidget {
  final Future<void> Function(String url) onOpenUrl;
  const _GeneralInfoTab({required this.onOpenUrl});

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

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
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
                          ..onTap = () => onOpenUrl('mailto:ranjberan@gmail.com'),
                      ),
                      const TextSpan(text: ' و کانال '),
                      TextSpan(
                        text: '@wajehha',
                        style: linkStyle,
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => onOpenUrl('https://t.me/wajehha'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UserGuideTab extends StatelessWidget {
  const _UserGuideTab();

  @override
  Widget build(BuildContext context) {
    const bodyStyle = TextStyle(fontSize: 15, height: 1.9, color: Colors.black87);
    const titleStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.bold, height: 1.9);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('🌤️ آب و هوا', style: titleStyle),
          SizedBox(height: 8),
          Text(
            'از طریق نوار «تنظیمات آب و هوا» می‌توانید تا ۴ شهر یا نقطه‌ی جغرافیایی دلخواه اضافه کنید. با زدن روی نوار «وضعیت هوای ده روز آینده» پیش‌بینی ۱۰ روز بعد را می‌بینید. در آن صفحه با کشیدن انگشت به چپ یا راست هم به صفحه‌ی اصلی برمی‌گردید.',
            style: bodyStyle,
          ),
          SizedBox(height: 20),

          Text('🗓️ تقویم', style: titleStyle),
          SizedBox(height: 8),
          Text(
            'تاریخ امروز به‌صورت شمسی، میلادی و قمری نمایش داده می‌شود. با زدن روی نوار «تنظیم مناسبت‌ها و مشاهده تقویم کامل» می‌توانید همه‌ی روزهای سال و مناسبت‌های شخصی خودتان را مدیریت کنید.',
            style: bodyStyle,
          ),
          SizedBox(height: 20),

          Text('🔔💊 یادآوری', style: titleStyle),
          SizedBox(height: 8),
          Text(
            'از نوار «تنظیمات یادآوری» می‌توانید یادآوری‌های دارویی یا کارهای روزمره را با تکرار روزانه، هفتگی یا ساعتی تنظیم کنید. برنامه سر وقت با صدا و ویبره اطلاع می‌دهد.',
            style: bodyStyle,
          ),
          SizedBox(height: 20),

          Text('📊 نمودار ساز', style: titleStyle),
          SizedBox(height: 8),
          Text(
            'برای پیگیری روند تغییرات مواردی مانند وزن، مقدار خواب، تعداد قدم‌های روزانه یا قند خون، از این بخش استفاده کنید.',
            style: bodyStyle,
          ),
          SizedBox(height: 20),

          Text('📌 ویجت صفحه اصلی', style: titleStyle),
          SizedBox(height: 8),
          Text(
            'با نگه‌داشتن انگشت روی صفحه اصلی گوشی و افزودن ویجت MyAssistant، ساعت، تاریخ، دما و یادآوری‌های امروز همیشه جلوی چشمتان می‌ماند. اندازه‌ی ویجت هم از عرض و ارتفاع قابل تغییر است.',
            style: bodyStyle,
          ),
        ],
      ),
    );
  }
}
