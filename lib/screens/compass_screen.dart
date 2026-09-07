import 'dart:async';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';

import '../utils/persian_numbers.dart';

/// صفحه‌ی «قطب‌نما»: با استفاده از سنسورهای دستگاه (شتاب‌سنج + مغناطیس‌سنج)
/// جهت فعلی را نمایش می‌دهد. کاملاً آفلاین کار می‌کند و به اینترنت نیازی
/// ندارد. در صورت اتصال به اینترنت و اجازه‌ی کاربر، مختصات جغرافیایی
/// (طول/عرض) هم زیر قطب‌نما نشان داده می‌شود.
class CompassScreen extends StatefulWidget {
  const CompassScreen({super.key});

  @override
  State<CompassScreen> createState() => _CompassScreenState();
}

class _CompassScreenState extends State<CompassScreen> {
  StreamSubscription<CompassEvent>? _compassSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  bool _compassChecked = false;
  bool _compassSupported = true;
  double? _accuracy; // دقت سنسور (اگر دستگاه گزارش دهد)

  // زاویه‌ی «باز شده» (unwrapped) برای چرخش نرم بدون پرش هنگام عبور از ۳۶۰/۰
  double _displayAngle = 0;
  bool _firstReading = true;

  bool _isOnline = false;
  bool _locationLoading = false;
  String? _locationError;
  Position? _position;

  // جهتِ قبله (نسبت به شمالِ جغرافیایی)، فقط وقتی کاربر دکمه‌ی «نمایش جهتِ
  // قبله» را بزند محاسبه می‌شود؛ مبتنی بر مختصاتِ کعبه (۲۱.۴۲۲۵، ۳۹.۸۲۶۲).
  double? _qiblaBearing;
  bool _qiblaLoading = false;
  String? _qiblaError;

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    _initCompass();
  }

  Future<void> _initConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    if (!mounted) return;
    setState(() => _isOnline = !result.contains(ConnectivityResult.none));
    _connectivitySub = Connectivity().onConnectivityChanged.listen((r) {
      if (!mounted) return;
      setState(() => _isOnline = !r.contains(ConnectivityResult.none));
    });
  }

  void _initCompass() {
    final events = FlutterCompass.events;
    if (events == null) {
      setState(() {
        _compassChecked = true;
        _compassSupported = false;
      });
      return;
    }
    _compassSub = events.listen((event) {
      if (!mounted) return;
      final heading = event.heading;
      if (heading == null) {
        setState(() {
          _compassChecked = true;
          _compassSupported = false;
        });
        return;
      }
      setState(() {
        _compassChecked = true;
        _compassSupported = true;
        _accuracy = event.accuracy;
        _updateDisplayAngle(heading);
      });
    });
  }

  /// جلوگیری از چرخش کامل (یک دور اضافه) هنگام عبور از مرز ۳۶۰ درجه به ۰.
  void _updateDisplayAngle(double newHeading) {
    final current = _displayAngle % 360;
    var diff = newHeading - current;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    if (_firstReading) {
      _displayAngle = newHeading;
      _firstReading = false;
    } else {
      _displayAngle += diff;
    }
  }

  Future<void> _fetchLocation() async {
    setState(() {
      _locationLoading = true;
      _locationError = null;
    });
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationError = 'سرویسِ موقعیت مکانی گوشی خاموش است. آن را از تنظیمات گوشی روشن کنید.';
          _locationLoading = false;
        });
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        setState(() {
          _locationError = 'اجازه‌ی دسترسی به موقعیت مکانی داده نشد.';
          _locationLoading = false;
        });
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationError =
              'دسترسی به موقعیت مکانی رد شده. از تنظیمات گوشی فعالش کنید.';
          _locationLoading = false;
        });
        return;
      }

      // ابتدا آخرین موقعیتِ شناخته‌شده (در صورت وجود) را فوری نمایش می‌دهیم
      // تا کاربر منتظر نماند، سپس تلاش می‌کنیم موقعیت تازه را با فرصت
      // کافی (تا ۳۰ ثانیه) دریافت کنیم — دریافت فیکس GPS داخل ساختمان یا
      // بدون آسمان باز می‌تواند چند ثانیه طول بکشد.
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null && mounted) {
          setState(() => _position = lastKnown);
        }
      } catch (_) {
        // نبودِ موقعیتِ قبلی مشکلی نیست؛ ادامه می‌دهیم.
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 30),
        ),
      );
      if (!mounted) return;
      setState(() {
        _position = pos;
        _locationLoading = false;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _locationLoading = false;
        _locationError = _position != null
            ? 'دریافت موقعیت دقیق‌تر زمان‌بر شد؛ مقدار بالا آخرین موقعیت شناخته‌شده است. برای موقعیت دقیق‌تر به فضای باز بروید و دوباره تلاش کنید.'
            : 'زمانِ دریافت موقعیت به پایان رسید. به فضای بازتر بروید (یا مطمئن شوید GPS روشن است) و دوباره تلاش کنید.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locationError = 'دریافت موقعیت مکانی با خطا مواجه شد. دوباره تلاش کنید.';
        _locationLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _compassSub?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }

  /// مختصاتِ خانه‌ی کعبه در مکه.
  static const double _kaabaLat = 21.4225;
  static const double _kaabaLon = 39.8262;

  /// جهتِ قبله (بر حسب درجه، نسبت به شمالِ جغرافیایی) با فرمولِ استانداردِ
  /// «بیرینگِ اولیه» بینِ دو نقطه روی کره؛ همان فرمولی که همه‌ی اپ‌های
  /// قبله‌نما استفاده می‌کنند.
  double _calculateQiblaBearing(double userLat, double userLon) {
    final phi1 = userLat * math.pi / 180;
    final phi2 = _kaabaLat * math.pi / 180;
    final deltaLambda = (_kaabaLon - userLon) * math.pi / 180;
    final y = math.sin(deltaLambda) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) - math.sin(phi1) * math.cos(phi2) * math.cos(deltaLambda);
    final theta = math.atan2(y, x);
    return (theta * 180 / math.pi + 360) % 360;
  }

  /// کوچک‌ترین اختلافِ زاویه‌ای بینِ دو جهت (همیشه بینِ ۰ تا ۱۸۰).
  double _angularDiff(double a, double b) {
    var d = (a - b) % 360;
    if (d > 180) d -= 360;
    if (d < -180) d += 360;
    return d.abs();
  }

  /// با فشردنِ دکمه‌ی «نمایش جهتِ قبله»: اگر موقعیتِ مکانی هنوز نداریم،
  /// اول آن را می‌گیرد (همان مجوزِ مکانی‌ای که برای بخشِ «موقعیت جغرافیایی»
  /// همین صفحه از قبل استفاده می‌شود، بدون نیاز به مجوزِ جدید)، سپس جهتِ
  /// قبله را حساب می‌کند تا روی خودِ قطب‌نما نشان داده شود.
  Future<void> _showQibla() async {
    setState(() {
      _qiblaLoading = true;
      _qiblaError = null;
    });
    if (_position == null) {
      await _fetchLocation();
    }
    if (!mounted) return;
    if (_position == null) {
      setState(() {
        _qiblaLoading = false;
        _qiblaError = _locationError ?? 'دریافتِ موقعیت مکانی ممکن نشد.';
      });
      return;
    }
    setState(() {
      _qiblaBearing = _calculateQiblaBearing(_position!.latitude, _position!.longitude);
      _qiblaLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final heading = _displayAngle % 360 < 0 ? (_displayAngle % 360) + 360 : _displayAngle % 360;
    final headingRounded = heading.round() % 360;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE3E6FF), Color(0xFFFDF3FF)],
        ),
      ),
      child: SafeArea(
        child: !_compassChecked
            ? const Center(child: CircularProgressIndicator())
            : !_compassSupported
                ? _buildUnsupported()
                : _buildCompass(headingRounded),
      ),
    );
  }

  Widget _buildUnsupported() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.explore_off, size: 72, color: Colors.indigo.shade200),
          const SizedBox(height: 16),
          const Text(
            'این دستگاه سنسور قطب‌نما (مغناطیس‌سنج) ندارد یا در دسترس نیست.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildCompass(int headingRounded) {
    final directionName = _persianDirectionName(headingRounded.toDouble());
    final lowAccuracy = _accuracy != null && _accuracy! > 25;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      children: [
        if (lowAccuracy)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.orange.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'دقت قطب‌نما پایین است؛ گوشی را به‌شکل ۸ حرکت دهید تا کالیبره شود.',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
        AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest.shortestSide;
              return Stack(
                alignment: Alignment.center,
                children: [
                  // سایه و پس‌زمینه‌ی دایره‌ای ثابت
                  Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.indigo.withOpacity(0.25),
                          blurRadius: 28,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                  ),
                  // صفحه‌ی چرخان قطب‌نما (جهت‌ها + خط‌کش درجات)
                  AnimatedRotation(
                    turns: -_displayAngle / 360,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: CustomPaint(
                      size: Size(size, size),
                      painter: _CompassDialPainter(qiblaBearingDeg: _qiblaBearing),
                    ),
                  ),
                  // نشانگر ثابت جهت رو‌به‌رو (نوک تیز رو به بالا)
                  Positioned(
                    top: size * 0.02,
                    child: CustomPaint(
                      size: Size(size * 0.09, size * 0.14),
                      painter: _PointerPainter(),
                    ),
                  ),
                  // مرکز: درجه‌ی عددی + نام جهت (ثابت، بدون چرخش)
                  Container(
                    width: size * 0.34,
                    height: size * 0.34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.indigo.shade50,
                      border: Border.all(color: Colors.indigo.shade100, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${toPersianDigits(headingRounded.toString())}°',
                          style: TextStyle(
                            fontSize: size * 0.075,
                            fontWeight: FontWeight.w900,
                            color: Colors.indigo.shade800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          directionName,
                          style: TextStyle(
                            fontSize: size * 0.042,
                            fontWeight: FontWeight.bold,
                            color: Colors.pink.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 22),
        if (_qiblaBearing != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildQiblaFeedback(headingRounded.toDouble()),
          ),
        _buildLocationCard(),
        const SizedBox(height: 12),
        _buildQiblaCard(),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildLocationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.indigo.withOpacity(0.12), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.my_location, color: Colors.indigo.shade400, size: 20),
              const SizedBox(width: 8),
              const Text('موقعیت جغرافیایی',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _isOnline ? Colors.green.shade50 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _isOnline ? 'آنلاین' : 'آفلاین',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _isOnline ? Colors.green.shade700 : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!_isOnline)
            const Text(
              'برای نمایش طول و عرض جغرافیایی، ابتدا به اینترنت متصل شوید.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            )
          else ...[
            if (_position != null) ...[
              Row(
                children: [
                  Expanded(
                    child: _CoordChip(
                      label: 'عرض جغرافیایی',
                      value: toPersianDigits(_position!.latitude.toStringAsFixed(5)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _CoordChip(
                      label: 'طول جغرافیایی',
                      value: toPersianDigits(_position!.longitude.toStringAsFixed(5)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            if (_locationError != null) ...[
              Text(_locationError!, style: const TextStyle(fontSize: 13, color: Colors.redAccent)),
              const SizedBox(height: 10),
            ],
            if (_position == null || _locationError != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _locationLoading ? null : _fetchLocation,
                  icon: _locationLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.location_searching, size: 18),
                  label: Text(_locationLoading
                      ? 'در حال دریافت موقعیت...'
                      : (_position == null ? 'نمایش مختصات مکان' : 'تلاش دوباره برای موقعیت دقیق‌تر')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// نوارِ فیدبک زیرِ قطب‌نما وقتی جهتِ قبله محاسبه شده: اگر گوشی فعلاً
  /// (تقریباً) رو به قبله باشد، پیامِ تاییدی نشان می‌دهد.
  Widget _buildQiblaFeedback(double currentHeading) {
    final facingQibla = _angularDiff(currentHeading, _qiblaBearing!) <= 5;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: facingQibla ? Colors.green.shade50 : Colors.teal.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: facingQibla ? Colors.green.shade300 : Colors.teal.shade200),
      ),
      child: Row(
        children: [
          Text(facingQibla ? '✅' : '🕋', style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              facingQibla
                  ? 'رو به قبله‌اید'
                  : 'نشانگرِ 🕋 روی قطب‌نما را زیرِ نوکِ قرمز بیاورید تا رو به قبله بایستید.',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: facingQibla ? Colors.green.shade800 : Colors.teal.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// کارتِ «جهتِ قبله»: دکمه‌ای که با فشردنش (و در صورتِ نیاز، گرفتنِ
  /// مختصاتِ مکانی با همان مجوزِ موقعیتِ مکانیِ موجود) جهتِ قبله را روی
  /// خودِ قطب‌نما نشان می‌دهد.
  Widget _buildQiblaCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.indigo.withOpacity(0.12), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('🕋', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              const Text('جهت قبله', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              if (_qiblaBearing != null) ...[
                const Spacer(),
                Text(
                  '${toPersianDigits(_qiblaBearing!.round().toString())}°',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade700),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (_qiblaError != null) ...[
            Text(_qiblaError!, style: const TextStyle(fontSize: 13, color: Colors.redAccent)),
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _qiblaLoading ? null : _showQibla,
              icon: _qiblaLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.explore, size: 18),
              label: Text(_qiblaLoading
                  ? 'در حال محاسبه...'
                  : (_qiblaBearing == null ? 'نمایش جهت قبله' : 'به‌روزرسانیِ جهت قبله')),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _persianDirectionName(double deg) {
    const names = [
      'شمال',
      'شمال‌شرقی',
      'شرق',
      'جنوب‌شرقی',
      'جنوب',
      'جنوب‌غربی',
      'غرب',
      'شمال‌غربی',
    ];
    final index = (((deg % 360) + 22.5) / 45).floor() % 8;
    return names[index];
  }
}

class _CoordChip extends StatelessWidget {
  final String label;
  final String value;
  const _CoordChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 11.5, color: Colors.indigo.shade400, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.indigo.shade800)),
        ],
      ),
    );
  }
}

/// رسم صفحه‌ی چرخان قطب‌نما: دایره‌ی بیرونی، خط‌کش درجات، حروف جهت‌ها و
/// (در صورت وجود) نشانگرِ جهتِ قبله.
class _CompassDialPainter extends CustomPainter {
  /// جهتِ قبله بر حسب درجه (نسبت به شمال)؛ اگر null باشد نشانگر رسم نمی‌شود.
  final double? qiblaBearingDeg;

  _CompassDialPainter({this.qiblaBearingDeg});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.045
      ..shader = SweepGradient(
        colors: [Colors.indigo.shade300, Colors.pink.shade200, Colors.indigo.shade300],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius * 0.93, ringPaint);

    final tickPaint = Paint()..color = Colors.indigo.shade200;
    final majorTickPaint = Paint()..color = Colors.indigo.shade700;

    for (int deg = 0; deg < 360; deg += 15) {
      final isCardinal = deg % 90 == 0;
      final isMid = deg % 45 == 0;
      final angle = (deg - 90) * math.pi / 180;
      final outerR = radius * 0.86;
      final innerR = isCardinal ? radius * 0.68 : (isMid ? radius * 0.74 : radius * 0.79);
      final p1 = center + Offset(math.cos(angle), math.sin(angle)) * outerR;
      final p2 = center + Offset(math.cos(angle), math.sin(angle)) * innerR;
      canvas.drawLine(
        p1,
        p2,
        (isCardinal ? majorTickPaint : tickPaint)
          ..strokeWidth = isCardinal ? radius * 0.03 : radius * 0.016,
      );
    }

    _drawLabel(canvas, center, radius * 0.58, 0, 'N', Colors.pink.shade600);
    _drawLabel(canvas, center, radius * 0.58, 90, 'E', Colors.indigo.shade700);
    _drawLabel(canvas, center, radius * 0.58, 180, 'S', Colors.indigo.shade700);
    _drawLabel(canvas, center, radius * 0.58, 270, 'W', Colors.indigo.shade700);

    if (qiblaBearingDeg != null) {
      _drawQiblaMarker(canvas, center, radius, qiblaBearingDeg!);
    }
  }

  /// نشانگرِ جهتِ قبله: یک نقطه‌ی سبز روی حلقه‌ی بیرونی به‌همراه ایموجیِ
  /// کعبه، دقیقاً روی زاویه‌ی محاسبه‌شده — این نشانگر هم مثلِ حروفِ N/E/S/W
  /// جزوِ صفحه‌ی چرخان است، پس با چرخشِ گوشی، خودش را با جهتِ واقعیِ قبله
  /// هماهنگ نگه می‌دارد.
  void _drawQiblaMarker(Canvas canvas, Offset center, double radius, double deg) {
    final angle = (deg - 90) * math.pi / 180;
    final dotCenter = center + Offset(math.cos(angle), math.sin(angle)) * radius * 0.93;
    final dotPaint = Paint()..color = Colors.green.shade600;
    canvas.drawCircle(dotCenter, radius * 0.055, dotPaint);
    canvas.drawCircle(dotCenter, radius * 0.055, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = radius * 0.012);

    final labelCenter = center + Offset(math.cos(angle), math.sin(angle)) * radius * 0.755;
    final tp = TextPainter(
      text: TextSpan(text: '🕋', style: TextStyle(fontSize: radius * 0.16)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, labelCenter - Offset(tp.width / 2, tp.height / 2));
  }

  void _drawLabel(Canvas canvas, Offset center, double r, double deg, String text, Color color) {
    final angle = (deg - 90) * math.pi / 180;
    final pos = center + Offset(math.cos(angle), math.sin(angle)) * r;
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: r * 0.42),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _CompassDialPainter oldDelegate) =>
      oldDelegate.qiblaBearingDeg != qiblaBearingDeg;
}

/// نشانگر ثابت مثلثی که همیشه رو به بالا (جهت روبه‌رو) اشاره می‌کند.
class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.redAccent.shade200
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawShadow(path, Colors.black, 2, false);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
