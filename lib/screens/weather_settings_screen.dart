import 'package:flutter/material.dart';
import '../models/weather_location.dart';
import '../services/location_storage_service.dart';
import '../data/iran_locations.dart';

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
const _kFieldFill = Color(0xFFEFF8F3);

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

  bool get _reachedLimit => _locations.length >= LocationStorageService.maxLocations;

  Future<void> _addManualLocation() async {
    final name = _nameController.text.trim();
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());

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
      filled: true,
      fillColor: _kFieldFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
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
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
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
                                  icon: const Icon(Icons.arrow_upward, color: Colors.black54, size: 26),
                                  tooltip: 'انتقال به ابتدای لیست',
                                  onPressed: () => _confirmMoveToTop(loc.id),
                                ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(loc.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${loc.province != null ? '${loc.province} - ' : ''}${loc.latitude.toStringAsFixed(3)}, ${loc.longitude.toStringAsFixed(3)}',
                                      style: const TextStyle(
                                          color: Colors.black87, fontSize: 15, fontWeight: FontWeight.bold),
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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.black87)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _nameController,
                        textAlign: TextAlign.right,
                        decoration: _pillDecoration('نام دلخواه'),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _latController,
                              textAlign: TextAlign.right,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                              decoration: _pillDecoration('عرض‌ جغرافیائی(S یا Lat-N)'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _lngController,
                              textAlign: TextAlign.right,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                              decoration: _pillDecoration('طول‌ جغرافیائی(W یا Lng-E)'),
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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.black87)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<IranProvince>(
                        decoration: _pillDecoration('استان'),
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
                        value: _selectedCity,
                        items: (_selectedProvince?.cities ?? [])
                            .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
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
