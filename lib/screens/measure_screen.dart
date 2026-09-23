import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, PlatformException, MethodChannel;

/// صفحه‌ی «اندازه‌گیری»: ابزار «متر هوشمند AR» که با دوربین گوشی فاصله،
/// محیط، مساحت و زاویه اندازه می‌گیرد.
///
/// این ابزار مبتنی بر WebXR (`navigator.xr` + سشن `immersive-ar`) است که
/// فقط داخل یک Secure Context کار می‌کند. آدرس‌های `content://` (که از
/// FileProvider می‌آیند) از نگاه Chrome سکیور حساب نمی‌شوند و باعث خطای
/// «session configuration is not supported» می‌شوند.
///
/// راه‌حل: یک سرور HTTP محلی و بسیار سبک روی `127.0.0.1` داخل خودِ اپ بالا
/// می‌آید و فایل را سرو می‌کند. آدرس‌های loopback همیشه Secure Context
/// محسوب می‌شوند، حتی بدون HTTPS — پس دوربین/WebXR به‌درستی کار می‌کند.
///
/// نکته درباره‌ی ذخیره‌سازی: چون پورت سرور در طول یک اجرای اپ ثابت
/// می‌ماند، هر بار که دکمه زده شود همان آدرس باز می‌شود و `localStorage`
/// صفحه (تنظیمات کالیبراسیون و اندازه‌گیری‌های ذخیره‌شده) حفظ می‌ماند —
/// تا وقتی اپ کاملاً بسته شود. این داده‌ها داخل فضای ذخیره‌سازیِ Chrome
/// می‌مانند، نه داخل حافظه‌ی اپ MyAssistant.
class MeasureScreen extends StatefulWidget {
  const MeasureScreen({super.key});

  @override
  State<MeasureScreen> createState() => _MeasureScreenState();
}

class _MeasureScreenState extends State<MeasureScreen> {
  static const MethodChannel _channel = MethodChannel('com.myassistant.app/open_in_browser');
  static const int _preferredPort = 47681;

  // نگه‌داشتن سرور و آدرس آن در سطح استاتیک تا در باز کردن‌های بعدی
  // (در همان اجرای اپ) دوباره ساخته نشود و آدرس ثابت بماند.
  static HttpServer? _server;
  static Uri? _serverUrl;
  static Uint8List? _htmlBytes;

  bool _opening = false;
  String? _error;

  Future<Uri> _ensureServerRunning() async {
    if (_server != null && _serverUrl != null) return _serverUrl!;

    _htmlBytes ??= (await rootBundle.load('assets/measure.html')).buffer.asUint8List();

    HttpServer server;
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, _preferredPort);
    } catch (_) {
      // اگر پورت پیش‌فرض مشغول بود، سیستم‌عامل خودش یک پورت آزاد بدهد.
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    }

    server.listen((HttpRequest request) {
      request.response.headers.contentType = ContentType('text', 'html', charset: 'utf-8');
      request.response.add(_htmlBytes!);
      request.response.close();
    });

    _server = server;
    _serverUrl = Uri.parse('http://127.0.0.1:${server.port}/measure.html');
    return _serverUrl!;
  }

  Future<void> _openInBrowser() async {
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      final url = await _ensureServerRunning();
      await _channel.invokeMethod('openUrlInBrowser', {'url': url.toString()});
    } on PlatformException {
      if (!mounted) return;
      setState(() => _error = 'مرورگری برای باز کردن ابزار پیدا نشد. لطفاً Chrome را نصب کنید.');
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
                            'این قابلیت به AR واقعی نیاز دارد که فقط داخل مرورگر Chrome کار می‌کند (نه داخل اپ). با زدن دکمه‌ی زیر، ابزار مستقیم در Chrome باز می‌شود.',
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
                    : const Icon(Icons.straighten, size: 18),
                label: Text(_opening ? 'در حال آماده‌سازی...' : 'شروع اندازه‌گیری'),
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
              'ابزار مستقیم در Chrome باز می‌شود.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: Colors.indigo.shade300),
            ),
          ],
        ),
      ),
    );
  }
}
