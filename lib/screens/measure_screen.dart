import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// صفحه‌ی «اندازه‌گیری»: ابزار «متر هوشمند AR» که با دوربین گوشی فاصله،
/// محیط، مساحت و زاویه اندازه می‌گیرد.
///
/// این ابزار مبتنی بر WebXR (`navigator.xr` + سشن `immersive-ar`) است که
/// فقط داخل خودِ مرورگر Chrome (به همراه ARCore) کار می‌کند — WebView
/// جاسازی‌شده‌ی اندروید (که کامپوننت‌های وب فلاتر از آن استفاده می‌کنند)
/// از AR غوطه‌ور پشتیبانی نمی‌کند. به همین دلیل، این صفحه به‌جای نمایش
/// مستقیمِ HTML داخل اپ، فایل را در مسیری ثابت داخل حافظه‌ی اپ آماده کرده
/// و با «باز کردن با...» به یک مرورگر واقعی (Chrome) می‌سپارد تا AR واقعاً
/// کار کند.
///
/// نکته درباره‌ی ذخیره‌سازی: چون مسیر فایل همیشه یکسان نگه داشته می‌شود،
/// از دیدِ Chrome همیشه «همان فایل» باز می‌شود، پس `localStorage` خودِ
/// صفحه (تنظیمات کالیبراسیون و اندازه‌گیری‌های ذخیره‌شده) بین بازکردن‌های
/// مختلف حفظ می‌ماند. این داده‌ها داخل فضای ذخیره‌سازیِ Chrome می‌مانند،
/// نه داخل حافظه‌ی اپ MyAssistant.
class MeasureScreen extends StatefulWidget {
  const MeasureScreen({super.key});

  @override
  State<MeasureScreen> createState() => _MeasureScreenState();
}

class _MeasureScreenState extends State<MeasureScreen> {
  bool _opening = false;
  String? _error;

  /// فایل HTML را از asset اپ به یک مسیرِ ثابت (نه یک نام موقت/تصادفی)
  /// داخل پوشه‌ی کش اپ کپی می‌کند. مسیر همیشه یکسان است تا Chrome همیشه
  /// همان «سایت» را ببیند و localStorage صفحه حفظ شود.
  Future<File> _prepareFile() async {
    final cacheDir = await getTemporaryDirectory();
    final measureDir = Directory('${cacheDir.path}/measure');
    if (!await measureDir.exists()) {
      await measureDir.create(recursive: true);
    }
    final file = File('${measureDir.path}/measure.html');
    final bytes = await rootBundle.load('assets/measure.html');
    // هر بار بازنویسی می‌شود تا اگر سیستم‌عامل کش را پاک کرده باشد،
    // فایل دوباره در همان مسیر ساخته شود (مسیر ثابت می‌ماند، فقط
    // localStorage همان لحظه از دست می‌رود).
    await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    return file;
  }

  Future<void> _openInBrowser() async {
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      final file = await _prepareFile();
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/html', name: 'measure.html')],
        subject: 'اندازه‌گیری AR',
      );
      if (!mounted) return;
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'باز کردن ابزار اندازه‌گیری با خطا مواجه شد. دوباره تلاش کنید.');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.indigo.shade50,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(color: Colors.indigo.withOpacity(0.12), blurRadius: 14, offset: const Offset(0, 6)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('📐', style: TextStyle(fontSize: 26)),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text('متر هوشمند AR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'گوشی را روی زمین یا دیوار بگیر و ضربه بزن؛ ابزار به‌طور خودکار فاصله، محیط، مساحت و زاویه را با دوربین محاسبه می‌کند.',
                    style: TextStyle(fontSize: 13.5, height: 1.8, color: Colors.black87),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ℹ️ ', style: TextStyle(fontSize: 14)),
                        Expanded(
                          child: Text(
                            'این قابلیت به AR واقعی نیاز دارد که فقط داخل مرورگر Chrome کار می‌کند (نه داخل اپ). با زدن دکمه‌ی زیر، ابزار در Chrome باز می‌شود.',
                            style: TextStyle(fontSize: 12.5, height: 1.8, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(fontSize: 13, color: Colors.redAccent)),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _opening ? null : _openInBrowser,
                icon: _opening
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.open_in_browser, size: 18),
                label: Text(_opening ? 'در حال آماده‌سازی...' : 'باز کردن ابزار اندازه‌گیری'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'با زدن دکمه، لیست برنامه‌ها باز می‌شود — Chrome را انتخاب کن.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: Colors.indigo.shade300),
            ),
          ],
        ),
      ),
    );
  }
}
