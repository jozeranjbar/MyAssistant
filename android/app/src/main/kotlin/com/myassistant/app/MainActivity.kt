package com.myassistant.app

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val pinChannel = "com.myassistant.app/widget_pin"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, pinChannel).setMethodCallHandler { call, result ->
            if (call.method == "requestPin") {
                requestPinWidget()
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun requestPinWidget() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val appWidgetManager = getSystemService(AppWidgetManager::class.java)
            val provider = ComponentName(this, WeatherClockWidgetProvider::class.java)
            if (appWidgetManager.isRequestPinAppWidgetSupported) {
                appWidgetManager.requestPinAppWidget(provider, null, null)
            }
        }
        // در نسخه‌های قدیمی‌تر اندروید (کمتر از ۸)، افزودن خودکار ویجت پشتیبانی
        // نمی‌شود و کاربر باید خودش با نگه‌داشتن انگشت روی صفحه اصلی، ویجت را
        // به‌صورت دستی اضافه کند.
    }
}
