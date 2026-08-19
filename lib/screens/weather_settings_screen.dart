import 'package:flutter/material.dart';
import '../models/weather_location.dart';
import '../services/location_storage_service.dart';
import '../data/iran_locations.dart';

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

  @override
  void dispose() {
    _nameController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final locations = await _storage.loadLocations();

    if (!mounted) return;

    setState(() => _locations = locations);
  }

  bool get _reachedLimit =>
      _locations.length >= LocationStorageService.maxLocations;

  // تبدیل اعداد فارسی و عربی به انگلیسی و اصلاح جداکننده اعشار
  String _normalizeNumber(String value) {
    return value
        .trim()
        .replaceAll('۰', '0')
        .replaceAll('۱', '1')
        .replaceAll('۲', '2')
        .replaceAll('۳', '3')
        .replaceAll('۴', '4')
        .replaceAll('۵', '5')
        .replaceAll('۶', '6')
        .replaceAll('۷', '7')
        .replaceAll('۸', '8')
        .replaceAll('۹', '9')
        .replaceAll('٠', '0')
        .replaceAll('١', '1')
        .replaceAll('٢', '2')
        .replaceAll('٣', '3')
        .replaceAll('٤', '4')
        .replaceAll('٥', '5')
        .replaceAll('٦', '6')
        .replaceAll('٧', '7')
        .replaceAll('٨', '8')
        .replaceAll('٩', '9')
        .replaceAll('٫', '.')
        .replaceAll('،', '.')
        .replaceAll(',', '.')
        .replaceAll(' ', '');
  }

  Future<void> _addManualLocation() async {
    final name = _nameController.text.trim();

    final latText = _normalizeNumber(_latController.text);
    final lngText = _normalizeNumber(_lngController.text);

    final lat = double.tryParse(latText);
    final lng = double.tryParse(lngText);

    if (name.isEmpty) {
      _showMessage('لطفاً نام لوکیشن را وارد کنید.');
      return;
    }

    if (lat == null || lng == null) {
      _showMessage(
        'مختصات معتبر نیستند. مثال: 35.6892 و 51.3890',
      );
      return;
    }

    if (!lat.isFinite || !lng.isFinite) {
      _showMessage('مختصات واردشده معتبر نیستند.');
      return;
    }

    if (lat < -90 || lat > 90) {
      _showMessage(
        'عرض جغرافیایی باید بین 90- تا 90 باشد.',
      );
      return;
    }

    if (lng < -180 || lng > 180) {
      _showMessage(
        'طول جغرافیایی باید بین 180- تا 180 باشد.',
      );
      return;
    }

    final added = await _storage.addLocation(
      WeatherLocation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        latitude: lat,
        longitude: lng,
        source: 'manual',
      ),
    );

    if (!added) {
      _showMessage(
        'حداکثر ۴ لوکیشن قابل ثبت است. ابتدا یکی را حذف کنید.',
      );
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

    final added = await _storage.addLocation(
      WeatherLocation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _selectedCity!.name,
        latitude: _selectedCity!.lat,
        longitude: _selectedCity!.lng,
        source: 'iran_city',
        province: _selectedProvince!.name,
      ),
    );

    if (!added) {
      _showMessage(
        'حداکثر ۴ لوکیشن قابل ثبت است. ابتدا یکی را حذف کنید.',
      );
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

  void _showMessage(String msg) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(msg)),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تنظیمات آب و هوا'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'لوکیشن‌های شما '
            '(${_locations.length}/${LocationStorageService.maxLocations})',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 8),

          if (_locations.isEmpty)
            const Text('هنوز لوکیشنی اضافه نشده است.'),

          ..._locations.asMap().entries.map((entry) {
            final index = entry.key;
            final loc = entry.value;

            return Card(
              child: ListTile(
                leading: const Icon(Icons.location_on),
                title: Text(loc.name),
                subtitle: Text(
                  '${loc.province != null ? '${loc.province} • ' : ''}'
                  '${loc.latitude.toStringAsFixed(3)}, '
                  '${loc.longitude.toStringAsFixed(3)}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (index != 0)
                      IconButton(
                        icon: const Icon(Icons.arrow_upward),
                        tooltip: 'انتقال به ابتدای لیست',
                        onPressed: () => _moveToTop(loc.id),
                      ),

                    IconButton(
                      icon: const Icon(
                        Icons.delete,
                        color: Colors.red,
                      ),
                      tooltip: 'حذف',
                      onPressed: () => _removeLocation(loc.id),
                    ),
                  ],
                ),
              ),
            );
          }),

          const Divider(height: 32),

          const Text(
            '۱) افزودن با طول و عرض جغرافیایی',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 8),

          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'نام دلخواه',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _latController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'عرض جغرافیایی (Lat)',
                    hintText: 'مثلاً 35.6892',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: TextField(
                  controller: _lngController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'طول جغرافیایی (Lng)',
                    hintText: 'مثلاً 51.3890',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          ElevatedButton.icon(
            onPressed: _reachedLimit
                ? null
                : _addManualLocation,
            icon: const Icon(Icons.add),
            label: const Text('افزودن لوکیشن'),
          ),

          const Divider(height: 32),

          const Text(
            '۲) انتخاب از استان‌ها و شهرهای ایران',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 8),

          DropdownButtonFormField<IranProvince>(
            decoration: const InputDecoration(
              labelText: 'استان',
              border: OutlineInputBorder(),
            ),
            value: _selectedProvince,
            items: iranProvinces
                .map(
                  (p) => DropdownMenuItem(
                    value: p,
                    child: Text(p.name),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedProvince = value;
                _selectedCity = null;
              });
            },
          ),

          const SizedBox(height: 8),

          DropdownButtonFormField<IranCity>(
            decoration: const InputDecoration(
              labelText: 'شهر',
              border: OutlineInputBorder(),
            ),
            value: _selectedCity,
            items: (_selectedProvince?.cities ?? [])
                .map(
                  (c) => DropdownMenuItem(
                    value: c,
                    child: Text(c.name),
                  ),
                )
                .toList(),
            onChanged: _selectedProvince == null
                ? null
                : (value) {
                    setState(() {
                      _selectedCity = value;
                    });
                  },
          ),

          const SizedBox(height: 8),

          ElevatedButton.icon(
            onPressed: _reachedLimit
                ? null
                : _addCityLocation,
            icon: const Icon(Icons.add),
            label: const Text('افزودن شهر'),
          ),

          if (_reachedLimit)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'به حداکثر تعداد لوکیشن (۴) رسیده‌اید.',
                style: TextStyle(
                  color: Colors.orange,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
