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
  // با هر تغییرِ نمایشِ افراد زیاد می‌شود تا صفحه‌ی تمام‌صفحه‌ی نمودار هم تازه شود
  final ValueNotifier<int> _fsTick = ValueNotifier<int>(0);
  final GlobalKey _variableFieldKey = GlobalKey();
  final GlobalKey _peopleFieldKey = GlobalKey();
  final Map<String, TextEditingController> _valueControllers = {};
  final Map<String, FocusNode> _valueFocusNodes = {};
  final _rowsScrollController = ScrollController();
  OverlayEntry? _dropdownOverlay;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _closeDropdown();
    _resetValueControllers();
    _rowsScrollController.dispose();
    _fsTick.dispose();
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
    _focusLastRowValue(scrollOnly: true);
  }

  Future<void> _persist() => _storage.save(_data);

  void _resetValueControllers() {
    for (final c in _valueControllers.values) {
      c.dispose();
    }
    _valueControllers.clear();
    for (final f in _valueFocusNodes.values) {
      f.dispose();
    }
    _valueFocusNodes.clear();
  }

  TextEditingController _valueControllerFor(ChartRow row, int personIndex) {
    final key = '${identityHashCode(row)}_$personIndex';
    return _valueControllers.putIfAbsent(key, () {
      final initial = personIndex < row.values.length ? row.values[personIndex] : '';
      return TextEditingController(text: initial);
    });
  }

  FocusNode _valueFocusNodeFor(ChartRow row, int personIndex) {
    final key = '${identityHashCode(row)}_$personIndex';
    return _valueFocusNodes.putIfAbsent(key, () => FocusNode());
  }

  /// خطِ چشمک‌زن را همیشه روی مقدارِ (فردِ اول در) آخرین ردیف قرار می‌دهد و
  /// جدول را به پایین اسکرول می‌کند تا آن ردیف دیده شود. با [scrollOnly] فقط
  /// اسکرول انجام می‌شود (بدون گرفتنِ فوکوس)، برای زمانی که صفحه تازه باز
  /// شده و نمی‌خواهیم بی‌مقدمه کیبورد بالا بیاید.
  void _focusLastRowValue({bool scrollOnly = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_rowsScrollController.hasClients) {
        _rowsScrollController.jumpTo(_rowsScrollController.position.maxScrollExtent);
      }
      if (scrollOnly) return;
      final rows = _data.currentRows;
      if (rows.isEmpty || _data.individuals.isEmpty) return;
      _valueFocusNodeFor(rows.last, 0).requestFocus();
    });
  }

  void _closeDropdown() {
    _dropdownOverlay?.remove();
    _dropdownOverlay = null;
  }

  /// یک منوی کشویی دقیقاً زیرِ همان فیلدی که لمس شده باز می‌کند (نه به‌صورت
  /// شیت از پایین صفحه). با زدن هرجای بیرون از منو بسته می‌شود؛ محتوای داخلش
  /// (با کمک setSheetState) بدون بسته‌شدنِ منو زنده بروزرسانی می‌شود.
  void _openAnchoredDropdown({
    required GlobalKey anchorKey,
    required Widget Function(BuildContext context, StateSetter setSheetState, VoidCallback close) builder,
  }) {
    _closeDropdown();
    final renderBox = anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);
    final screenHeight = MediaQuery.of(context).size.height;

    late OverlayEntry entry;
    void close() {
      entry.remove();
      if (identical(_dropdownOverlay, entry)) _dropdownOverlay = null;
    }

    entry = OverlayEntry(
      builder: (overlayContext) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: close,
                child: const SizedBox.shrink(),
              ),
            ),
            Positioned(
              left: offset.dx,
              top: offset.dy + size.height + 4,
              width: size.width,
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                elevation: 6,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: (screenHeight - offset.dy - size.height - 24).clamp(120.0, 420.0)),
                  child: StatefulBuilder(builder: (ctx, setSheetState) => builder(ctx, setSheetState, close)),
                ),
              ),
            ),
          ],
        );
      },
    );
    _dropdownOverlay = entry;
    Overlay.of(context).insert(entry);
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

  Future<String?> _promptName({required String title, String initial = ''}) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
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
    controller.dispose();
    return result;
  }

  // ---------------------------------------------------------------------
  // مدیریت متغیرها
  // ---------------------------------------------------------------------

  void _showVariableSheet() {
    _openAnchoredDropdown(
      anchorKey: _variableFieldKey,
      builder: (dropdownCtx, setSheetState, close) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFFF5F7),
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('متغیرها', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              for (final v in _data.variables)
                ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  tileColor: v == _data.currentVariable ? const Color(0xFFFFEEF2) : Colors.white,
                  title: Text(v, textAlign: TextAlign.right),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    tooltip: 'حذف متغیر',
                    onPressed: () async {
                      close();
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
                    close();
                    _focusLastRowValue(scrollOnly: true);
                  },
                ),
              const SizedBox(height: 6),
              ElevatedButton.icon(
                onPressed: () {
                  close();
                  _addVariableDialog();
                },
                icon: const Icon(Icons.add),
                label: const Text('افزودن متغیر'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7CB342), foregroundColor: Colors.white),
              ),
            ],
          ),
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

  void _showPeopleSheet() {
    _openAnchoredDropdown(
      anchorKey: _peopleFieldKey,
      builder: (dropdownCtx, setSheetState, close) {
        Future<void> refresh() async {
          setSheetState(() {});
          setState(() {});
          await _persist();
        }

        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFFFAF0),
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
          ),
        );
      },
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

  /// یک برچسبِ زمانیِ امن برای «نام فایل» (بدون هیچ کاراکتر جداکننده‌ی
  /// مسیر مثل «/»؛ برخلاف [_formatJalali] که برای نمایش استفاده می‌شود).
  /// نبودِ این تفکیک باعث می‌شد اسلش‌های داخل تاریخِ نمایشی به‌اشتباه به‌عنوان
  /// جداکننده‌ی پوشه در مسیر فایل تفسیر شوند و نوشتنِ فایل (و درنتیجه
  /// اشتراک‌گذاری) با خطا مواجه شود.
  String _fileTimestamp() {
    final j = Jalali.now();
    final now = DateTime.now();
    final datePart = '${j.year}${j.month.toString().padLeft(2, '0')}${j.day.toString().padLeft(2, '0')}';
    final timePart =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    return '$datePart-$timePart';
  }

  Future<void> _addDate() async {
    if (_data.currentVariable == null) {
      _showSnack('ابتدا یک متغیر انتخاب یا اضافه کنید.');
      return;
    }
    final picked = await showJalaliDatePicker(context, typableYear: true);
    if (picked == null) return;
    final dateStr = _formatJalali(picked);
    final added = _data.addDateToCurrent(dateStr);
    if (!added) {
      await _alert('این تاریخ قبلاً ثبت شده است. لطفاً تاریخ دیگری انتخاب کنید.');
      return;
    }
    setState(() {});
    await _persist();
    _focusLastRowValue();
  }

  Future<void> _editRowDate(int rowIndex) async {
    final rows = _data.currentRows;
    final row = rows[rowIndex];
    final initial = _parseJalaliOrNull(row.date) ?? Jalali.now();
    final picked = await showJalaliDatePicker(context, initial: initial, typableYear: true);
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
    _focusLastRowValue(scrollOnly: true);
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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.date,
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        softWrap: false,
                        style: const TextStyle(color: Color(0xFF8B4513), fontSize: 15),
                      ),
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
          ),
          for (int i = 0; i < _data.individuals.length; i++)
            SizedBox(
              width: colWidth,
              child: TextField(
                controller: _valueControllerFor(row, i),
                focusNode: _valueFocusNodeFor(row, i),
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

  /// ردیفِ همیشه-حاضرِ «افزودنِ تاریخِ جدید»؛ دقیقاً هم‌شکلِ یک ردیفِ داده‌ی
  /// معمولی است (یک سلولِ تاریخ + سلول‌های مقدار) اما به‌جای مقدارِ واقعی،
  /// راهنمای خالی نشان می‌دهد. همیشه به‌عنوان آخرین ردیفِ جدول رسم می‌شود؛
  /// با لمسِ سلولِ تاریخ، انتخاب‌گرِ تاریخِ شمسی باز می‌شود (همان [_addDate]).
  Widget _buildAddRow(double dateColWidth, double colWidth) {
    return Container(
      height: 56,
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFC4CBC9)))),
      child: Row(
        children: [
          SizedBox(
            width: dateColWidth,
            child: InkWell(
              onTap: _addDate,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'تاریخ را وارد کنید',
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 14, fontStyle: FontStyle.italic),
                      ),
                    ),
                    const Icon(Icons.add_circle_outline, size: 18, color: Color(0xFF2E7D32)),
                  ],
                ),
              ),
            ),
          ),
          for (int i = 0; i < _data.individuals.length; i++)
            SizedBox(
              width: colWidth,
              child: const Center(
                child: Text('مقدار', style: TextStyle(color: Color(0xFFB0B0B0), fontSize: 14)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    final rows = _data.currentRows;
    final people = _data.individuals;
    const dateColWidth = 150.0;
    const colWidth = 92.0;
    const rowHeight = 56.0;
    final totalWidth = dateColWidth + people.length * colWidth;
    // +۱ برای ردیفِ همیشه-حاضرِ «افزودن تاریخ» در انتهای جدول.
    final itemCount = rows.length + 1;

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
                // ارتفاع دقیقاً به‌اندازه‌ی دو ردیف است تا به‌طور پیش‌فرض
                // (پس از اسکرول خودکار به پایین) فقط دو ردیفِ انتهایی دیده
                // شوند؛ برای دیدن بقیه‌ی ردیف‌ها باید اسکرول کرد.
                SizedBox(
                  height: rowHeight * 2,
                  child: ListView.builder(
                    controller: _rowsScrollController,
                    itemCount: itemCount,
                    itemBuilder: (context, index) {
                      if (index == rows.length) {
                        return _buildAddRow(dateColWidth, colWidth);
                      }
                      return _buildDataRow(index, dateColWidth, colWidth);
                    },
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
              _fsTick.value++;
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

  /// نمودار را در یک صفحه‌ی تمام‌صفحه باز می‌کند (با همان زوم دوانگشتی)
  Future<void> _openFullScreenChart() {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (ctx) => Scaffold(
          backgroundColor: const Color(0xFFD9ECF5),
          body: SafeArea(
            child: Padding(
              // فاصله‌ی زیادِ پایین: روی گوشی‌های جدید (نوار حرکتی / گوشه‌های گرد)
              // قسمتِ پایینِ صفحه بریده یا پنهان می‌شود، پس نمودار بالاتر از آن
              // تمام می‌شود.
              padding: EdgeInsets.fromLTRB(10, 6, 10, MediaQuery.of(ctx).padding.bottom + 64),
              child: ValueListenableBuilder<int>(
                valueListenable: _fsTick,
                builder: (context, _, __) {
                  final rows = _data.currentRows;
                  final scale = _scaleForRows(rows);
                  return Column(
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 44,
                            height: 40,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              tooltip: 'بستن',
                              icon: const Icon(Icons.fullscreen_exit, size: 30, color: Color(0xFF183A49)),
                              onPressed: () => Navigator.of(ctx).pop(),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              _data.currentVariable != null
                                  ? 'نمایش و عدم نمایش نمودار ${_data.currentVariable} هر فرد'
                                  : 'نمودار',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF183A49)),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 44),
                        ],
                      ),
                      const SizedBox(height: 4),
                      _buildLegend(),
                      const SizedBox(height: 4),
                      const Text(
                        'با دو انگشت زوم کنید  •  دوبار ضربه: نمایش کامل',
                        style: TextStyle(fontSize: 11, color: Color(0xFF5E7782)),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: (rows.isEmpty || _data.individuals.isEmpty)
                            ? const SizedBox.shrink()
                            : ClipRect(
                                child: _ZoomableChart(
                                  rows: rows,
                                  visibility: _data.visibility,
                                  colorIndices: _data.colorIndices,
                                  scale: scale,
                                ),
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChartSection() {
    final rows = _data.currentRows;
    final scale = _scaleForRows(rows);

    final hasChart = rows.isNotEmpty && _data.individuals.isNotEmpty;
    return Column(
      children: [
        Row(
          children: [
            // دکمه‌ی نمایشِ تمام‌صفحه
            SizedBox(
              width: 40,
              height: 32,
              child: hasChart
                  ? IconButton(
                      padding: EdgeInsets.zero,
                      tooltip: 'نمایش تمام‌صفحه',
                      icon: const Icon(Icons.fullscreen, size: 28, color: Color(0xFF183A49)),
                      onPressed: _openFullScreenChart,
                    )
                  : null,
            ),
            Expanded(
              child: Text(
                _data.currentVariable != null
                    ? 'نمایش و عدم نمایش نمودار ${_data.currentVariable} هر فرد'
                    : 'هیچ متغیری وجود ندارد',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF183A49)),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 40),
          ],
        ),
        const SizedBox(height: 6),
        _buildLegend(),
        const SizedBox(height: 2),
        const Text(
          'با دو انگشت زوم کنید  •  دوبار ضربه: نمایش کامل',
          style: TextStyle(fontSize: 11, color: Color(0xFF5E7782)),
        ),
        const SizedBox(height: 2),
        Expanded(
          child: (rows.isEmpty || _data.individuals.isEmpty)
              ? const Center(
                  child: Text('برای رسم نمودار، حداقل یک فرد و یک تاریخ اضافه کنید.',
                      style: TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
                )
              : ClipRect(
                  child: _ZoomableChart(
                    rows: rows,
                    visibility: _data.visibility,
                    colorIndices: _data.colorIndices,
                    scale: scale,
                  ),
                ),
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
      final stamp = _fileTimestamp();
      final file = File('${dir.path}/chart-backup-$stamp.json');
      await file.writeAsString(json);
      await Share.shareXFiles([XFile(file.path)], text: 'پشتیبان نمودار ساز');
    } catch (e) {
      _showSnack('اشتراک‌گذاری فایل ممکن نشد: $e');
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
    controller.dispose();
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
    // ابعاد طوری انتخاب می‌شود که تصویر نسبتِ «عادی» (نه خیلی پهن) داشته باشد و
    // در گالری بزرگ و خوانا دیده شود: فاصله‌ی نقطه‌ها متوسط، و ارتفاعِ نمودار
    // متناسب با عرض است.
    const left = 100.0, right = 44.0, bottom = 120.0;
    final n = rows.length;
    final spacing = n > 1 ? (1000.0 / (n - 1)).clamp(40.0, 110.0).toDouble() : 0.0;
    final plotW = n > 1 ? (n - 1) * spacing : 200.0;
    final width = left + plotW + right;
    final plotH = math.max(480.0, width * 0.5);

    return Container(
      width: width,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      // به‌جای موقعیت‌دهیِ مطلق (Stack/Positioned) با فاصله‌های ثابتِ از پیش
      // حدس‌زده‌شده، از یک چیدمانِ عمودیِ طبیعی (Column) استفاده می‌شود؛ به
      // این ترتیب اگر عنوان یا فهرستِ افراد به بیش از یک خط بشکند (مثلاً
      // نام متغیر طولانی یا تعداد زیاد افراد)، هیچ‌وقت روی نمودار زیرش
      // نمی‌افتد — هر بخش دقیقاً به‌اندازه‌ی ارتفاع واقعیِ خودش جا می‌گیرد.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _data.currentVariable != null ? 'نمایش و عدم نمایش نمودار ${_data.currentVariable} هر فرد' : 'نمودار',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF183A49)),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 14,
              runSpacing: 6,
              children: [
                for (final i in visiblePeople)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(color: Color(_data.colorOf(i)), borderRadius: BorderRadius.circular(4)),
                    ),
                    const SizedBox(width: 6),
                    Text(_data.individuals[i],
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF3B2E32))),
                  ]),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
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
          SizedBox(
            width: width,
            height: bottom,
            child: Stack(
              children: [
                for (int idx = 0; idx < rows.length; idx++)
                  Positioned(
                    left: left + idx * (n > 1 ? spacing : 0) - 100,
                    top: 8,
                    width: 100,
                    child: Transform.rotate(
                      angle: -0.6,
                      alignment: Alignment.topRight,
                      child: Text(rows[idx].date,
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF4A5B57))),
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
      // کیفیتِ بالا، ولی برای نمودارهای خیلی عریض از حدِ توانِ GPU (حدود ۸۰۰۰ پیکسل) رد نشود
      final pixelRatio = (6000 / boundary.size.width).clamp(1.0, 2.5).toDouble();
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('no-bytes');
      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final stamp = _fileTimestamp();
      final file = File('${dir.path}/chart-$stamp.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'نمودار ${_data.currentVariable ?? ''}');
    } catch (e) {
      if (mounted) await _alert('ساخت تصویر نمودار با خطا مواجه شد: $e');
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
          // کشیدنِ انگشت به چپ/راست دیگر باعث بازگشت به صفحه‌ی اصلی نمی‌شود.
          GestureDetector(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Material(
                            key: _variableFieldKey,
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
                                    const Icon(Icons.arrow_drop_down, color: Color(0xFF8A6D4A), size: 72),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Material(
                            key: _peopleFieldKey,
                            color: const Color(0xFF2E7D32),
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: _showPeopleSheet,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                child: Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'افراد 👥',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                    const Icon(Icons.arrow_drop_down, color: Colors.white, size: 72),
                                  ],
                                ),
                              ),
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
                    // فاصله‌ی اضافیِ متناسب با ناحیه‌ی امنِ پایین گوشی؛ روی
                    // بعضی گوشی‌های جدید (نوار حرکتی/گوشه‌های گرد) این ناحیه
                    // به‌درستی توسط SafeArea گزارش نمی‌شود، پس این فاصله‌ی
                    // اضافه باعث می‌شود دکمه‌ها همیشه با فاصله از لبه‌ی پایین
                    // (به‌اندازه‌ی ارتفاع خودشان) بالاتر بیایند.
                    SizedBox(height: MediaQuery.of(context).padding.bottom + 48),
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
// نمودارِ داخلِ صفحه با زومِ دو‌انگشتی
// =============================================================================
//
// زوم ۱ = کلِ نمودار دیده می‌شود. با دو انگشت (pinch) تا حدِ دیدنِ یک نقطه زوم
// می‌شود؛ با یک انگشت جابه‌جا می‌شود؛ دوبار ضربه = برگشت به نمایشِ کامل.
// اندازه‌ی نقطه‌ها و خط‌ها هنگامِ زوم ثابت می‌ماند و محورها هماهنگ با زوم
// دوباره محاسبه می‌شوند (مثلِ نمودارهای حرفه‌ای).

class _ZoomableChart extends StatefulWidget {
  final List<ChartRow> rows;
  final List<bool> visibility;
  final List<int> colorIndices;
  final _ChartScale scale;
  const _ZoomableChart({
    required this.rows,
    required this.visibility,
    required this.colorIndices,
    required this.scale,
  });

  @override
  State<_ZoomableChart> createState() => _ZoomableChartState();
}

class _ZoomableChartState extends State<_ZoomableChart> {
  static const double _leftAxis = 46, _rightPad = 14, _topPad = 14, _bottomPad = 46;
  static const double _xEdge = 0.4; // کمی حاشیه تا نقطه‌های اول و آخر بریده نشوند

  double _zoom = 1;
  double _x0 = 0; // اندیسِ ستونی که لبه‌ی چپِ نمودار است
  double _y0 = 0; // مقداری که لبه‌ی پایینِ نمودار است
  double _startZoom = 1, _focusX = 0, _focusY = 0;
  double _plotW = 1, _plotH = 1;

  int get _n => widget.rows.length;
  double get _fullX0 => -_xEdge;
  double get _fullXW => (_n > 1 ? (_n - 1).toDouble() : 0.0) + 2 * _xEdge;
  double get _fullY0 => widget.scale.min;
  double get _fullYW => widget.scale.max - widget.scale.min;
  double get _maxZoom => math.max(8.0, 2.0 * (_n - 1));

  @override
  void initState() {
    super.initState();
    _resetView();
  }

  @override
  void didUpdateWidget(covariant _ZoomableChart old) {
    super.didUpdateWidget(old);
    // اگر تعدادِ تاریخ‌ها یا بازه‌ی عددی عوض شد، به نمایشِ کامل برگرد
    if (old.rows.length != widget.rows.length ||
        old.scale.min != widget.scale.min ||
        old.scale.max != widget.scale.max) {
      _resetView();
    }
  }

  void _resetView() {
    _zoom = 1;
    _x0 = _fullX0;
    _y0 = _fullY0;
  }

  void _clampView() {
    final wx = _fullXW / _zoom, wy = _fullYW / _zoom;
    _x0 = _x0.clamp(_fullX0, _fullX0 + _fullXW - wx).toDouble();
    _y0 = _y0.clamp(_fullY0, _fullY0 + _fullYW - wy).toDouble();
  }

  Offset _toData(Offset local) {
    final wx = _fullXW / _zoom, wy = _fullYW / _zoom;
    final dx = _x0 + (local.dx - _leftAxis) / _plotW * wx;
    final dy = _y0 + (1 - (local.dy - _topPad) / _plotH) * wy;
    return Offset(dx, dy);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest;
      _plotW = math.max(1.0, size.width - _leftAxis - _rightPad);
      _plotH = math.max(1.0, size.height - _topPad - _bottomPad);
      _clampView();
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: () => setState(_resetView),
        onScaleStart: (d) {
          _startZoom = _zoom;
          final p = _toData(d.localFocalPoint);
          _focusX = p.dx;
          _focusY = p.dy;
        },
        onScaleUpdate: (d) {
          setState(() {
            _zoom = (_startZoom * d.scale).clamp(1.0, _maxZoom).toDouble();
            final wx = _fullXW / _zoom, wy = _fullYW / _zoom;
            // نقطه‌ی زیرِ انگشت‌ها ثابت می‌ماند (هم برای زوم، هم برای جابه‌جایی)
            _x0 = _focusX - (d.localFocalPoint.dx - _leftAxis) / _plotW * wx;
            _y0 = _focusY - (1 - (d.localFocalPoint.dy - _topPad) / _plotH) * wy;
            _clampView();
          });
        },
        child: CustomPaint(
          size: size,
          painter: _ZoomChartPainter(
            rows: widget.rows,
            visibility: widget.visibility,
            colorIndices: widget.colorIndices,
            x0: _x0,
            wx: _fullXW / _zoom,
            y0: _y0,
            wy: _fullYW / _zoom,
            plotL: _leftAxis,
            plotT: _topPad,
            plotW: _plotW,
            plotH: _plotH,
          ),
        ),
      );
    });
  }
}

class _ZoomChartPainter extends CustomPainter {
  final List<ChartRow> rows;
  final List<bool> visibility;
  final List<int> colorIndices;
  final double x0, wx, y0, wy;
  final double plotL, plotT, plotW, plotH;

  _ZoomChartPainter({
    required this.rows,
    required this.visibility,
    required this.colorIndices,
    required this.x0,
    required this.wx,
    required this.y0,
    required this.wy,
    required this.plotL,
    required this.plotT,
    required this.plotW,
    required this.plotH,
  });

  double _px(double i) => plotL + (i - x0) / wx * plotW;
  double _py(double v) => plotT + (1 - (v - y0) / wy) * plotH;

  @override
  void paint(Canvas canvas, Size size) {
    final plotRect = Rect.fromLTWH(plotL, plotT, plotW, plotH);

    // ---- خط‌های راهنما و عددهای محور عمودی (متناسب با زوم) ----
    final ns = _computeNiceScale(y0, y0 + wy, 6);
    final gridPaint = Paint()
      ..color = const Color(0xFFD7DFDA)
      ..strokeWidth = 1;
    final tickCount = ((ns.max - ns.min) / ns.step).round();
    for (int i = 0; i <= tickCount; i++) {
      final v = ns.min + i * ns.step;
      if (v < y0 - ns.step * 1e-6 || v > y0 + wy + ns.step * 1e-6) continue;
      final y = _py(v);
      canvas.drawLine(Offset(plotL, y), Offset(plotL + plotW, y), gridPaint);
      final tp = TextPainter(
        text: TextSpan(
          text: _formatAxisValue(v, ns.step),
          style: const TextStyle(color: Color(0xFF4A5B57), fontWeight: FontWeight.bold, fontSize: 12),
        ),
        textDirection: TextDirection.rtl,
      )..layout();
      tp.paint(canvas, Offset(plotL - tp.width - 5, y - tp.height / 2));
    }
    canvas.drawLine(Offset(plotL, plotT + plotH), Offset(plotL + plotW, plotT + plotH),
        Paint()..color = const Color(0xFF9AA8A2)..strokeWidth = 1.2);

    // ---- خط‌ها و نقطه‌ها (بریده‌شده به ناحیه‌ی نمودار) ----
    canvas.save();
    canvas.clipRect(plotRect.inflate(8));
    for (int p = 0; p < visibility.length; p++) {
      if (!visibility[p]) continue;
      final color = Color(chartColorPalette[colorIndices[p] % chartColorPalette.length]);
      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;
      final dotPaint = Paint()..color = color;
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;

      final points = <Offset>[];
      for (int r = 0; r < rows.length; r++) {
        final v = p < rows[r].values.length ? parseFaNumber(rows[r].values[p]) : null;
        if (v != null) points.add(Offset(_px(r.toDouble()), _py(v)));
      }
      for (int i = 0; i < points.length - 1; i++) {
        final a = points[i], b = points[i + 1];
        if ((a.dx < plotL - 8 && b.dx < plotL - 8) || (a.dx > plotL + plotW + 8 && b.dx > plotL + plotW + 8)) {
          continue;
        }
        canvas.drawLine(a, b, linePaint);
      }
      for (final pt in points) {
        if (pt.dx < plotL - 8 || pt.dx > plotL + plotW + 8) continue;
        canvas.drawCircle(pt, 5, dotPaint);
        canvas.drawCircle(pt, 5, borderPaint);
      }
    }
    canvas.restore();

    // ---- تاریخ‌های زیرِ محور؛ هرچه بیشتر زوم کنید، تاریخ‌های بیشتری دیده می‌شود ----
    final pxPerIndex = plotW / wx;
    final stride = math.max(1, (38 / pxPerIndex).ceil());
    final first = math.max(0, x0.ceil());
    final last = math.min(rows.length - 1, (x0 + wx).floor());
    final axisY = plotT + plotH + 8;
    for (int r = first; r <= last; r++) {
      if (r % stride != 0) continue;
      final x = _px(r.toDouble());
      if (x < plotL - 4 || x > plotL + plotW + 4) continue;
      canvas.drawLine(Offset(x, plotT + plotH), Offset(x, plotT + plotH + 4),
          Paint()..color = const Color(0xFF9AA8A2)..strokeWidth = 1);
      final tp = TextPainter(
        text: TextSpan(
          text: rows[r].date,
          style: const TextStyle(fontSize: 11, color: Color(0xFF4A5B57), fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.rtl,
      )..layout();
      canvas.save();
      canvas.translate(x, axisY);
      canvas.rotate(-0.6);
      tp.paint(canvas, Offset(-tp.width, 0));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ZoomChartPainter old) => true;
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
        text: TextSpan(text: label, style: const TextStyle(color: Color(0xFF4A5B57), fontWeight: FontWeight.bold, fontSize: 17)),
        textDirection: TextDirection.rtl,
      )..layout();
      tp.paint(canvas, Offset(leftPad - tp.width - 10, y - tp.height / 2));
    }

    for (final p in visibleIndividuals) {
      final color = Color(chartColorPalette[colorIndices[p] % chartColorPalette.length]);
      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;
      final dotPaint = Paint()..color = color;
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      final points = <Offset>[];
      for (int idx = 0; idx < rows.length; idx++) {
        final v = p < rows[idx].values.length ? parseFaNumber(rows[idx].values[p]) : null;
        if (v != null) points.add(Offset(leftPad + idx * (n > 1 ? spacing : 0), valueToY(v)));
      }
      for (int i = 0; i < points.length - 1; i++) {
        canvas.drawLine(points[i], points[i + 1], linePaint);
      }
      for (final pt in points) {
        canvas.drawCircle(pt, 7, dotPaint);
        canvas.drawCircle(pt, 7, borderPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ExportChartPainter oldDelegate) => true;
}
