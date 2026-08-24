import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/notification_service.dart';
import 'services/reminder_storage_service.dart';
import 'services/background_service.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // در صورت بروز خطای غیرمنتظره در ساخت هر ویجت، به‌جای صفحه خاکستری خالی،
  // متن دقیق خطا نمایش داده می‌شود تا رفع اشکال آسان‌تر باشد.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Text(
            'خطا: ${details.exceptionAsString()}',
            style: const TextStyle(color: Colors.red, fontSize: 13),
            textDirection: TextDirection.ltr,
          ),
        ),
      ),
    );
  };

  // مقداردهی اولیه اعلان‌ها و کارهای پس‌زمینه در try/catch قرار گرفته تا در
  // صورت بروز خطا (مثلاً عدم پشتیبانی یک قابلیت روی برخی گوشی‌ها)، کل برنامه
  // از کار نیفتد و فقط همان بخش نادیده گرفته شود.
  try {
    await NotificationService().init();
  } catch (e) {
    debugPrint('خطا در مقداردهی اعلان‌ها: $e');
  }

  try {
    await BackgroundService.initialize();
  } catch (e) {
    debugPrint('خطا در مقداردهی سرویس پس‌زمینه: $e');
  }

  try {
    // زمان‌بندی مجدد یادآوری‌های ذخیره‌شده هنگام باز شدن برنامه
    final reminders = await ReminderStorageService().loadReminders();
    await NotificationService().rescheduleAll(reminders);
  } catch (e) {
    debugPrint('خطا در بازتنظیم یادآوری‌ها: $e');
  }

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
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.lightBlue,
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
