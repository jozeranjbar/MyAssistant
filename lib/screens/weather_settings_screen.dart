import 'package:flutter/material.dart';
import '../models/weather_location.dart';
import '../services/location_storage_service.dart';
import '../data/iran_locations.dart';
import '../utils/persian_numbers.dart';

// رنگ‌های اصلی طرح جدید (گرادیانت فیروزه‌ای/نعنایی و دکمه‌های آبی-نارنجی)
const _kBgGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFFBFE9DD), Color(0xFFDCF3E4)],
);
const _kButtonGradient = LinearGradient(
  colors: [Color(0xFF4FA8D8), Color(0xFFF2A93C)],
);
const _kCardTopGradient = LinearGradient(
  colors: [
    Color(0xFF7B5EA7),
    Color(0xFFE0729A),
    Color(0xFFE8A65A),
    Color(0xFF57B894),
    Color(0xFF4C93C6),
  ],
);

// رنگ‌های تیتر آبی
const _kHeaderBlue = Color(0xFF1565C0);

// رنگ‌های برجسته‌ی آبی برای دو مستطیل «افزودن لوکیشن» و «افزودن شهر»
const _kBlueFieldFill = Color(0xFFDCEEFB);
const _kBlueBorder = Color(0xFF64B5F6);
const _kBlueShadowColor = Color(0xFF1565C0);

// رنگ‌های برجسته‌ی سبز برای فیلدها و کارت‌ها
const _kGreenFieldFill = Color(0xFFDFF6E3); // سبز کمرنگ
const _kGreenTextStrong = Color(0xFF1B5E20); // سبز پررنگ

// رنگ قهوه‌ای برای نام شهرها
const _kBrownCity = Color(0xFF6D4C29);
const _kGreenBorder = Color(0xFF66BB6A);
const _kGreenShadowColor = Color(0xFF2E7D32);

/// مقدار طول/عرض جغرافیایی را از چند شیوه‌ی نوشتاریِ مختلف می‌خواند، چون
/// کیبورد عددیِ خیلی از گوشی‌ها کلید «منفی» ندارد: «-92.567»، «منفی92.567»،
/// «_92.567» یا حرف جهت در انتها («92.567S» یا «92.567W» یعنی منفی).
double? _parseCoordinate(String raw) {
  var s = normalizeDigitsToAscii(raw.trim());
  if (s.isEmpty) return null;

  var negative = s.contains('منفی') || s.startsWith('-') || s.startsWith('_');
  s = s.replaceAll('منفی', '').replaceAll('-', '').replaceAll('_', '');

  final dirMatch = RegExp(r'\s*([NSEWnsew])\s*$').firstMatch(s);
  if (dirMatch != null) {
    final letter = dirMatch.group(1)!.toUpperCase();
    if (letter == 'S' || letter == 'W') negative = true;
    s = s.substring(0, dirMatch.start);
  }

  final value = double.tryParse(s.trim());
  if (value == null) return null;
  return negative ? -value.abs() : value.abs();
}

class WeatherSettingsScreen extends StatefulWidget {
  const WeatherSettingsScreen({super.key});

  @override
  State<WeatherSettingsScreen> createState() => _WeatherSettingsScreenState();
}

class _WeatherSettingsScreenState extends State<WeatherSettingsScreen> {
  final _storage = LocationStorageService();
  List<WeatherLocation> _locations = [];

  // فرم افزودن دستی با طول و عرض جغرافیایی
  final _nameController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  // انتخاب استان/شهر
  IranProvince? _selectedProvince;
  IranCity? _selectedCity;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final locations = await _storage.loadLocations();
    setState(() => _locations = locations);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  bool get _reachedLimit => _locations.length >= LocationStorageService.maxLocations;

  Future<void> _addManualLocation() async {
    final name = _nameController.text.trim();
    final lat = _parseCoordinate(_latController.text);
    final lng = _parseCoordinate(_lngController.text);

    if (name.isEmpty || lat == null || lng == null) {
      _showMessage('لطفاً نام و مختصات معتبر وارد کنید.');
      return;
    }
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      _showMessage('مقدار طول/عرض جغرافیایی نامعتبر است.');
      return;
    }

    final added = await _storage.addLocation(WeatherLocation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      latitude: lat,
      longitude: lng,
      source: 'manual',
    ));

    if (!added) {
      _showMessage('حداکثر ۴ لوکیشن قابل ثبت است. ابتدا یکی را حذف کنید.');
      return;
    }

    _nameController.clear();
    _latController.clear();
    _lngController.clear();
    await _load();
  }

  Future<void> _addCityLocation() async {
    if (_selectedProvince == null || _selectedCity == null) {
      _showMessage('استان و شهر را انتخاب کنید.');
      return;
    }
    final added = await _storage.addLocation(WeatherLocation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _selectedCity!.name,
      latitude: _selectedCity!.lat,
      longitude: _selectedCity!.lng,
      source: 'iran_city',
      province: _selectedProvince!.name,
    ));
    if (!added) {
      _showMessage('حداکثر ۴ لوکیشن قابل ثبت است. ابتدا یکی را حذف کنید.');
      return;
    }
    await _load();
  }

  Future<void> _removeLocation(String id) async {
    await _storage.removeLocation(id);
    await _load();
  }

  Future<void> _moveToTop(String id) async {
    await _storage.moveToTop(id);
    await _load();
  }

  Future<void> _confirmRemove(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف مکان'),
        content: const Text('آیا از حذف این مکان مطمئنید؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('انصراف')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _removeLocation(id);
    }
  }

  Future<void> _confirmMoveToTop(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تبدیل به مکان اصلی'),
        content: const Text('آیا می‌خواهید این مکان را به مکان اصلی تبدیل کنید؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('انصراف')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('بله')),
        ],
      ),
    );
    if (confirmed == true) {
      await _moveToTop(id);
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  InputDecoration _pillDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _kGreenTextStrong, fontWeight: FontWeight.w600),
      filled: true,
      fillColor: _kGreenFieldFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(color: _kGreenBorder.withOpacity(0.5), width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(color: _kGreenBorder.withOpacity(0.5), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: const BorderSide(color: _kGreenTextStrong, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    );
  }

  /// برای دو مستطیل برجسته‌ی پایینِ صفحه («افزودن با طول و عرض جغرافیایی» و
  /// «انتخاب از استان‌ها و شهرهای ایران») که باید زمینه‌ی آبی داشته باشند.
  BoxDecoration _blueCardDecoration() {
    return BoxDecoration(
      color: _kBlueFieldFill,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _kBlueBorder.withOpacity(0.5), width: 1.2),
      boxShadow: [
        BoxShadow(
          color: _kBlueShadowColor.withOpacity(0.28),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_ios, color: Colors.black87, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        centerTitle: true,
        title: const Text(
          'تنظیمات آب و هوا',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: _kBgGradient),
        child: SafeArea(
          child: GestureDetector(
            onHorizontalDragEnd: (details) {
              if ((details.primaryVelocity ?? 0).abs() > 200) {
                Navigator.of(context).maybePop();
              }
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Text('مکان‌های منتخب من (${_locations.length}/${LocationStorageService.maxLocations})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _kHeaderBlue)),
                const SizedBox(height: 10),
                if (_locations.isEmpty)
                  const Text('هنوز لوکیشنی اضافه نشده است.', style: TextStyle(color: Colors.black54)),
                ..._locations.asMap().entries.map((entry) {
                  final index = entry.key;
                  final loc = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: _kGreenFieldFill,
                      border: Border.all(color: _kGreenBorder.withOpacity(0.45), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: _kGreenShadowColor.withOpacity(0.28),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(height: 8, decoration: const BoxDecoration(gradient: _kCardTopGradient)),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent, size: 26),
                                tooltip: 'حذف',
                                onPressed: () => _confirmRemove(loc.id),
                              ),
                              if (index != 0)
                                IconButton(
                                  icon: const Icon(Icons.arrow_upward, color: _kGreenTextStrong, size: 26),
                                  tooltip: 'انتقال به ابتدای لیست',
                                  onPressed: () => _confirmMoveToTop(loc.id),
                                ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(loc.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold, fontSize: 16, color: _kBrownCity)),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${loc.province != null ? '${loc.province} - ' : ''}${loc.latitude.toStringAsFixed(3)}, ${loc.longitude.toStringAsFixed(3)}',
                                      style: const TextStyle(
                                          color: _kGreenTextStrong, fontSize: 15, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 12),

                const Text('افزودن با طول و عرض جغرافیایی',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: _kHeaderBlue)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: _blueCardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _nameController,
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: _kGreenTextStrong, fontWeight: FontWeight.bold),
                        decoration: _pillDecoration('نام دلخواه'),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _latController,
                              textAlign: TextAlign.right,
                              style: const TextStyle(color: _kGreenTextStrong, fontWeight: FontWeight.bold),
                              decoration: _pillDecoration('عرض جغرافیایی (مثلاً -32.5 یا منفی32.5 یا 32.5S)'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _lngController,
                              textAlign: TextAlign.right,
                              style: const TextStyle(color: _kGreenTextStrong, fontWeight: FontWeight.bold),
                              decoration: _pillDecoration('طول جغرافیایی (مثلاً -53.6 یا منفی53.6 یا 53.6W)'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _GradientButton(
                        label: 'افزودن لوکیشن',
                        icon: Icons.add,
                        onTap: _reachedLimit ? null : _addManualLocation,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),

                const Text('انتخاب از استان‌ها و شهرهای ایران',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: _kHeaderBlue)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: _blueCardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<IranProvince>(
                        decoration: _pillDecoration('استان'),
                        style: const TextStyle(color: _kGreenTextStrong, fontWeight: FontWeight.bold),
                        value: _selectedProvince,
                        items: iranProvinces.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedProvince = value;
                            _selectedCity = null;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<IranCity>(
                        decoration: _pillDecoration('شهر'),
                        style: const TextStyle(color: _kBrownCity, fontWeight: FontWeight.bold),
                        value: _selectedCity,
                        items: (_selectedProvince?.cities ?? [])
                            .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c.name, style: const TextStyle(color: _kBrownCity, fontWeight: FontWeight.bold))))
                            .toList(),
                        onChanged: _selectedProvince == null
                            ? null
                            : (value) => setState(() => _selectedCity = value),
                      ),
                      const SizedBox(height: 14),
                      _GradientButton(
                        label: 'افزودن شهر',
                        icon: Icons.add,
                        onTap: _reachedLimit ? null : _addCityLocation,
                      ),
                    ],
                  ),
                ),
                if (_reachedLimit)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text('به حداکثر تعداد لوکیشن (۴) رسیده‌اید.',
                        style: TextStyle(color: Colors.deepOrange)),
                  ),
                const SizedBox(height: 24),
                const Center(child: Icon(Icons.auto_awesome, color: Colors.white70, size: 26)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  const _GradientButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          decoration: BoxDecoration(
            gradient: _kButtonGradient,
            borderRadius: BorderRadius.circular(28),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(width: 8),
                  Icon(icon, color: Colors.white, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
