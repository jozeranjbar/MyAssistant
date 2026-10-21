import 'package:flutter/material.dart';

import '../utils/persian_numbers.dart';

/// یک عددِ دما با علامتِ درجه‌ی بالانویس، همیشه سمتِ راستِ همان عدد (حتی داخل
/// متنِ راست‌به‌چپ، چون هر واحد یک ویجتِ چپ‌به‌راستِ جدا است).
class _DegreeNumber extends StatelessWidget {
  final int value;
  final TextStyle style;
  const _DegreeNumber({required this.value, required this.style});

  @override
  Widget build(BuildContext context) {
    final size = style.fontSize ?? 14;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(toPersianDigits(value.toString()), style: style),
          Transform.translate(
            offset: Offset(0, -size * 0.35),
            child: Text('°', style: style.copyWith(fontSize: size * 0.8)),
          ),
        ],
      ),
    );
  }
}

/// «حداقل تا حداکثر» دما، مثلاً «۲۳° تا ۳۶°» یا (با [parentheses]) «(۲۳° تا ۳۶°)».
/// علامتِ درجه بالای هر دو عدد و سمتِ راستِ آن‌ها قرار می‌گیرد.
class TempRange extends StatelessWidget {
  final double min;
  final double max;
  final TextStyle style;
  final bool parentheses;

  const TempRange({
    super.key,
    required this.min,
    required this.max,
    required this.style,
    this.parentheses = false,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          if (parentheses) Text('(', style: style),
          _DegreeNumber(value: min.round(), style: style),
          Text(' تا ', style: style),
          _DegreeNumber(value: max.round(), style: style),
          if (parentheses) Text(')', style: style),
        ],
      ),
    );
  }
}
