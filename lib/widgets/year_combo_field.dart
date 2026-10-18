import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/persian_numbers.dart';

/// فیلد «سال» که هم کشویی است و هم می‌شود سال را با کیبورد تایپ کرد.
///
/// - با لمس فلش سمتِ چپ، فهرستی از سال‌های اطراف سالِ فعلی باز می‌شود.
/// - با لمس خودِ فیلد می‌شود هر سالی را (با ارقام فارسی یا انگلیسی) تایپ کرد.
/// - فقط وقتی عددِ تایپ‌شده معتبر باشد ([minYear] تا [maxYear]) به
///   [onChanged] اطلاع داده می‌شود؛ اگر کاربر فیلد را نامعتبر رها کند، به
///   آخرین سالِ معتبر برمی‌گردد.
class YearComboField extends StatefulWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final InputDecoration decoration;
  final TextStyle style;
  final int minYear;
  final int maxYear;

  /// تعداد سال‌های قبل/بعد از سالِ فعلی در فهرستِ کشویی.
  final int before;
  final int after;

  const YearComboField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.decoration,
    required this.style,
    this.minYear = 1,
    this.maxYear = 3000,
    this.before = 15,
    this.after = 14,
  });

  @override
  State<YearComboField> createState() => _YearComboFieldState();
}

class _YearComboFieldState extends State<YearComboField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: toPersianDigits(widget.value.toString()));
    _focusNode = FocusNode()..addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant YearComboField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // اگر مقدار از بیرون (مثلاً از فهرست کشویی) عوض شد، متن را هماهنگ کن.
    if (_parsed() != widget.value && !_focusNode.hasFocus) {
      _syncText();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  int? _parsed() => int.tryParse(normalizeDigitsToAscii(_controller.text.trim()));

  void _syncText() {
    final text = toPersianDigits(widget.value.toString());
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      // با ورود به فیلد، کلِ عدد انتخاب شود تا تایپِ سالِ جدید راحت باشد.
      _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
    } else {
      // اگر متن نامعتبر یا ناقص رها شد، به آخرین سالِ معتبر برگردد.
      _syncText();
    }
  }

  void _onTextChanged(String text) {
    final y = _parsed();
    if (y != null && y >= widget.minYear && y <= widget.maxYear && y != widget.value) {
      widget.onChanged(y);
    }
  }

  void _pick(int year) {
    FocusScope.of(context).unfocus();
    widget.onChanged(year);
    final t = toPersianDigits(year.toString());
    _controller.value = TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
  }

  @override
  Widget build(BuildContext context) {
    final years = <int>[
      for (var y = widget.value - widget.before; y <= widget.value + widget.after; y++)
        if (y >= widget.minYear && y <= widget.maxYear) y,
    ];

    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: 4,
      style: widget.style,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9۰-۹٠-٩]')),
      ],
      onChanged: _onTextChanged,
      onEditingComplete: () => FocusScope.of(context).unfocus(),
      onTapOutside: (_) => _focusNode.unfocus(),
      decoration: widget.decoration.copyWith(
        counterText: '',
        contentPadding: const EdgeInsets.only(left: 0, right: 8, top: 18, bottom: 18),
        prefixIcon: PopupMenuButton<int>(
          tooltip: 'انتخاب سال از فهرست',
          padding: EdgeInsets.zero,
          icon: Icon(Icons.arrow_drop_down, color: widget.style.color),
          constraints: const BoxConstraints(maxHeight: 320, minWidth: 90),
          onSelected: _pick,
          itemBuilder: (_) => [
            for (final y in years)
              PopupMenuItem<int>(
                value: y,
                height: 40,
                child: Center(
                  child: Text(
                    toPersianDigits(y.toString()),
                    style: TextStyle(
                      fontWeight: y == widget.value ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
          ],
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      ),
    );
  }
}
