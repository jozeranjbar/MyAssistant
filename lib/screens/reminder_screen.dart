import 'dart:async';
import 'package:flutter/material.dart';
import '../models/reminder.dart';
import '../services/reminder_storage_service.dart';
import '../services/notification_service.dart';
import '../utils/persian_numbers.dart';
import 'wake_alarm_screen.dart';

/// برای نمایش: ساعت‌ها از ۰۰ تا ۲۳ هستند؛ مثلاً نیم‌ساعت بعد از نیمه‌شب «۰۰:۳۰».
String _displayHourMinute(TimeOfDay t) {
  return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

/// انتخاب‌گرِ بزرگِ ساعتِ یادآوری: دو فیلد کشویی با فونتِ درشت — «ساعت»
/// (۱ تا ۲۴) و «دقیقه» (۰۰ تا ۵۹). برخلاف picker پیش‌فرضِ فلاتر که از «۰»
/// شروع می‌شود، اینجا شمارشِ ساعت از «۱» تا «۲۴» است و «۲۴» معادلِ نیمه‌شب
/// (ساعتِ صفرِ داخلی) است.
Future<TimeOfDay?> showBigHourTimePicker(BuildContext context, {required TimeOfDay initial}) {
  int selectedHour = initial.hour;
  int selectedMinute = initial.minute;

  InputDecoration pickerDecoration() => InputDecoration(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      );

  return showDialog<TimeOfDay>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(builder: (context, setDialogState) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFE1D3FF), Color(0xFFFFE0EE), Color(0xFFFFF3D6)],
                ),
                boxShadow: [
                  BoxShadow(color: Colors.deepPurple.withOpacity(0.25), blurRadius: 24, offset: const Offset(0, 10)),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'انتخاب ساعت یادآوری',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.deepPurple),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              const Text('ساعت (۱ تا ۲۴)',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black54)),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<int>(
                                isExpanded: true,
                                decoration: pickerDecoration(),
                                style: const TextStyle(
                                    fontSize: 30, fontWeight: FontWeight.bold, color: Colors.deepPurple, height: 1.4),
                                value: selectedHour,
                                items: List.generate(24, (i) => i)
                                    .map((h) => DropdownMenuItem(
                                        value: h, child: Text(toPersianDigits(h.toString().padLeft(2, '0')))))
                                    .toList(),
                                onChanged: (v) => setDialogState(() => selectedHour = v!),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            children: [
                              const Text('دقیقه',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black54)),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<int>(
                                isExpanded: true,
                                decoration: pickerDecoration(),
                                style: const TextStyle(
                                    fontSize: 30, fontWeight: FontWeight.bold, color: Colors.pink, height: 1.4),
                                value: selectedMinute,
                                items: List.generate(60, (i) => i)
                                    .map((m) => DropdownMenuItem(
                                        value: m, child: Text(toPersianDigits(m.toString().padLeft(2, '0')))))
                                    .toList(),
                                onChanged: (v) => setDialogState(() => selectedMinute = v!),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('انصراف', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(dialogContext, TimeOfDay(hour: selectedHour, minute: selectedMinute));
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                            child: const Text('تأیید', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      });
    },
  );
}

class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key});

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> with SingleTickerProviderStateMixin {
  final _storage = ReminderStorageService();
  final _notifications = NotificationService();
  List<Reminder> _reminders = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final reminders = await _storage.loadReminders();
    if (!mounted) return;
    setState(() => _reminders = reminders);
  }

  List<Reminder> get _medReminders =>
      _reminders.where((r) => r.category == ReminderCategory.medication).toList()
        ..sort((a, b) => a.timeLabel.compareTo(b.timeLabel));

  List<Reminder> get _dailyReminders =>
      _reminders.where((r) => r.category == ReminderCategory.daily).toList()
        ..sort((a, b) => a.timeLabel.compareTo(b.timeLabel));

  Future<void> _toggleActive(Reminder r, bool value) async {
    r.isActive = value;
    if (value) r.lastFiredAt = DateTime.now();
    await _storage.updateReminder(r);
    await _load();
    if (value) {
      try {
        await _notifications.scheduleReminder(r);
      } catch (e) {
        if (mounted) _showSnack('خطا در فعال‌سازی یادآوری: $e');
      }
    } else {
      unawaited(_notifications.cancelReminder(r.id));
    }
  }

  Future<void> _quickDelete(Reminder r) async {
    final confirmed = await _showConfirmDialog('آیا از حذف مطمئنید؟');
    if (confirmed != true) return;
    await _storage.removeReminder(r.id);
    await _notifications.cancelReminder(r.id);
    await _load();
  }

  Future<bool?> _showConfirmDialog(String message) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(message, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('انصراف')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('تأیید'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openAddOrEdit(ReminderCategory category, {Reminder? existing}) async {
    // پنجره‌ی کوچکِ افزودن/ویرایش بالاترین نقطه‌ی صفحه قرار می‌گیرد (نه پایین
    // یا وسط). فقط با «ذخیره» یا «انصراف» بسته می‌شود؛ لمس بیرون از پنجره آن
    // را نمی‌بندد.
    final saved = await showDialog<Reminder>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ReminderEditSheet(category: category, existing: existing),
    );
    if (saved == null) return;

    if (existing == null) {
      await _storage.addReminder(saved);
    } else {
      await _storage.updateReminder(saved);
    }
    // لیست را همین الان به‌روزرسانی کن؛ زمان‌بندی اعلان ممکن است روی برخی
    // گوشی‌ها (به‌خصوص بار اول) چند ثانیه طول بکشد و نباید صفحه را معطل کند.
    await _load();
    if (saved.isActive) {
      try {
        // اعلان‌های قبلیِ این یادآوری (مثلاً از برنامه‌ی چندروزه‌ی قبلی) پاک
        // شوند تا اعلانِ تکراریِ قدیمی باقی نماند.
        await _notifications.cancelReminder(saved.id);
        await _notifications.scheduleReminder(saved);
      } catch (e) {
        if (mounted) _showSnack('خطا در زمان‌بندی یادآوری: $e');
      }
    } else {
      unawaited(_notifications.cancelReminder(saved.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    const medColor = Color(0xFF1D4ED8);
    const dailyColor = Color(0xFF20C997);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '🔔 تنظیمات اعلان‌ها',
          style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF1B5E20),
          labelColor: const Color(0xFF1B5E20),
          unselectedLabelColor: const Color(0xFF1B5E20).withOpacity(0.55),
          tabs: const [
            Tab(text: '💊 داروها'),
            Tab(text: '⏰ زنگ بیداری'),
            Tab(text: '📝 یادآوری‌های روزمره'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ReminderList(
            reminders: _medReminders,
            color: medColor,
            emptyEmoji: '💊',
            emptyText: 'هنوز دارویی ثبت نشده',
            addLabel: '+ افزودن دارو',
            onAdd: () => _openAddOrEdit(ReminderCategory.medication),
            onEdit: (r) => _openAddOrEdit(ReminderCategory.medication, existing: r),
            onToggle: _toggleActive,
            onDelete: _quickDelete,
          ),
          const WakeAlarmScreen(),
          _ReminderList(
            reminders: _dailyReminders,
            color: dailyColor,
            emptyEmoji: '📝',
            emptyText: 'هنوز یادآوری روزمره‌ای ثبت نشده',
            addLabel: '+ افزودن یادآوری روزمره',
            onAdd: () => _openAddOrEdit(ReminderCategory.daily),
            onEdit: (r) => _openAddOrEdit(ReminderCategory.daily, existing: r),
            onToggle: _toggleActive,
            onDelete: _quickDelete,
          ),
        ],
      ),
    );
  }
}

class _ReminderList extends StatelessWidget {
  final List<Reminder> reminders;
  final Color color;
  final String emptyEmoji;
  final String emptyText;
  final String addLabel;
  final VoidCallback onAdd;
  final void Function(Reminder) onEdit;
  final void Function(Reminder, bool) onToggle;
  final void Function(Reminder) onDelete;

  const _ReminderList({
    required this.reminders,
    required this.color,
    required this.emptyEmoji,
    required this.emptyText,
    required this.addLabel,
    required this.onAdd,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
      children: [
        if (reminders.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 50),
            child: Column(
              children: [
                Text(emptyEmoji, style: const TextStyle(fontSize: 40)),
                const SizedBox(height: 10),
                Text(emptyText, style: const TextStyle(color: Colors.grey, fontSize: 14)),
              ],
            ),
          )
        else
          ...reminders.map((r) => _ReminderCard(
                reminder: r,
                color: color,
                onTap: () => onEdit(r),
                onToggle: (v) => onToggle(r, v),
                onDelete: () => onDelete(r),
              )),
        const SizedBox(height: 6),
        Material(
          color: color,
          borderRadius: BorderRadius.circular(18),
          elevation: 4,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onAdd,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                addLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReminderCard extends StatelessWidget {
  final Reminder reminder;
  final Color color;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  const _ReminderCard({
    required this.reminder,
    required this.color,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = reminder.category == ReminderCategory.medication ? reminder.dose : reminder.note;
    return Opacity(
      opacity: reminder.isActive ? 1 : 0.5,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(18),
          border: Border(right: BorderSide(color: color, width: 5)),
          boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 62,
                  child: Text(
                    toPersianDigits(reminder.cycleTodaySlot() != null
                        ? Reminder.formatMinutesOfDay(
                            reminder.cycleTodaySlot()!.hour * 60 + reminder.cycleTodaySlot()!.minute)
                        : reminder.timeLabel),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: onTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(reminder.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          if (subtitle.isNotEmpty)
                            Text(subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(_repeatLabelFa(reminder), style: TextStyle(fontSize: 11, color: color)),
                          ),
                          if (reminder.repeatType == RepeatType.cycle && reminder.cycleMinutes.isNotEmpty)
                            Text(
                              toPersianDigits(reminder.cycleSummary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: color.withOpacity(0.8)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Switch(value: reminder.isActive, onChanged: onToggle, activeColor: color),
              ],
            ),
            const Divider(height: 1),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: onTap,
                  icon: Icon(Icons.edit_outlined, size: 16, color: color),
                  label: Text('ویرایش', style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.bold)),
                ),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                  label: const Text('حذف این یادآوری', style: TextStyle(color: Colors.red, fontSize: 12.5, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _repeatLabelFa(Reminder r) {
    final label = r.repeatLabel;
    // اعداد داخل برچسب (برای «هر چند روز/ساعت یک‌بار») هم فارسی نمایش داده شوند
    return toPersianDigits(label);
  }
}

/// ---------------- فرم افزودن/ویرایش (Bottom Sheet) ----------------

class _ReminderEditSheet extends StatefulWidget {
  final ReminderCategory category;
  final Reminder? existing;
  const _ReminderEditSheet({required this.category, this.existing});

  @override
  State<_ReminderEditSheet> createState() => _ReminderEditSheetState();
}

class _ReminderEditSheetState extends State<_ReminderEditSheet> {
  final _notifications = NotificationService();
  late final TextEditingController _nameController;
  late final TextEditingController _doseOrNoteController;
  late final TextEditingController _intervalController;
  late TimeOfDay _time;
  late RepeatType _repeatType;
  late bool _soundEnabled;
  late bool _vibrationEnabled;

  // برنامه‌ی چندروزه (RepeatType.cycle)
  late final TextEditingController _cycleDaysController;
  late List<int> _cycleMinutes; // ساعتِ هر روز، به‌صورت دقیقه از نیمه‌شب
  late int _cycleTodayDay; // امروز روزِ چندمِ برنامه است (از ۱)
  static const int _minCycleDays = 2;
  static const int _maxCycleDays = 14;

  bool get _isMed => widget.category == ReminderCategory.medication;
  Color get _color => _isMed ? const Color(0xFF1D4ED8) : const Color(0xFF20C997);

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameController = TextEditingController(text: e?.title ?? '');
    _doseOrNoteController = TextEditingController(text: _isMed ? (e?.dose ?? '') : (e?.note ?? ''));
    _intervalController = TextEditingController(text: e?.repeatInterval?.toString() ?? '');
    _time = TimeOfDay(hour: e?.hour ?? 16, minute: e?.minute ?? 0);
    _repeatType = e?.repeatType ?? RepeatType.daily;
    _soundEnabled = e?.soundEnabled ?? true;
    _vibrationEnabled = e?.vibrationEnabled ?? true;

    if (e != null && e.repeatType == RepeatType.cycle && e.cycleMinutes.isNotEmpty) {
      _cycleMinutes = List<int>.from(e.cycleMinutes);
      _cycleTodayDay = e.cycleDayNumberFor(DateTime.now());
    } else {
      _cycleMinutes = List<int>.filled(4, _time.hour * 60 + _time.minute);
      _cycleTodayDay = 1;
    }
    _cycleDaysController = TextEditingController(text: _cycleMinutes.length.toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _doseOrNoteController.dispose();
    _intervalController.dispose();
    _cycleDaysController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showBigHourTimePicker(context, initial: _time);
    if (picked != null) setState(() => _time = picked);
  }

  void _onCycleDaysChanged(String text) {
    final n = int.tryParse(normalizeDigitsToAscii(text.trim()));
    if (n == null || n < _minCycleDays || n > _maxCycleDays) return;
    setState(() {
      final fill = _cycleMinutes.isNotEmpty ? _cycleMinutes.last : _time.hour * 60 + _time.minute;
      if (n > _cycleMinutes.length) {
        _cycleMinutes = [..._cycleMinutes, ...List<int>.filled(n - _cycleMinutes.length, fill)];
      } else if (n < _cycleMinutes.length) {
        _cycleMinutes = _cycleMinutes.sublist(0, n);
      }
      if (_cycleTodayDay > n) _cycleTodayDay = n;
    });
  }

  Future<void> _pickCycleTime(int index) async {
    final m = _cycleMinutes[index];
    final picked = await showBigHourTimePicker(context, initial: TimeOfDay(hour: m ~/ 60, minute: m % 60));
    if (picked != null) setState(() => _cycleMinutes[index] = picked.hour * 60 + picked.minute);
  }

  Widget _buildCycleSection() {
    const accent = Color(0xFFF06595);
    final n = _cycleMinutes.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel(text: 'تعداد روزهای برنامه (بعد از روز آخر، دوباره از روز اول شروع می‌شود)', color: accent),
        _StyledTextField(
          controller: _cycleDaysController,
          hint: 'مثلاً ۴',
          fillColor: accent,
          keyboardType: TextInputType.number,
          onChanged: _onCycleDaysChanged,
        ),
        const SizedBox(height: 14),
        _FieldLabel(text: 'ساعت یادآوری در هر روز', color: const Color(0xFF9775FA)),
        for (var i = 0; i < n; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: const Color(0xFF9775FA).withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _pickCycleTime(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Text(toPersianDigits('روز ${i + 1}'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const Spacer(),
                      const Icon(Icons.access_time, color: Color(0xFF9775FA), size: 24),
                      const SizedBox(width: 8),
                      Text(
                        toPersianDigits(_displayHourMinute(
                            TimeOfDay(hour: _cycleMinutes[i] ~/ 60, minute: _cycleMinutes[i] % 60))),
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF9775FA)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 6),
        _FieldLabel(text: 'امروز روزِ چندمِ برنامه است؟', color: const Color(0xFF15AABF)),
        DropdownButtonFormField<int>(
          value: _cycleTodayDay.clamp(1, n),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF15AABF).withOpacity(0.12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          ),
          items: [
            for (var d = 1; d <= n; d++)
              DropdownMenuItem(value: d, child: Text(toPersianDigits('روز $d'))),
          ],
          onChanged: (v) => setState(() => _cycleTodayDay = v ?? 1),
        ),
      ],
    );
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnack('لطفاً عنوان را وارد کنید');
      return;
    }
    final isCycle = _repeatType == RepeatType.cycle;
    if (isCycle && (_cycleMinutes.length < _minCycleDays || _cycleMinutes.length > _maxCycleDays)) {
      _showSnack('تعداد روزهای برنامه باید بین ${toPersianDigits(_minCycleDays.toString())} تا ${toPersianDigits(_maxCycleDays.toString())} باشد');
      return;
    }
    final now = DateTime.now();
    final needsInterval = _repeatType == RepeatType.everyXDays || _repeatType == RepeatType.everyXHours;
    final interval = int.tryParse(_intervalController.text.trim());
    if (needsInterval && (interval == null || interval <= 0)) {
      _showSnack('لطفاً عدد تکرار معتبر (بزرگ‌تر از صفر) وارد کنید');
      return;
    }

    final existing = widget.existing;
    final result = Reminder(
      id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.remainder(2000000000),
      category: widget.category,
      title: name,
      dose: _isMed ? _doseOrNoteController.text.trim() : (existing?.dose ?? ''),
      note: !_isMed ? _doseOrNoteController.text.trim() : (existing?.note ?? ''),
      hour: isCycle ? _cycleMinutes.first ~/ 60 : _time.hour,
      minute: isCycle ? _cycleMinutes.first % 60 : _time.minute,
      repeatType: _repeatType,
      repeatInterval: needsInterval ? interval : null,
      cycleMinutes: isCycle ? List<int>.from(_cycleMinutes) : <int>[],
      cycleStart: isCycle ? DateTime(now.year, now.month, now.day - (_cycleTodayDay - 1)) : null,
      isActive: existing?.isActive ?? true,
      createdAt: existing?.createdAt,
      lastFiredAt: existing?.lastFiredAt,
      soundEnabled: _soundEnabled,
      vibrationEnabled: _vibrationEnabled,
    );

    Navigator.of(context).pop(result);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final needsInterval = _repeatType == RepeatType.everyXDays || _repeatType == RepeatType.everyXHours;
    final isCycle = _repeatType == RepeatType.cycle;

    return PopScope(
      // دکمه‌ی برگشتِ گوشی هم پنجره را نمی‌بندد؛ فقط «ذخیره»/«انصراف».
      canPop: false,
      child: Align(
      // پنجره بالای صفحه می‌نشیند و تا جای ممکن از پایین فاصله دارد.
      alignment: Alignment.topCenter,
      child: Padding(
      // وقتی کیبورد باز است، پایینِ پنجره بالای کیبورد می‌ماند.
      padding: EdgeInsets.fromLTRB(10, 8, 10, MediaQuery.of(context).viewInsets.bottom + 8),
      child: ConstrainedBox(
        // اگر محتوا از ارتفاعِ در دسترس بیشتر شد، داخلِ پنجره اسکرول می‌شود
        // (چون از قبل داخل SingleChildScrollView است).
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).viewInsets.bottom - 80,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFE3F9EA),
            borderRadius: BorderRadius.circular(22),
          ),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: SingleChildScrollView(
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              Text(
                widget.existing == null
                    ? (_isMed ? 'افزودن یادآوری دارو' : 'افزودن یادآوری روزمره')
                    : 'ویرایش یادآوری',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              _FieldLabel(text: _isMed ? 'نام دارو' : 'عنوان یادآوری', color: const Color(0xFF4F6EF7)),
              _StyledTextField(
                controller: _nameController,
                hint: _isMed ? 'مثلاً کلسیم ۱۰۰۰' : 'مثلاً آب دادن به گل‌ها',
                fillColor: const Color(0xFF4CAF50),
              ),
              const SizedBox(height: 14),

              _FieldLabel(
                text: _isMed ? 'توضیح' : 'یادداشت',
                color: _isMed ? const Color(0xFFFF922B) : const Color(0xFF15AABF),
              ),
              _StyledTextField(
                controller: _doseOrNoteController,
                hint: _isMed ? 'مثلاً قبل از غذا' : 'یادداشت تکمیلی...',
                fillColor: _isMed ? const Color(0xFFFF922B) : const Color(0xFF15AABF),
                maxLines: _isMed ? 1 : 3,
              ),
              const SizedBox(height: 14),

              _FieldLabel(text: 'تکرار', color: const Color(0xFF20C997)),
              _RepeatTypeSelector(
                value: _repeatType,
                onChanged: (v) => setState(() => _repeatType = v),
              ),
              if (needsInterval) ...[
                const SizedBox(height: 14),
                _FieldLabel(
                  text: _repeatType == RepeatType.everyXDays
                      ? 'هر چند روز یک‌بار یادآوری شود'
                      : 'هر چند ساعت یک‌بار یادآوری شود',
                  color: const Color(0xFFF06595),
                ),
                _StyledTextField(
                  controller: _intervalController,
                  hint: _repeatType == RepeatType.everyXDays ? 'مثلاً ۴' : 'مثلاً ۸',
                  fillColor: const Color(0xFFF06595),
                  keyboardType: TextInputType.number,
                ),
              ],
              const SizedBox(height: 14),
              if (isCycle)
                _buildCycleSection()
              else ...[
              _FieldLabel(text: 'ساعت یادآوری', color: const Color(0xFF9775FA)),
              Material(
                color: const Color(0xFF9775FA).withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _pickTime,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.access_time, color: Color(0xFF9775FA), size: 34),
                        const SizedBox(width: 10),
                        Text(
                          toPersianDigits(_displayHourMinute(_time)),
                          style: const TextStyle(
                              fontSize: 34, fontWeight: FontWeight.w800, color: Color(0xFF9775FA)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              ],
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _FieldLabel(text: 'نحوه‌ی اعلان', color: _color),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          await _notifications.sendTestNotification();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                duration: Duration(seconds: 6),
                                content: Text(
                                  'اعلان آزمایشی تا ۵ ثانیه دیگر می‌آید. اگه صدا/لرزش نداشت، '
                                  'اول حجم صدای اعلان‌ها و حالت مزاحم نشوید رو در تنظیمات گوشی چک کن.',
                                ),
                              ),
                            );
                          }
                        } catch (_) {
                          // خطای احتمالی نادیده گرفته می‌شود؛ پیامی به کاربر نشان داده نمی‌شود.
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _color,
                        side: BorderSide(color: _color),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.volume_up, size: 16),
                      label: const Text('تست', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: _color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  children: [
                    SwitchListTile(
                      value: _soundEnabled,
                      onChanged: (v) => setState(() => _soundEnabled = v),
                      activeColor: _color,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('پخش صدا', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      secondary: Icon(Icons.volume_up, color: _color),
                    ),
                    Divider(height: 1, color: _color.withOpacity(0.15)),
                    SwitchListTile(
                      value: _vibrationEnabled,
                      onChanged: (v) => setState(() => _vibrationEnabled = v),
                      activeColor: _color,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('لرزش (ویبره)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      secondary: Icon(Icons.vibration, color: _color),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              Row(
                children: [
                  if (widget.existing != null) ...[
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 14)),
                        onPressed: () => Navigator.of(context).pop(null),
                        child: const Text('انصراف از ویرایش'),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ] else ...[
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                        onPressed: () => Navigator.of(context).pop(null),
                        child: const Text('انصراف'),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _save,
                      child: const Text('ذخیره', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
      ),
      ),
    ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _FieldLabel({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
    );
  }
}

class _StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final Color fillColor;
  final int maxLines;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  const _StyledTextField({
    required this.controller,
    required this.hint,
    required this.fillColor,
    this.maxLines = 1,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      textAlign: TextAlign.right,
      // متنی که کاربر می‌نویسد سیاه و پررنگ است؛ راهنما (hint) خاکستریِ کمرنگ.
      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.normal),
        filled: true,
        fillColor: fillColor.withOpacity(0.12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      ),
    );
  }
}

class _RepeatTypeSelector extends StatelessWidget {
  final RepeatType value;
  final ValueChanged<RepeatType> onChanged;
  const _RepeatTypeSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<RepeatType>(
      value: value,
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFF20C997).withOpacity(0.12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      ),
      items: RepeatType.values
          .map((t) => DropdownMenuItem(value: t, child: Text(t.optionLabel)))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
