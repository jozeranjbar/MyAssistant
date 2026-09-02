/// مدل داده‌ی «نمودار ساز»: چند نفر، چند متغیر (وزن، خواب، قند خون و ...) و
/// برای هر متغیر یک سری تاریخ/مقدار به‌ازای هر فرد.
///
/// ساختار JSON این مدل عمداً همان ساختار نسخه‌ی وبِ «نمودار ساز» (namood2.html)
/// است تا فایل پشتیبانی که از هرکدام گرفته می‌شود، در دیگری هم قابل بازیابی باشد.
library chart_board;

import '../utils/persian_numbers.dart' as persian_numbers;

/// پالت رنگ ثابت افراد؛ رنگ هر فرد بر اساس [ChartBoardData.colorIndices] تعیین
/// می‌شود، نه موقعیت فعلی‌اش در لیست؛ به این ترتیب با حذف یک نفر، رنگ بقیه عوض نمی‌شود.
const List<int> chartColorPalette = [
  0xFFD92F69,
  0xFF8B4513,
  0xFF4CAF50,
  0xFF2196F3,
  0xFFFF9800,
  0xFF9C27B0,
  0xFF795548,
  0xFF607D8B,
];

/// متغیرهای پیش‌فرض به همین ترتیب: وزن، مقدار خواب، پیاده‌روی، قند خون.
/// «وزن» همیشه اولین و پیش‌فرضِ انتخاب‌شده است.
const List<String> kDefaultChartVariables = ['وزن', 'مقدار خواب', 'پیاده‌روی', 'قند خون'];

/// برای سازگاری با کدهای قبلی: اولین و اصلی‌ترین متغیر پیش‌فرض.
const String kDefaultChartVariable = 'وزن';

/// حداکثر تعداد افرادی که می‌توان به نمودار اضافه کرد.
const int kMaxChartPeople = 5;

/// ارقام فارسی/عربی یک رشته را به معادل انگلیسی تبدیل می‌کند (برای پردازش داخلی).
/// (نام‌های toFaDigits/normalizeDigits برای سازگاری با فایل‌های موجودِ نمودار
/// ساز حفظ شده‌اند؛ پیاده‌سازیِ واقعی در utils/persian_numbers.dart است تا
/// همین منطق در همه‌ی برنامه یکسان و یک‌جا نگهداری شود.)
String normalizeDigits(String input) => persian_numbers.normalizeDigitsToAscii(input);

/// عدد را به ارقام فارسی تبدیل می‌کند.
String toFaDigits(String input) => persian_numbers.toPersianDigits(input);

/// رشته‌ی مقدار (که می‌تواند شامل متن هم باشد، مثل «۵۴ کیلوگرم») را به عدد
/// تبدیل می‌کند؛ در صورت نامعتبر بودن null برمی‌گرداند. برای رسم نمودار استفاده می‌شود.
double? parseFaNumber(String? input) {
  if (input == null) return null;
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;
  final normalized = normalizeDigits(trimmed);
  final match = RegExp(r'-?\d+(\.\d+)?').firstMatch(normalized);
  if (match == null) return null;
  return double.tryParse(match.group(0)!);
}

/// کلید عددی برای مرتب‌سازی/مقایسه‌ی تاریخ‌های شمسی به‌فرمت YYYY/MM/DD.
int dateSortKey(String date) {
  final normalized = normalizeDigits(date);
  final parts = normalized.split('/').map((p) => int.tryParse(p.trim())).toList();
  if (parts.length != 3 || parts.any((p) => p == null)) return 1 << 30;
  return parts[0]! * 10000 + parts[1]! * 100 + parts[2]!;
}

void sortChartRows(List<ChartRow> rows) {
  rows.sort((a, b) => dateSortKey(a.date).compareTo(dateSortKey(b.date)));
}

/// یک ردیف داده: یک تاریخ به‌همراه مقدار هر فرد در همان تاریخ (هم‌تراز با
/// [ChartBoardData.individuals]).
class ChartRow {
  String date;
  List<String> values;

  ChartRow({required this.date, List<String>? values}) : values = values ?? [];

  ChartRow copy() => ChartRow(date: date, values: List<String>.from(values));

  Map<String, dynamic> toJson() => {'date': date, 'values': values};

  factory ChartRow.fromJson(Map<String, dynamic> json) => ChartRow(
        date: json['date']?.toString() ?? '',
        values: (json['values'] as List? ?? []).map((e) => e?.toString() ?? '').toList(),
      );
}

/// کل وضعیت «نمودار ساز»: افراد، متغیرها و داده‌ی هر متغیر.
class ChartBoardData {
  List<String> individuals;
  List<bool> visibility;
  List<int> colorIndices;
  int nextColorIndex;
  List<String> variables;
  String? currentVariable;
  Map<String, List<ChartRow>> dataByVariable;

  ChartBoardData({
    List<String>? individuals,
    List<bool>? visibility,
    List<int>? colorIndices,
    this.nextColorIndex = 0,
    List<String>? variables,
    this.currentVariable,
    Map<String, List<ChartRow>>? dataByVariable,
  })  : individuals = individuals ?? [],
        visibility = visibility ?? [],
        colorIndices = colorIndices ?? [],
        variables = variables ?? [kDefaultChartVariable],
        dataByVariable = dataByVariable ?? {kDefaultChartVariable: []};

  /// وضعیت شروع: دو نفرِ پیش‌فرض («فرد شماره ۱» و «فرد شماره ۲») با دو
  /// تاریخ و مقدار وزنِ نمونه، و متغیرهای پیش‌فرض: وزن، مقدار خواب،
  /// پیاده‌روی، قند خون — با «وزن» به‌عنوان متغیر انتخاب‌شده.
  factory ChartBoardData.initial() {
    const defaultIndividuals = ['فرد شماره ۱', 'فرد شماره ۲'];
    final defaultWeightRows = [
      ChartRow(date: '۱۴۰۵/۰۳/۰۵', values: ['۵۲ کیلو', '۱۰۳ کیلو']),
      ChartRow(date: '۱۴۰۵/۰۶/۱۲', values: ['۶۱ کیلو', '۸۸ کیلو']),
    ];
    return ChartBoardData(
      individuals: List<String>.from(defaultIndividuals),
      visibility: List<bool>.filled(defaultIndividuals.length, true),
      colorIndices: List<int>.generate(defaultIndividuals.length, (i) => i),
      nextColorIndex: defaultIndividuals.length,
      variables: List<String>.from(kDefaultChartVariables),
      currentVariable: kDefaultChartVariables.first,
      dataByVariable: {
        for (final v in kDefaultChartVariables) v: (v == kDefaultChartVariable ? defaultWeightRows : <ChartRow>[]),
      },
    );
  }

  List<ChartRow> get currentRows =>
      currentVariable != null ? (dataByVariable[currentVariable!] ?? const []) : const [];

  int colorOf(int personIndex) =>
      chartColorPalette[colorIndices[personIndex] % chartColorPalette.length];

  /// افزودن یک نفر جدید؛ یک مقدار خالی هم به تمام ردیف‌های تمام متغیرها اضافه می‌شود.
  void addPerson(String name) {
    individuals.add(name);
    visibility.add(true);
    colorIndices.add(nextColorIndex++);
    for (final rows in dataByVariable.values) {
      for (final row in rows) {
        row.values.add('');
      }
    }
  }

  void renamePerson(int index, String name) => individuals[index] = name;

  /// حذف کامل یک فرد از همه‌ی متغیرها (ستون مربوط به او از تمام ردیف‌ها حذف می‌شود).
  void removePerson(int index) {
    individuals.removeAt(index);
    visibility.removeAt(index);
    colorIndices.removeAt(index);
    for (final rows in dataByVariable.values) {
      for (final row in rows) {
        if (index < row.values.length) row.values.removeAt(index);
      }
    }
  }

  void addVariable(String name) {
    variables.add(name);
    dataByVariable[name] = [];
    currentVariable = name;
  }

  void removeVariable(String name) {
    variables.remove(name);
    dataByVariable.remove(name);
    if (currentVariable == name) {
      currentVariable = variables.isNotEmpty ? variables.first : null;
    }
  }

  /// افزودن تاریخ جدید (با مقدار خالی برای همه) به متغیر جاری؛ در صورت تکراری
  /// بودن تاریخ false برمی‌گرداند.
  bool addDateToCurrent(String date) {
    final rows = currentVariable != null ? dataByVariable[currentVariable!] : null;
    if (rows == null) return false;
    if (rows.any((r) => r.date == date)) return false;
    rows.add(ChartRow(date: date, values: List.filled(individuals.length, '')));
    sortChartRows(rows);
    return true;
  }

  /// بازنشانی کامل: همه‌ی افراد/متغیرها حذف می‌شوند و فقط متغیرهای پیش‌فرض
  /// (وزن، مقدار خواب، پیاده‌روی، قند خون) به‌صورت خالی باقی می‌مانند.
  void clearAll() {
    individuals = [];
    visibility = [];
    colorIndices = [];
    nextColorIndex = 0;
    variables = List<String>.from(kDefaultChartVariables);
    dataByVariable = {for (final v in kDefaultChartVariables) v: <ChartRow>[]};
    currentVariable = kDefaultChartVariables.first;
  }

  Map<String, dynamic> toJson() => {
        'individuals': individuals,
        'visibility': visibility,
        'colorIndices': colorIndices,
        'nextColorIndex': nextColorIndex,
        'variables': variables,
        'currentVariable': currentVariable,
        'dataByVariable':
            dataByVariable.map((k, v) => MapEntry(k, v.map((r) => r.toJson()).toList())),
      };

  factory ChartBoardData.fromJson(Map<String, dynamic> json) {
    final individuals =
        (json['individuals'] as List? ?? []).map((e) => e.toString()).toList();

    var visibility =
        (json['visibility'] as List?)?.map((e) => e == true).toList() ?? <bool>[];
    while (visibility.length < individuals.length) {
      visibility.add(true);
    }
    if (visibility.length > individuals.length) {
      visibility = visibility.sublist(0, individuals.length);
    }

    List<int> colorIndices;
    final rawColorIndices = json['colorIndices'] as List?;
    if (rawColorIndices != null && rawColorIndices.length == individuals.length) {
      colorIndices = rawColorIndices.map((e) => (e as num).toInt()).toList();
    } else {
      colorIndices = List.generate(individuals.length, (i) => i);
    }

    final nextColorIndex = (json['nextColorIndex'] is num)
        ? (json['nextColorIndex'] as num).toInt()
        : (colorIndices.isEmpty
            ? individuals.length
            : colorIndices.reduce((a, b) => a > b ? a : b) + 1);

    var variables = (json['variables'] as List? ?? []).map((e) => e.toString()).toList();

    final rawDataByVariable = json['dataByVariable'];
    final dataByVariable = <String, List<ChartRow>>{};
    if (rawDataByVariable is Map) {
      rawDataByVariable.forEach((key, value) {
        final rows = (value as List? ?? [])
            .map((e) => ChartRow.fromJson(e as Map<String, dynamic>))
            .toList();
        sortChartRows(rows);
        dataByVariable[key.toString()] = rows;
      });
    }
    if (variables.isEmpty) variables = List<String>.from(kDefaultChartVariables);
    for (final v in variables) {
      dataByVariable.putIfAbsent(v, () => []);
    }

    final currentVariableRaw = json['currentVariable'];
    final currentVariable =
        (currentVariableRaw != null && variables.contains(currentVariableRaw))
            ? currentVariableRaw.toString()
            : variables.first;

    return ChartBoardData(
      individuals: individuals,
      visibility: visibility,
      colorIndices: colorIndices,
      nextColorIndex: nextColorIndex,
      variables: variables,
      currentVariable: currentVariable,
      dataByVariable: dataByVariable,
    );
  }
}
