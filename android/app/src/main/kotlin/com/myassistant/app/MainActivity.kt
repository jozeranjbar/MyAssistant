package com.myassistant.app

import android.appwidget.AppWidgetManager
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Intent
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

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
            if (call.method == "openHtmlInBrowser") {
                val path = call.argument<String>("path")
                if (path.isNullOrEmpty()) {
                    result.error("NO_PATH", "مسیر فایل ارسال نشده است", null)
                    return@setMethodCallHandler
                }
                val opened = openHtmlInBrowser(path)
                if (opened) {
                    result.success(null)
                } else {
                    result.error("NO_BROWSER", "هیچ مرورگری برای باز کردن فایل پیدا نشد", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    /**
     * فایل HTML محلی را با ACTION_VIEW (نه Share) از طریق FileProvider باز می‌کند
     * تا به‌جای WebView داخلی، خودِ مرورگر (ترجیحاً Chrome) آن را اجرا کند —
     * چون WebXR/immersive-ar فقط داخل یک مرورگر واقعی کار می‌کند.
     */
    private fun openHtmlInBrowser(path: String): Boolean {
        val file = File(path)
        if (!file.exists()) return false

        val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)

        // ابتدا تلاش برای باز کردن مستقیم با Chrome
        val chromeIntent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "text/html")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            setPackage("com.android.chrome")
        }
        try {
            startActivity(chromeIntent)
            return true
        } catch (e: ActivityNotFoundException) {
            // Chrome نصب نیست؛ به مرورگر پیش‌فرض/انتخاب کاربر برمی‌گردیم
        }

        val genericIntent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "text/html")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
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
