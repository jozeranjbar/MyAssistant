package com.myassistant.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * گیرنده‌ی پخش‌های سیستمیِ روشن/خاموش‌شدنِ صفحه.
 *
 * ACTION_SCREEN_ON و ACTION_SCREEN_OFF را نمی‌شود در AndroidManifest ثبت
 * کرد (این یک محدودیتِ خودِ اندروید است، نه مربوط به Oreo)، برای همین این
 * کلاس باید به‌صورت پویا (در MyApplication.onCreate) با registerReceiver
 * ثبت شود.
 */
class WidgetScreenReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_SCREEN_ON -> WeatherClockWidgetProvider.onScreenOn(context)
            Intent.ACTION_SCREEN_OFF -> WeatherClockWidgetProvider.onScreenOff(context)
        }
    }
}
