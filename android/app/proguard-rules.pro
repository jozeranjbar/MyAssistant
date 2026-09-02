# قوانین Proguard در صورت نیاز به سفارشی‌سازی بیشتر می‌توانند اینجا اضافه شوند.
-keep class com.dexterous.** { *; }

# پلاگین flutter_local_notifications برای ذخیره/بازیابی یادآوری‌های زمان‌بندی‌شده
# (تا بعد از ری‌استارت گوشی هم باقی بمانند) از Gson با انواع جنریک استفاده می‌کند.
# بدون این قوانین، R8 در بیلد ریلیز اطلاعات نوع جنریک را حذف می‌کند و خطای
# «Missing type parameter» باعث می‌شود هیچ یادآوری‌ای اصلاً زمان‌بندی نشود.
-keep class com.google.gson.** { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep class com.google.gson.reflect.TypeToken { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# چون minifyEnabled فعاله، بدون این خط‌ها ممکنه R8 کلاس‌های ویجت هوم‌اسکرین رو
# توی بیلد ریلیز حذف/تغییرنام بده و ویجت روی APK نهایی کار نکنه.
-keep class com.myassistant.app.WeatherClockWidgetProvider { *; }
-keep class com.myassistant.app.MainActivity { *; }
-keep class es.antonborri.home_widget.** { *; }
