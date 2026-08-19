import 'package:flutter/material.dart';
import 'services/notification_service.dart';
import 'services/reminder_storage_service.dart';
import 'services/background_service.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationService().init();
  await BackgroundService.initialize();

  // زمان‌بندی مجدد یادآوری‌های ذخیره‌شده هنگام باز شدن برنامه
  // (پوشش‌دهنده حالتی که برنامه بعد از ری‌استارت گوشی برای اولین بار باز می‌شود؛
  // برای زمان‌بندی خودکار بلافاصله بعد از بوت بدون باز کردن برنامه، از
  // BroadcastReceiver اندروید برای BOOT_COMPLETED در AndroidManifest استفاده شده
  // که وظیفه boot_reschedule_task را در background_service.dart صدا می‌زند).
  final reminders = await ReminderStorageService().loadReminders();
  await NotificationService().rescheduleAll(reminders);

  runApp(const MyAssistantApp());
}

class MyAssistantApp extends StatelessWidget {
  const MyAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyAssistant',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [Locale('fa', 'IR'), Locale('en', 'US')],
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
        fontFamily: 'Vazirmatn', // اختیاری: فونت فارسی را در pubspec اضافه کنید
      ),
      builder: (context, child) {
        // اجرای کل برنامه به‌صورت راست‌به‌چپ (فارسی) و مدیریت ابعاد/چرخش صفحه
        return Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: MediaQuery.of(context).textScaler.clamp(
                    minScaleFactor: 0.9,
                    maxScaleFactor: 1.2,
                  ),
            ),
            child: child!,
          ),
        );
      },
      home: const HomeScreen(),
    );
  }
}
