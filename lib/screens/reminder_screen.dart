import 'dart:async';
import 'package:flutter/material.dart';
import '../models/reminder.dart';
import '../services/reminder_storage_service.dart';
import '../services/notification_service.dart';

String _toPersianDigits(String input) {
  const western = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  var result = input;
  for (var i = 0; i < western.length; i++) {
    result = result.replaceAll(western[i], persian[i]);
  }
  return result;
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
    _tabController = TabController(length: 2, vsync: this);
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
      unawaited(_notifications.scheduleReminder(r));
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

  Future<void> _openAddOrEdit(ReminderCategory category, {Reminder? existing}) async {
    final saved = await showModalBottomSheet<Reminder>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
      unawaited(_notifications.scheduleReminder(saved));
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
          '🔔 تنظیمات یادآوری',
          style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF1B5E20),
          labelColor: const Color(0xFF1B5E20),
          unselectedLabelColor: const Color(0xFF1B5E20).withOpacity(0.55),
          tabs: const [
            Tab(text: '💊 یادآوری داروها'),
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
            emptyText: 'هنوز یادآوری دارویی ثبت نشده',
            addLabel: '+ افزودن یادآوری دارو',
            onAdd: () => _openAddOrEdit(ReminderCategory.medication),
            onEdit: (r) => _openAddOrEdit(ReminderCategory.medication, existing: r),
            onToggle: _toggleActive,
            onDelete: _quickDelete,
          ),
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
                    _toPersianDigits(reminder.timeLabel),
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
    return _toPersianDigits(label);
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
  late final TextEditingController _nameController;
  late final TextEditingController _doseOrNoteController;
  late final TextEditingController _intervalController;
  late TimeOfDay _time;
  late RepeatType _repeatType;

  bool get _isMed => widget.category == ReminderCategory.medication;
  Color get _color => _isMed ? const Color(0xFF1D4ED8) : const Color(0xFF20C997);

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameController = TextEditingController(text: e?.title ?? '');
    _doseOrNoteController = TextEditingController(text: _isMed ? (e?.dose ?? '') : (e?.note ?? ''));
    _intervalController = TextEditingController(text: e?.repeatInterval?.toString() ?? '');
    _time = TimeOfDay(hour: e?.hour ?? 16, minute: e?.minute ?? 30);
    _repeatType = e?.repeatType ?? RepeatType.daily;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _doseOrNoteController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnack('لطفاً عنوان را وارد کنید');
      return;
    }
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
      hour: _time.hour,
      minute: _time.minute,
      repeatType: _repeatType,
      repeatInterval: needsInterval ? interval : null,
      isActive: existing?.isActive ?? true,
      createdAt: existing?.createdAt,
      lastFiredAt: existing?.lastFiredAt,
      lastFiredDate: existing?.lastFiredDate,
    );

    Navigator.of(context).pop(result);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final needsInterval = _repeatType == RepeatType.everyXDays || _repeatType == RepeatType.everyXHours;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFE3F9EA),
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
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

              _FieldLabel(text: 'ساعت یادآوری', color: const Color(0xFF9775FA)),
              Material(
                color: const Color(0xFF9775FA).withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _pickTime,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.access_time, color: Color(0xFF9775FA)),
                        const SizedBox(width: 8),
                        Text(
                          _toPersianDigits(
                              '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}'),
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF9775FA)),
                        ),
                      ],
                    ),
                  ),
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

  const _StyledTextField({
    required this.controller,
    required this.hint,
    required this.fillColor,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textAlign: TextAlign.right,
      decoration: InputDecoration(
        hintText: hint,
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
