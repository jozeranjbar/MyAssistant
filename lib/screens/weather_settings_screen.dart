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

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.lightBlue.shade100,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.arrow_back_ios, size: 16, color: Colors.brown.shade400),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'تنظیمات آب و هوا',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.brown.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.brown.shade400),
          ],
        ),
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0).abs() > 200) {
            Navigator.of(context).maybePop();
          }
        },
        child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('لوکیشن‌های شما (${_locations.length}/${LocationStorageService.maxLocations})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          if (_locations.isEmpty) const Text('هنوز لوکیشنی اضافه نشده است.'),
          ..._locations.asMap().entries.map((entry) {
            final index = entry.key;
            final loc = entry.value;
            return Card(
              child: ListTile(
                leading: const Icon(Icons.location_on),
                title: Text(loc.name),
                subtitle: Text(
                    '${loc.province != null ? '${loc.province} • ' : ''}${loc.latitude.toStringAsFixed(3)}, ${loc.longitude.toStringAsFixed(3)}'),
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
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'حذف',
                      onPressed: () => _removeLocation(loc.id),
                    ),
                  ],
                ),
              ),
            );
          }),
          const Divider(height: 32),

          const Text('۱) افزودن با طول و عرض جغرافیایی',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'نام دلخواه', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _latController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: const InputDecoration(labelText: 'عرض جغرافیایی (Lat)', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _lngController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: const InputDecoration(labelText: 'طول جغرافیایی (Lng)', border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _reachedLimit ? null : _addManualLocation,
            icon: const Icon(Icons.add),
            label: const Text('افزودن لوکیشن'),
          ),
          const Divider(height: 32),

          const Text('۲) انتخاب از استان‌ها و شهرهای ایران',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          DropdownButtonFormField<IranProvince>(
            decoration: const InputDecoration(labelText: 'استان', border: OutlineInputBorder()),
            value: _selectedProvince,
            items: iranProvinces
                .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
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
            decoration: const InputDecoration(labelText: 'شهر', border: OutlineInputBorder()),
            value: _selectedCity,
            items: (_selectedProvince?.cities ?? [])
                .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
                .toList(),
            onChanged: _selectedProvince == null
                ? null
                : (value) => setState(() => _selectedCity = value),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _reachedLimit ? null : _addCityLocation,
            icon: const Icon(Icons.add),
            label: const Text('افزودن شهر'),
          ),
          if (_reachedLimit)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('به حداکثر تعداد لوکیشن (۴) رسیده‌اید.',
                  style: TextStyle(color: Colors.orange)),
            ),
        ],
      ),
      ),
    );
  }
}
