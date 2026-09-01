import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';

String _toPersianDigits(String input) {
  const western = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  var result = input;
  for (var i = 0; i < western.length; i++) {
    result = result.replaceAll(western[i], persian[i]);
  }
  return result;
}

const _gregorianMonthNamesFa = [
  'ژانویه',
  'فوریه',
  'مارس',
  'آوریل',
  'مه',
  'ژوئن',
  'ژوئیه',
  'اوت',
  'سپتامبر',
  'اکتبر',
  'نوامبر',
  'دسامبر',
];

/// صفحه‌ی «تبدیل تاریخ»: با دو کلید بین «شمسی ← میلادی» و «میلادی ← شمسی»
/// جابه‌جا می‌شود؛ با انتخاب تاریخ از فیلدهای کشویی، نتیجه‌ی تبدیل بلافاصله
/// (بدون نیاز به دکمه‌ی جداگانه) در مقابلش نمایش داده می‌شود.
class DateConverterScreen extends StatefulWidget {
  const DateConverterScreen({super.key});

  @override
  State<DateConverterScreen> createState() => _DateConverterScreenState();
}

class _DateConverterScreenState extends State<DateConverterScreen> {
  bool _shamsiToGregorian = true;

  late int _jYear;
  late int _jMonth;
  late int _jDay;

  late int _gYear;
  late int _gMonth;
  late int _gDay;

  @override
  void initState() {
    super.initState();
    final now = Jalali.now();
    _jYear = now.year;
    _jMonth = now.month;
    _jDay = now.day;
    final g = DateTime.now();
    _gYear = g.year;
    _gMonth = g.month;
    _gDay = g.day;
  }

  InputDecoration _pillDecoration() => InputDecoration(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تبدیل تاریخ'),
        backgroundColor: Colors.teal.shade100,
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0).abs() > 200) {
            Navigator.of(context).maybePop();
          }
        },
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFDFF3EE), Color(0xFFFFF3D6)],
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _ToggleTab(
                        label: 'شمسی ← میلادی',
                        selected: _shamsiToGregorian,
                        onTap: () => setState(() => _shamsiToGregorian = true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ToggleTab(
                        label: 'میلادی ← شمسی',
                        selected: !_shamsiToGregorian,
                        onTap: () => setState(() => _shamsiToGregorian = false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                if (_shamsiToGregorian) _buildShamsiToGregorian() else _buildGregorianToShamsi(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShamsiToGregorian() {
    final daysInMonth = Jalali(_jYear, _jMonth, 1).monthLength;
    if (_jDay > daysInMonth) _jDay = daysInMonth;
    final gregorian = Jalali(_jYear, _jMonth, _jDay).toDateTime();
    final resultText =
        '${_toPersianDigits(gregorian.day.toString())} ${_gregorianMonthNamesFa[gregorian.month - 1]} ${_toPersianDigits(gregorian.year.toString())}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('تاریخ شمسی را انتخاب کنید:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF2E5C31))),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                isExpanded: true,
                decoration: _pillDecoration(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurple, height: 1.4),
                value: _jDay,
                items: List.generate(daysInMonth, (i) => i + 1)
                    .map((d) => DropdownMenuItem(value: d, child: Text(_toPersianDigits(d.toString()))))
                    .toList(),
                onChanged: (v) => setState(() => _jDay = v!),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<int>(
                isExpanded: true,
                decoration: _pillDecoration(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.pink, height: 1.4),
                value: _jMonth,
                items: List.generate(12, (i) => i + 1)
                    .map((m) => DropdownMenuItem(value: m, child: Text(Jalali(_jYear, m, 1).formatter.mN)))
                    .toList(),
                onChanged: (v) => setState(() => _jMonth = v!),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<int>(
                isExpanded: true,
                decoration: _pillDecoration(),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange.shade800, height: 1.4),
                value: _jYear,
                items: List.generate(30, (i) => _jYear - 15 + i)
                    .map((y) => DropdownMenuItem(value: y, child: Text(_toPersianDigits(y.toString()))))
                    .toList(),
                onChanged: (v) => setState(() => _jYear = v!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),
        _ResultCard(label: 'معادل میلادی', value: resultText, color: const Color(0xFF1565C0)),
      ],
    );
  }

  Widget _buildGregorianToShamsi() {
    final daysInMonth = DateTime(_gYear, _gMonth + 1, 0).day;
    if (_gDay > daysInMonth) _gDay = daysInMonth;
    final jalali = Jalali.fromDateTime(DateTime(_gYear, _gMonth, _gDay));
    final resultText =
        '${_toPersianDigits(jalali.day.toString())} ${jalali.formatter.mN} ${_toPersianDigits(jalali.year.toString())}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('تاریخ میلادی را انتخاب کنید:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1565C0))),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                isExpanded: true,
                decoration: _pillDecoration(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurple, height: 1.4),
                value: _gDay,
                items: List.generate(daysInMonth, (i) => i + 1)
                    .map((d) => DropdownMenuItem(value: d, child: Text(_toPersianDigits(d.toString()))))
                    .toList(),
                onChanged: (v) => setState(() => _gDay = v!),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<int>(
                isExpanded: true,
                decoration: _pillDecoration(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.pink, height: 1.4),
                value: _gMonth,
                items: List.generate(12, (i) => i + 1)
                    .map((m) => DropdownMenuItem(value: m, child: Text(_gregorianMonthNamesFa[m - 1])))
                    .toList(),
                onChanged: (v) => setState(() => _gMonth = v!),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<int>(
                isExpanded: true,
                decoration: _pillDecoration(),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange.shade800, height: 1.4),
                value: _gYear,
                items: List.generate(30, (i) => _gYear - 15 + i)
                    .map((y) => DropdownMenuItem(value: y, child: Text(_toPersianDigits(y.toString()))))
                    .toList(),
                onChanged: (v) => setState(() => _gYear = v!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),
        _ResultCard(label: 'معادل شمسی', value: resultText, color: const Color(0xFF2E5C31)),
      ],
    );
  }
}

class _ToggleTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleTab({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.teal : Colors.teal.shade50,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : Colors.teal.shade800,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _ResultCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.3), width: 1.4),
        boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color.withOpacity(0.8))),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
