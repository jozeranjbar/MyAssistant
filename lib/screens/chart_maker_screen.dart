import 'package:flutter/material.dart';

/// صفحه‌ی «نمودار ساز» - در حال حاضر ساختار اولیه (اسکلت) صفحه است
/// و بر اساس نیاز شما تکمیل خواهد شد.
class ChartMakerScreen extends StatelessWidget {
  const ChartMakerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('نمودار ساز')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'این بخش به‌زودی تکمیل می‌شود.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
