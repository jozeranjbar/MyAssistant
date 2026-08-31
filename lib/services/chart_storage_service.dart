import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chart_board.dart';

/// ذخیره‌سازی محلی «نمودار ساز» با SharedPreferences؛ دقیقاً همان الگوی
/// [ReminderStorageService]. کل وضعیت (افراد، متغیرها، داده‌ها) به‌صورت یک
/// آبجکت JSON واحد ذخیره می‌شود.
class ChartStorageService {
  static const _key = 'chart_maker_v1';

  Future<ChartBoardData> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return ChartBoardData.initial();
    try {
      return ChartBoardData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return ChartBoardData.initial();
    }
  }

  Future<void> save(ChartBoardData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(data.toJson()));
  }

  /// خروجی متنی (JSON) برای پشتیبان‌گیری؛ فرمت با تورفتگی برای خوانایی بهتر.
  String exportBackupJson(ChartBoardData data) =>
      const JsonEncoder.withIndent('  ').convert(data.toJson());

  /// بررسی و تبدیل متن JSON پشتیبان به مدل؛ در صورت نامعتبر بودن ساختار، null
  /// برمی‌گرداند (بدون اینکه چیزی در برنامه تغییر کند).
  ChartBoardData? parseBackupJson(String text) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map ||
          decoded['individuals'] is! List ||
          decoded['variables'] is! List ||
          decoded['dataByVariable'] is! Map) {
        return null;
      }
      return ChartBoardData.fromJson(decoded.cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }
}
