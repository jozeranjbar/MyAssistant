# قوانین Proguard در صورت نیاز به سفارشی‌سازی بیشتر می‌توانند اینجا اضافه شوند.
-keep class com.dexterous.** { *; }

# چون minifyEnabled فعاله، بدون این خط‌ها ممکنه R8 کلاس‌های ویجت هوم‌اسکرین رو
# توی بیلد ریلیز حذف/تغییرنام بده و ویجت روی APK نهایی کار نکنه.
-keep class com.myassistant.app.WeatherClockWidgetProvider { *; }
-keep class com.myassistant.app.MainActivity { *; }
-keep class es.antonborri.home_widget.** { *; }
