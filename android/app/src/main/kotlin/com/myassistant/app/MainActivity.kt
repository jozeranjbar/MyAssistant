package com.myassistant.app

import android.appwidget.AppWidgetManager
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val pinChannel = "com.myassistant.app/widget_pin"
    private val browserChannel = "com.myassistant.app/open_in_browser"

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, browserChannel).setMethodCallHandler { call, result ->
            if (call.method == "openUrlInBrowser") {
                val url = call.argument<String>("url")
                if (url.isNullOrEmpty()) {
                    result.error("NO_URL", "آدرس ارسال نشده است", null)
                    return@setMethodCallHandler
                }
                val opened = openUrlInBrowser(url)
                if (opened) {
                    result.success(null)
                } else {
                    result.error("NO_BROWSER", "هیچ مرورگری برای باز کردن آدرس پیدا نشد", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    /**
     * آدرس (اینجا آدرس سرور محلی http://127.0.0.1:port/...) را با
     * ACTION_VIEW باز می‌کند تا به‌جای WebView داخلی، خودِ مرورگر
     * (ترجیحاً Chrome) آن را اجرا کند — چون WebXR/immersive-ar فقط
     * داخل یک مرورگر واقعی و روی Secure Context کار می‌کند.
     */
    private fun openUrlInBrowser(url: String): Boolean {
        val uri = Uri.parse(url)

        // ابتدا تلاش برای باز کردن مستقیم با Chrome
        val chromeIntent = Intent(Intent.ACTION_VIEW, uri).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            setPackage("com.android.chrome")
        }
        try {
            startActivity(chromeIntent)
            return true
        } catch (e: ActivityNotFoundException) {
            // Chrome نصب نیست؛ به مرورگر پیش‌فرض/انتخاب کاربر برمی‌گردیم
        }

        val genericIntent = Intent(Intent.ACTION_VIEW, uri).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return try {
            startActivity(genericIntent)
            true
        } catch (e: ActivityNotFoundException) {
            false
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
