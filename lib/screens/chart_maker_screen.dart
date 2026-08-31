import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:share_plus/share_plus.dart';

import '../models/chart_board.dart';
import '../services/chart_storage_service.dart';
import 'calendar_screen.dart' show showJalaliDatePicker;

/// صفحه‌ی «نمودار ساز»: چند نفر، چند متغیر (وزن، خواب، قند خون و ...) و برای
/// هر متغیر یک جدول تاریخ/مقدار به همراه نموداری خطی. پیاده‌سازی این صفحه
/// معادلِ نسخه‌ی وبِ مستقل «نمودار ساز» است، با استفاده حداکثری از امکانات
/// موجود پروژه (تقویم شمسی مشترک با صفحه‌ی تقویم، الگوی ذخیره‌سازی مشابه
/// یادآوری‌ها) به‌جای بازنویسی دوباره‌ی آن‌ها.
class ChartMakerScreen extends StatefulWidget {
  const ChartMakerScreen({super.key});

  @override
  State<ChartMakerScreen> createState() => _ChartMakerScreenState();
}

class _ChartMakerScreenState extends State<ChartMakerScreen> {
  final _storage = ChartStorageService();
  ChartBoardData _data = ChartBoardData.initial();
  bool _loading = true;
  bool _preparingExport = false;

  final GlobalKey _exportKey = GlobalKey();
  final Map<String, TextEditingController> _valueControllers = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _resetValueControllers();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await _storage.load();
    if (!mounted) return;
    _resetValueControllers();
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  Future<void> _persist() => _storage.save(_data);

  void _resetValueControllers() {
    for (final c in _valueControllers.values) {
      c.dispose();
    }
    _valueControllers.clear();
  }

  TextEditingController _valueControllerFor(ChartRow row, int personIndex) {
    final key = '${identityHashCode(row)}_$personIndex';
    return _valueControllers.putIfAbsent(key, () {
      final initial = personIndex < row.values.length ? row.values[personIndex] : '';
      return TextEditingController(text: initial);
    });
  }

  // ---------------------------------------------------------------------
  // دیالوگ‌های عمومی (تأیید / هشدار / پیام کوتاه)
  // ---------------------------------------------------------------------

  Future<bool?> _confirm(String message) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(message, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('خیر')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('بله'),
          ),
        ],
      ),
    );
  }

  Future<void> _alert(String message) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(message, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [ElevatedButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('باشه'))],
      ),
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<String?> _promptName({required String title, String initial = ''}) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title, textAlign: TextAlign.center),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 30,
          textAlign: TextAlign.right,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          onSubmitted: (v) => Navigator.pop(dialogContext, v.trim()),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('انصراف')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('تایید'),
          ),
        ],
      ),
    );
  }

  Widget _sheetHandle() => Center(
        child: Container(
          width: 42,
          height: 4,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(4)),
        ),
      );

  // ---------------------------------------------------------------------
  // مدیریت متغیرها
  // ---------------------------------------------------------------------

  Future<void> _showVariableSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFFF5F7),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sheetHandle(),
            const Text('متغیرها', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            for (final v in _data.variables)
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                tileColor: v == _data.currentVariable ? const Color(0xFFFFEEF2) : Colors.white,
                title: Text(v, textAlign: TextAlign.right),
                trailing: IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  tooltip: 'حذف متغیر',
                  onPressed: () async {
                    Navigator.pop(sheetCtx);
                    final ok = await _confirm('آیا مطمئن هستید که می‌خواهید متغیر «$v» حذف شود؟');
                    if (ok == true) {
                      setState(() => _data.removeVariable(v));
                      await _persist();
                    }
                  },
                ),
                onTap: () {
                  setState(() => _data.currentVariable = v);
                  unawaited(_persist());
                  Navigator.pop(sheetCtx);
                },
              ),
            const SizedBox(height: 6),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(sheetCtx);
                _addVariableDialog();
              },
              icon: const Icon(Icons.add),
              label: const Text('افزودن متغیر'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7CB342), foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addVariableDialog() async {
    final name = await _promptName(title: 'نام متغیر جدید را بنویسید');
    if (name == null) return;
    if (name.isEmpty) {
      _showSnack('نام متغیر نمی‌تواند خالی باشد.');
      return;
    }
    if (name.length > 30) {
      _showSnack('نام متغیر نمی‌تواند بیشتر از ۳۰ کاراکتر باشد.');
      return;
    }
    if (_data.variables.contains(name)) {
      _showSnack('این متغیر قبلاً وجود دارد.');
      return;
    }
    setState(() => _data.addVariable(name));
    await _persist();
  }

  // ---------------------------------------------------------------------
  // مدیریت افراد
  // ---------------------------------------------------------------------

  String? _validatePersonName(String name, {int? editingIndex}) {
    if (name.trim().isEmpty) return 'نام فرد نمی‌تواند خالی باشد.';
    if (name.length > 30) return 'نام فرد نمی‌تواند بیشتر از ۳۰ کاراکتر باشد.';
    final dupIndex = _data.individuals.indexOf(name);
    if (editingIndex != null) {
      if (dupIndex != -1 && dupIndex != editingIndex) return 'این نام قبلاً برای فرد دیگری استفاده شده است.';
    } else {
      if (_data.individuals.length >= kMaxChartPeople) return 'حداکثر ۵ نفر می‌توانند اضافه شوند.';
      if (dupIndex != -1) return 'این فرد قبلاً وجود دارد.';
    }
    return null;
  }

  Future<void> _showPeopleSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(builder: (ctx, setSheetState) {
        Future<void> refresh() async {
          setSheetState(() {});
          setState(() {});
          await _persist();
        }

        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFFFAF0),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sheetHandle(),
              const Text('افراد', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF6B4D2E))),
              const SizedBox(height: 10),
              for (int i = 0; i < _data.individuals.length; i++)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF5E5C8)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Color(0xFF2C6B9E), size: 20),
                        tooltip: 'ویرایش',
                        onPressed: () async {
                          final name = await _promptName(title: 'ویرایش نام فرد', initial: _data.individuals[i]);
                          if (name == null) return;
                          final err = _validatePersonName(name, editingIndex: i);
                          if (err != null) {
                            _showSnack(err);
                            return;
                          }
                          _data.renamePerson(i, name);
                          await refresh();
                        },
                      ),
                      Expanded(
                        child: Text(
                          _data.individuals[i],
                          textAlign: TextAlign.right,
                          style: TextStyle(color: Color(_data.colorOf(i)), fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFFD94D45)),
                        tooltip: 'حذف',
                        onPressed: () async {
                          final ok = await _confirm(
                              'آیا مطمئن هستید که می‌خواهید «${_data.individuals[i]}» حذف شود؟ تمام تاریخ‌ها و مقادیر ثبت‌شده برای این فرد نیز حذف خواهند شد.');
                          if (ok == true) {
                            _resetValueControllers();
                            _data.removePerson(i);
                            await refresh();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              if (_data.individuals.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('هنوز فردی اضافه نشده', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                ),
              const SizedBox(height: 6),
              ElevatedButton.icon(
                onPressed: () async {
                  if (_data.individuals.length >= kMaxChartPeople) {
                    _showSnack('حداکثر ۵ نفر می‌توانند اضافه شوند.');
                    return;
                  }
                  final name = await _promptName(title: 'نام فرد را بنویسید');
                  if (name == null) return;
                  final err = _validatePersonName(name);
                  if (err != null) {
                    _showSnack(err);
                    return;
                  }
                  _data.addPerson(name);
                  await refresh();
                },
                icon: const Icon(Icons.person_add),
                label: const Text('افزودن (حداکثر ۵ نام)'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7CB342), foregroundColor: Colors.white),
              ),
            ],
          ),
        );
      }),
    );
  }

  // ---------------------------------------------------------------------
  // تاریخ‌ها (با استفاده از انتخاب‌گر تاریخ شمسیِ مشترکِ صفحه‌ی تقویم)
  // ---------------------------------------------------------------------

  Jalali? _parseJalaliOrNull(String date) {
    final normalized = normalizeDigits(date);
    final parts = normalized.split('/').map((p) => int.tryParse(p.trim())).toList();
    if (parts.length != 3 || parts.any((p) => p == null)) return null;
    try {
      return Jalali(parts[0]!, parts[1]!, parts[2]!);
    } catch (_) {
      return null;
    }
  }

  String _formatJalali(Jalali j) =>
      toFaDigits('${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}');

  Future<void> _addDate() async {
    if (_data.currentVariable == null) {
      _showSnack('ابتدا یک متغیر انتخاب یا اضافه کنید.');
      return;
    }
    final picked = await showJalaliDatePicker(context);
    if (picked == null) return;
    final dateStr = _formatJalali(picked);
    final added = _data.addDateToCurrent(dateStr);
    if (!added) {
      await _alert('این تاریخ قبلاً ثبت شده است. لطفاً تاریخ دیگری انتخاب کنید.');
      return;
    }
    setState(() {});
    await _persist();
  }

  Future<void> _editRowDate(int rowIndex) async {
    final rows = _data.currentRows;
    final row = rows[rowIndex];
    final initial = _parseJalaliOrNull(row.date) ?? Jalali.now();
    final picked = await showJalaliDatePicker(context, initial: initial);
    if (picked == null) return;
    final newDate = _formatJalali(picked);
    final duplicate = rows.any((r) => r != row && r.date == newDate);
    if (duplicate) {
      await _alert('این تاریخ قبلاً ثبت شده است. لطفاً تاریخ دیگری انتخاب کنید.');
      return;
    }
    row.date = newDate;
    setState(() => sortChartRows(rows));
    await _persist();
  }

  Future<void> _deleteRow(int rowIndex) async {
    final ok = await _confirm('آیا می‌خواهید این تاریخ را حذف کنید؟');
    if (ok != true) return;
    final rows = _data.currentRows;
    final row = rows[rowIndex];
    for (int i = 0; i < row.values.length; i++) {
      _valueControllers.remove('${identityHashCode(row)}_$i')?.dispose();
    }
    setState(() => rows.removeAt(rowIndex));
    await _persist();
  }

  Future<void> _clearAll() async {
    final ok = await _confirm(
        'آیا از حذف تمام افراد، متغیرها، تاریخ‌ها و مقادیر آنها مطمئنید؟ (متغیر «وزن» به‌صورت خالی باقی می‌ماند)');
    if (ok != true) return;
    _resetValueControllers();
    setState(() => _data.clearAll());
    await _persist();
  }

  // ---------------------------------------------------------------------
  // جدول داده‌ها
  // ---------------------------------------------------------------------

  Widget _headerCell(String text, double width, Color color) => SizedBox(
        width: width,
        child: Center(
          child: Text(
            text,
            style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );

  Widget _buildDataRow(int rowIndex, double dateColWidth, double colWidth) {
    final rows = _data.currentRows;
    final row = rows[rowIndex];
    return Container(
      key: ValueKey(identityHashCode(row)),
      height: 56,
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFC4CBC9)))),
      child: Row(
        children: [
          SizedBox(
            width: dateColWidth,
            child: InkWell(
              onTap: () => _editRowDate(rowIndex),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(row.date,
                        style: const TextStyle(color: Color(0xFF8B4513), fontSize: 15), overflow: TextOverflow.ellipsis),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.close, size: 16, color: Color(0xFFD94D45)),
                    tooltip: 'حذف تاریخ',
                    onPressed: () => _deleteRow(rowIndex),
                  ),
                ],
              ),
            ),
          ),
          for (int i = 0; i < _data.individuals.length; i++)
            SizedBox(
              width: colWidth,
              child: TextField(
                controller: _valueControllerFor(row, i),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF1558DF), fontSize: 15),
                decoration: const InputDecoration(border: InputBorder.none, hintText: 'مقدار', isDense: true),
                onChanged: (v) {
                  while (row.values.length <= i) {
                    row.values.add('');
                  }
                  row.values[i] = v;
                  setState(() {});
                },
                onTapOutside: (_) {
                  FocusScope.of(context).unfocus();
                  unawaited(_persist());
                },
                onEditingComplete: () {
                  FocusScope.of(context).unfocus();
                  unawaited(_persist());
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    final rows = _data.currentRows;
    final people = _data.individuals;
    const dateColWidth = 118.0;
    const colWidth = 92.0;
    final totalWidth = dateColWidth + people.length * colWidth;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE2E5E4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD7E1DF)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: totalWidth,
            child: Column(
              children: [
                Container(
                  height: 40,
                  color: const Color(0xFFB3E0F2),
                  child: Row(
                    children: [
                      _headerCell('تاریخ', dateColWidth, const Color(0xFF183A49)),
                      for (int i = 0; i < people.length; i++)
                        _headerCell(people[i], colWidth, Color(_data.colorOf(i))),
                    ],
                  ),
                ),
                SizedBox(
                  height: 140,
                  child: rows.isEmpty
                      ? const Center(child: Text('تاریخی ثبت نشده', style: TextStyle(color: Colors.grey, fontSize: 12)))
                      : ListView.builder(
                          itemCount: rows.length,
                          itemBuilder: (context, rowIndex) => _buildDataRow(rowIndex, dateColWidth, colWidth),
                        ),
                ),
                Container(
                  height: 40,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: dateColWidth - 16,
                    height: 30,
                    child: ElevatedButton(
                      onPressed: _addDate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC8E6C9),
                        foregroundColor: const Color(0xFF2E5C31),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text('افزودن تاریخ', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // راهنمای رنگ (Legend) و نمودار
  // ---------------------------------------------------------------------

  Widget _buildLegend() {
    if (_data.individuals.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        for (int i = 0; i < _data.individuals.length; i++)
          GestureDetector(
            onTap: () {
              setState(() => _data.visibility[i] = !_data.visibility[i]);
              unawaited(_persist());
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _data.visibility[i] ? const Color(0xFFFFF9C4) : const Color(0xFFDCDCDC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2DCCD)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Opacity(opacity: _data.visibility[i] ? 1 : 0.35, child: const Text('💡', style: TextStyle(fontSize: 14))),
                  const SizedBox(width: 6),
                  Text(_data.individuals[i],
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(_data.colorOf(i)))),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildChartSection() {
    final rows = _data.currentRows;
    final scale = _scaleForRows(rows);
    const chartHeight = 200.0;
    const axisWidth = 46.0;
    const minSpacing = 36.0;

    return Column(
      children: [
        Text(
          _data.currentVariable != null
              ? 'نمایش و عدم نمایش نمودار ${_data.currentVariable} هر فرد'
              : 'هیچ متغیری وجود ندارد',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF183A49)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        _buildLegend(),
        const SizedBox(height: 4),
        Expanded(
          child: (rows.isEmpty || _data.individuals.isEmpty)
              ? const Center(
                  child: Text('برای رسم نمودار، حداقل یک فرد و یک تاریخ اضافه کنید.',
                      style: TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
                )
              : LayoutBuilder(builder: (context, constraints) {
                  final viewportWidth = constraints.maxWidth - axisWidth;
                  final n = rows.length;
                  final neededWidth = n > 1 ? (n - 1) * minSpacing + 30 : viewportWidth;
                  final drawWidth = math.max(viewportWidth, neededWidth);
                  return Row(
                    children: [
                      SizedBox(
                        width: axisWidth,
                        height: chartHeight,
                        child: CustomPaint(painter: _AxisPainter(scale: scale)),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: drawWidth,
                            height: chartHeight,
                            child: CustomPaint(
                              painter: _LineChartPainter(
                                rows: rows,
                                visibility: _data.visibility,
                                colorIndices: _data.colorIndices,
                                scale: scale,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // پشتیبان‌گیری / بازیابی
  // ---------------------------------------------------------------------

  Future<void> _showBackupSheet() async {
    final json = _storage.exportBackupJson(_data);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('پشتیبان اطلاعات', textAlign: TextAlign.center),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('می‌توانید فایل پشتیبان (JSON) را به اشتراک بگذارید یا متن آن را کپی کنید:',
                  style: TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              Container(
                height: 130,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4FAF5),
                  border: Border.all(color: const Color(0xFFCFE3D3)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(json, textDirection: TextDirection.ltr, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                ),
              ),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: json));
              _showSnack('متن پشتیبان کپی شد.');
            },
            child: const Text('📋 کپی متن'),
          ),
          ElevatedButton(
            onPressed: () => _shareBackupFile(json),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2196F3), foregroundColor: Colors.white),
            child: const Text('اشتراک‌گذاری فایل'),
          ),
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('بستن')),
        ],
      ),
    );
  }

  Future<void> _shareBackupFile(String json) async {
    try {
      final dir = await getTemporaryDirectory();
      final stamp = _formatJalali(Jalali.now());
      final file = File('${dir.path}/نمودار-ساز-پشتیبان-$stamp.json');
      await file.writeAsString(json);
      await Share.shareXFiles([XFile(file.path)], text: 'پشتیبان نمودار ساز');
    } catch (_) {
      _showSnack('اشتراک‌گذاری فایل ممکن نشد؛ از گزینه «کپی متن» استفاده کنید.');
    }
  }

  Future<void> _showRestoreSheet() async {
    final controller = TextEditingController();
    String? error;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (ctx, setDialogState) {
        return AlertDialog(
          title: const Text('بازیابی از پشتیبان', textAlign: TextAlign.center),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('فایل پشتیبان را از طریق «اشتراک‌گذاری فایل» فرستاده‌اید؟ متن JSON آن را اینجا جای‌گذاری (Paste) کنید:',
                    style: TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  maxLines: 6,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
              ],
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('انصراف')),
            ElevatedButton(
              onPressed: () async {
                final text = controller.text.trim();
                if (text.isEmpty) {
                  setDialogState(() => error = 'متنی جای‌گذاری نشده است.');
                  return;
                }
                final parsed = _storage.parseBackupJson(text);
                if (parsed == null) {
                  setDialogState(() => error = 'متن وارد شده یک پشتیبان معتبر نیست.');
                  return;
                }
                Navigator.pop(dialogContext);
                final ok = await _confirm(
                    'بازیابی از پشتیبان، تمام اطلاعات فعلی برنامه را با اطلاعات این فایل جایگزین می‌کند. آیا مطمئن هستید؟');
                if (ok == true) {
                  _resetValueControllers();
                  setState(() => _data = parsed);
                  await _persist();
                }
              },
              child: const Text('بازیابی'),
            ),
          ],
        );
      }),
    );
  }

  // ---------------------------------------------------------------------
  // خروجی تصویر نمودار
  // ---------------------------------------------------------------------

  Widget _buildExportChart() {
    final rows = _data.currentRows;
    if (rows.isEmpty || _data.individuals.isEmpty) {
      return const SizedBox(width: 1, height: 1);
    }
    final scale = _scaleForRows(rows);
    final visiblePeople = [for (int i = 0; i < _data.individuals.length; i++) if (_data.visibility[i]) i];
    const left = 64.0, right = 30.0, spacing = 70.0, top = 76.0, bottom = 64.0, plotH = 320.0;
    final n = rows.length;
    final plotW = n > 1 ? (n - 1) * spacing : 200.0;
    final width = left + plotW + right;
    final height = top + plotH + bottom;

    return Container(
      width: width,
      height: height,
      color: Colors.white,
      child: Stack(
        children: [
          Positioned(
            top: 14,
            left: 0,
            right: 0,
            child: Text(
              _data.currentVariable != null ? 'نمایش و عدم نمایش نمودار ${_data.currentVariable} هر فرد' : 'نمودار',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF183A49)),
            ),
          ),
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 14,
              children: [
                for (final i in visiblePeople)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(color: Color(_data.colorOf(i)), borderRadius: BorderRadius.circular(3)),
                    ),
                    const SizedBox(width: 4),
                    Text(_data.individuals[i],
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF3B2E32))),
                  ]),
              ],
            ),
          ),
          Positioned(
            top: top,
            left: 0,
            width: width,
            height: plotH,
            child: CustomPaint(
              painter: _ExportChartPainter(
                rows: rows,
                visibleIndividuals: visiblePeople,
                colorIndices: _data.colorIndices,
                scale: scale,
                leftPad: left,
                rightPad: right,
                spacing: spacing,
              ),
            ),
          ),
          Positioned(
            top: top + plotH + 10,
            left: 0,
            width: width,
            height: bottom,
            child: Stack(
              children: [
                for (int idx = 0; idx < rows.length; idx++)
                  Positioned(
                    left: left + idx * (n > 1 ? spacing : 0) - 40,
                    top: 0,
                    width: 80,
                    child: Transform.rotate(
                      angle: -0.6,
                      alignment: Alignment.topRight,
                      child: Text(rows[idx].date,
                          textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7873))),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportChartImage() async {
    final rows = _data.currentRows;
    if (rows.isEmpty || _data.individuals.isEmpty) {
      await _alert('داده‌ای برای رسم نمودار وجود ندارد.');
      return;
    }
    setState(() => _preparingExport = true);
    // یک فریم صبر می‌کنیم تا ویجت (نامرئیِ) خروجی واقعاً رسم شده باشد
    await Future.delayed(const Duration(milliseconds: 60));
    try {
      final boundary = _exportKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('render-not-ready');
      final image = await boundary.toImage(pixelRatio: 2);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('no-bytes');
      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final stamp = _formatJalali(Jalali.now());
      final safeTitle = (_data.currentVariable ?? 'نمودار').replaceAll(RegExp(r'[\\/:*?"<>|]'), '');
      final file = File('${dir.path}/نمودار-$safeTitle-$stamp.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'نمودار $safeTitle');
    } catch (_) {
      if (mounted) await _alert('ساخت تصویر نمودار با خطا مواجه شد.');
    } finally {
      if (mounted) setState(() => _preparingExport = false);
    }
  }

  // ---------------------------------------------------------------------
  // دکمه‌های پایین صفحه
  // ---------------------------------------------------------------------

  Widget _bottomButton(String label, VoidCallback? onTap, {bool danger = false}) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: danger ? const Color(0xFFFAE3E3) : const Color(0xFFDCEEE3),
        foregroundColor: danger ? const Color(0xFFBA6868) : const Color(0xFF4D7560),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _buildBottomButtons() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _bottomButton('↑ پشتیبان‌گیری', _showBackupSheet),
        _bottomButton('↓ بازیابی از پشتیبان', _showRestoreSheet),
        _bottomButton(_preparingExport ? '⏳ در حال ساخت...' : '🖼 ذخیره نمودار (تصویر)', _preparingExport ? null : _exportChartImage),
        _bottomButton('حذف همه اطلاعات', _clearAll, danger: true),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // ساختار کلی صفحه
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('نمودار ساز')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFEDF8F1),
      appBar: AppBar(
        title: const Text('📊 نمودار ساز', style: TextStyle(color: Color(0xFF1558DF), fontWeight: FontWeight.bold)),
      ),
      body: Stack(
        children: [
          GestureDetector(
            onHorizontalDragEnd: (details) {
              if ((details.primaryVelocity ?? 0).abs() > 200) {
                Navigator.of(context).maybePop();
              }
            },
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Material(
                            color: const Color(0xFFE8DCC8),
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: _showVariableSheet,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _data.currentVariable ?? 'هیچ متغیری وجود ندارد',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 15, color: Color(0xFF4B3A2E), fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const Icon(Icons.arrow_drop_down, color: Color(0xFF8A6D4A)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Material(
                          color: const Color(0xFFC8E6C9),
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: _showPeopleSheet,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              child: Text('افراد 👥',
                                  style: TextStyle(color: Color(0xFF2E5C31), fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildTable(),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFFD9ECF5), borderRadius: BorderRadius.circular(16)),
                        child: _buildChartSection(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildBottomButtons(),
                  ],
                ),
              ),
            ),
          ),
          // ویجت نامرئیِ خروجیِ نمودار: فقط برای گرفتن تصویر استفاده می‌شود و
          // هرگز روی صفحه دیده نمی‌شود (خارج از محدوده‌ی قابل‌مشاهده قرار دارد).
          Positioned(
            left: -5000,
            top: 0,
            child: IgnorePointer(
              child: RepaintBoundary(key: _exportKey, child: _buildExportChart()),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// محاسبه‌ی مقیاس محور عمودی («عدد گرد و خوانا»، الگوریتم استاندارد nice-number)
// =============================================================================

class _ChartScale {
  final double min;
  final double max;
  final double step;
  const _ChartScale(this.min, this.max, this.step);
}

double _niceNumber(double range, bool round) {
  if (range == 0) return 0;
  final exponent = (math.log(range.abs()) / math.ln10).floor();
  final fraction = range.abs() / math.pow(10, exponent);
  double niceFraction;
  if (round) {
    if (fraction < 1.5) {
      niceFraction = 1;
    } else if (fraction < 3) {
      niceFraction = 2;
    } else if (fraction < 7) {
      niceFraction = 5;
    } else {
      niceFraction = 10;
    }
  } else {
    if (fraction <= 1) {
      niceFraction = 1;
    } else if (fraction <= 2) {
      niceFraction = 2;
    } else if (fraction <= 5) {
      niceFraction = 5;
    } else {
      niceFraction = 10;
    }
  }
  return niceFraction * math.pow(10, exponent).toDouble();
}

_ChartScale _computeNiceScale(double minValIn, double maxValIn, int maxTicks) {
  double minVal = minValIn;
  double maxVal = maxValIn;
  if (minVal == maxVal) {
    minVal -= 1;
    maxVal += 1;
  }
  final rawRange = _niceNumber(maxVal - minVal, false);
  final step = _niceNumber(rawRange / (maxTicks - 1), true);
  final niceMin = (minVal / step).floor() * step;
  final niceMax = (maxVal / step).ceil() * step;
  return _ChartScale(niceMin, niceMax, step);
}

String _formatAxisValue(double val, double step) {
  final decimalsRaw = -(math.log(step) / math.ln10).floor();
  final decimals = decimalsRaw < 0 ? 0 : decimalsRaw;
  final fixed = val.abs() < step / 1e6 ? 0.0 : val;
  return toFaDigits(fixed.toStringAsFixed(decimals));
}

_ChartScale _scaleForRows(List<ChartRow> rows) {
  double rawMin = double.infinity;
  double rawMax = -double.infinity;
  for (final row in rows) {
    for (final v in row.values) {
      final val = parseFaNumber(v);
      if (val != null) {
        if (val > rawMax) rawMax = val;
        if (val < rawMin) rawMin = val;
      }
    }
  }
  if (!rawMin.isFinite || !rawMax.isFinite) {
    rawMin = 0;
    rawMax = 1;
  }
  return _computeNiceScale(rawMin, rawMax, 6);
}

// =============================================================================
// نقاش محور عمودی (ستون ثابت، خارج از ناحیه‌ی اسکرول‌شونده‌ی نمودار)
// =============================================================================

class _AxisPainter extends CustomPainter {
  final _ChartScale scale;
  final double paddingTop;
  final double paddingBottom;

  _AxisPainter({required this.scale, this.paddingTop = 20, this.paddingBottom = 10});

  @override
  void paint(Canvas canvas, Size size) {
    final drawingHeight = size.height - paddingTop - paddingBottom;
    double valueToY(double val) => paddingTop + (1 - (val - scale.min) / (scale.max - scale.min)) * drawingHeight;
    final tickCount = ((scale.max - scale.min) / scale.step).round();
    String? lastLabel;
    double? lastY;
    for (int i = 0; i <= tickCount; i++) {
      final tickVal = scale.min + i * scale.step;
      final formatted = _formatAxisValue(tickVal, scale.step);
      final y = valueToY(tickVal);
      if (formatted == lastLabel || (lastY != null && (y - lastY).abs() < 20)) continue;
      lastLabel = formatted;
      lastY = y;
      final tp = TextPainter(
        text: TextSpan(text: formatted, style: const TextStyle(color: Color(0xFF4A5B57), fontWeight: FontWeight.bold, fontSize: 13)),
        textDirection: TextDirection.rtl,
      )..layout();
      tp.paint(canvas, Offset(size.width - tp.width - 4, y - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _AxisPainter oldDelegate) =>
      oldDelegate.scale.min != scale.min || oldDelegate.scale.max != scale.max || oldDelegate.scale.step != scale.step;
}

// =============================================================================
// نقاش نمودار خطی (ناحیه‌ی اسکرول‌شونده‌ی افقی)
// =============================================================================

class _LineChartPainter extends CustomPainter {
  final List<ChartRow> rows;
  final List<bool> visibility;
  final List<int> colorIndices;
  final _ChartScale scale;
  final double innerLeftPad;
  final double innerRightPad;
  final double paddingTop;
  final double paddingBottom;

  _LineChartPainter({
    required this.rows,
    required this.visibility,
    required this.colorIndices,
    required this.scale,
    this.innerLeftPad = 14,
    this.innerRightPad = 15,
    this.paddingTop = 20,
    this.paddingBottom = 10,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final drawingHeight = size.height - paddingTop - paddingBottom;
    double valueToY(double val) => paddingTop + (1 - (val - scale.min) / (scale.max - scale.min)) * drawingHeight;
    final n = rows.length;
    final plotWidth = size.width - innerLeftPad - innerRightPad;
    final xStep = n > 1 ? plotWidth / (n - 1) : 0.0;

    final gridPaint = Paint()
      ..color = const Color(0xFFD7DFDA)
      ..strokeWidth = 1;
    final tickCount = ((scale.max - scale.min) / scale.step).round();
    for (int i = 0; i <= tickCount; i++) {
      final y = valueToY(scale.min + i * scale.step);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (int p = 0; p < visibility.length; p++) {
      if (!visibility[p]) continue;
      final color = Color(chartColorPalette[colorIndices[p] % chartColorPalette.length]);
      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      final dotPaint = Paint()..color = color;
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;

      final points = <Offset>[];
      for (int r = 0; r < rows.length; r++) {
        final v = p < rows[r].values.length ? parseFaNumber(rows[r].values[p]) : null;
        if (v != null) {
          points.add(Offset(innerLeftPad + r * xStep, valueToY(v)));
        }
      }
      for (int i = 0; i < points.length - 1; i++) {
        canvas.drawLine(points[i], points[i + 1], linePaint);
      }
      for (final pt in points) {
        canvas.drawCircle(pt, 5, dotPaint);
        canvas.drawCircle(pt, 5, borderPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) => true;
}

// =============================================================================
// نقاش نسخه‌ی خروجیِ (کامل و بدون اسکرول) نمودار، برای تبدیل به تصویر PNG
// =============================================================================

class _ExportChartPainter extends CustomPainter {
  final List<ChartRow> rows;
  final List<int> visibleIndividuals;
  final List<int> colorIndices;
  final _ChartScale scale;
  final double leftPad;
  final double rightPad;
  final double spacing;

  _ExportChartPainter({
    required this.rows,
    required this.visibleIndividuals,
    required this.colorIndices,
    required this.scale,
    required this.leftPad,
    required this.rightPad,
    required this.spacing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double valueToY(double val) => (1 - (val - scale.min) / (scale.max - scale.min)) * size.height;
    final n = rows.length;

    final gridPaint = Paint()
      ..color = const Color(0xFFDBE4E0)
      ..strokeWidth = 1;
    final tickCount = ((scale.max - scale.min) / scale.step).round();
    for (int i = 0; i <= tickCount; i++) {
      final tickVal = scale.min + i * scale.step;
      final y = valueToY(tickVal);
      canvas.drawLine(Offset(leftPad, y), Offset(size.width - rightPad, y), gridPaint);
      final label = _formatAxisValue(tickVal, scale.step);
      final tp = TextPainter(
        text: TextSpan(text: label, style: const TextStyle(color: Color(0xFF4A5B57), fontWeight: FontWeight.bold, fontSize: 13)),
        textDirection: TextDirection.rtl,
      )..layout();
      tp.paint(canvas, Offset(leftPad - tp.width - 8, y - tp.height / 2));
    }

    for (final p in visibleIndividuals) {
      final color = Color(chartColorPalette[colorIndices[p] % chartColorPalette.length]);
      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      final dotPaint = Paint()..color = color;
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      final points = <Offset>[];
      for (int idx = 0; idx < rows.length; idx++) {
        final v = p < rows[idx].values.length ? parseFaNumber(rows[idx].values[p]) : null;
        if (v != null) points.add(Offset(leftPad + idx * (n > 1 ? spacing : 0), valueToY(v)));
      }
      for (int i = 0; i < points.length - 1; i++) {
        canvas.drawLine(points[i], points[i + 1], linePaint);
      }
      for (final pt in points) {
        canvas.drawCircle(pt, 5.5, dotPaint);
        canvas.drawCircle(pt, 5.5, borderPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ExportChartPainter oldDelegate) => true;
}
