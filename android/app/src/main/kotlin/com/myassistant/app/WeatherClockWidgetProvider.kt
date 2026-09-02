package com.myassistant.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Typeface
import android.os.Build
import android.os.Bundle
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import android.text.style.RelativeSizeSpan
import android.text.style.StyleSpan
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import java.util.Calendar
import java.util.Locale

class WeatherClockWidgetProvider : AppWidgetProvider() {

    /** سبک ظاهریِ یک متغیر: معمولی، بولد، یا ساعت (بولد + بزرگ‌تر + درخشان). */
    private enum class ItemStyle { REGULAR, BOLD, CLOCK }

    /** یک متغیرِ منفرد که باید پشت سر بقیه‌ی متغیرها در متنِ پیوسته چیده شود. */
    private data class FlowItem(val text: String, val color: Int, val relativeSize: Float, val style: ItemStyle)

    companion object {
        private const val ACTION_TICK = "com.myassistant.app.WIDGET_TICK"

        // اندازه‌ی پایه‌ی فونت متن (بر حسب sp) که بقیه‌ی اندازه‌ها نسبت به آن محاسبه می‌شوند
        private const val BASE_TEXT_SIZE_SP = 14f

        private fun buildTickPendingIntent(context: Context): PendingIntent {
            val intent = Intent(context, WeatherClockWidgetProvider::class.java).apply {
                action = ACTION_TICK
            }
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            return PendingIntent.getBroadcast(context, 0, intent, flags)
        }

        /**
         * به‌جای یک آلارم تکرارشونده‌ی غیردقیق (که سیستم برای صرفه‌جویی باتری
         * با تأخیر اجرا می‌کند)، هر بار یک آلارم دقیق فقط برای لحظه‌ی شروع
         * دقیقه‌ی بعد تنظیم می‌شود؛ در هر تیک دوباره برای دقیقه‌ی بعدی
         * زمان‌بندی می‌شود.
         */
        private fun scheduleNextTick(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val pendingIntent = buildTickPendingIntent(context)
            val nextMinute = Calendar.getInstance().apply {
                add(Calendar.MINUTE, 1)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }.timeInMillis

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, nextMinute, pendingIntent)
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, nextMinute, pendingIntent)
            }
        }

        private fun cancelPeriodicTick(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.cancel(buildTickPendingIntent(context))
        }
    }

    /** یک متغیر را به builder اضافه می‌کند؛ separator دقیقاً همانی است که پیش از متن درج می‌شود
     *  (""=بدون فاصله، " "=فقط فاصله برای چسباندن به‌هم، "  •  "=نقطه‌ی سفیدِ جداکننده). */
    private fun appendItem(builder: SpannableStringBuilder, item: FlowItem, separator: String) {
        // نقطه‌ی جداکننده و فاصله‌ی ساده رنگ پیش‌فرضِ TextView (سفید) را می‌گیرند،
        // پس نیازی به اسپن رنگ جداگانه برای خودِ separator نیست.
        builder.append(separator)
        val start = builder.length
        builder.append(item.text)
        val end = builder.length
        builder.setSpan(ForegroundColorSpan(item.color), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        builder.setSpan(RelativeSizeSpan(item.relativeSize), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        if (item.style != ItemStyle.REGULAR) {
            builder.setSpan(StyleSpan(Typeface.BOLD), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
    }

    /**
     * ساخت کاملِ RemoteViews، دقیقاً به همین ترتیب:
     * ساعت (زرد طلایی، فونت ۳۰) ← •(سفید) ← شهر+دما+وضعیت‌آسمان (آبی غلیظ،
     * بدون نقطه‌ی داخلی) ← •(سفید) ← عدد و کلمه‌ی یادآوری ← •(سفید) ←
     * هفته (سبز غلیظ) ← روز/ماه شمسی ← روز/ماه قمری ← روز/ماه میلادی
     * (این سه‌تای آخر بدون هیچ نقطه‌ای، فقط با فاصله از هم جدا می‌شوند).
     */
    private fun buildViews(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int): RemoteViews {
        val widgetData = HomeWidgetPlugin.getData(context)
        val views = RemoteViews(context.packageName, R.layout.weather_clock_widget)

        val goldColor = 0xFFFFD700.toInt() // زرد طلایی (ساعت)
        val darkBlueColor = 0xFF0D47A1.toInt() // آبی غلیظ (شهر/دما/وضعیت آسمان)
        val reminderColor = 0xFFFFD54F.toInt() // زرد (یادآوری)
        val darkGreenColor = 0xFF1B5E20.toInt() // سبز غلیظ (روز هفته)
        val dateColor = 0xFF000000.toInt() // سیاه (تاریخ‌های شمسی/قمری/میلادی)

        val clock = FlowItem(currentTimeText(), goldColor, 30f / BASE_TEXT_SIZE_SP, ItemStyle.CLOCK)
        val city = FlowItem(widgetData.getString("city_name", "—") ?: "—", darkBlueColor, 1.0f, ItemStyle.BOLD)
        val temp = FlowItem(widgetData.getString("temperature", "--") ?: "--", darkBlueColor, 1.3f, ItemStyle.BOLD)
        val emoji = FlowItem(widgetData.getString("weather_emoji", "🌤️") ?: "🌤️", darkBlueColor, 1.4f, ItemStyle.REGULAR)
        val reminder = FlowItem(widgetData.getString("reminder_text", "0 یادآوری") ?: "0 یادآوری", reminderColor, 0.9f, ItemStyle.BOLD)
        val weekday = FlowItem(widgetData.getString("weekday_text", "—") ?: "—", darkGreenColor, 0.85f, ItemStyle.BOLD)
        val dateShamsi = FlowItem(widgetData.getString("date_shamsi", "—") ?: "—", dateColor, 0.8f, ItemStyle.REGULAR)
        val dateHijri = FlowItem(widgetData.getString("date_hijri", "—") ?: "—", dateColor, 0.8f, ItemStyle.REGULAR)
        val dateGregorian = FlowItem(widgetData.getString("date_gregorian", "—") ?: "—", dateColor, 0.8f, ItemStyle.REGULAR)

        val dot = "  •  "
        val builder = SpannableStringBuilder()
        appendItem(builder, clock, "")
        builder.append("\n")
        appendItem(builder, city, "")
        appendItem(builder, temp, " ")
        appendItem(builder, emoji, " ")
        appendItem(builder, reminder, dot)
        appendItem(builder, weekday, dot)
        appendItem(builder, dateShamsi, " ")
        appendItem(builder, dateHijri, " ")
        appendItem(builder, dateGregorian, " ")

        views.setTextViewText(R.id.widget_content, builder)
        views.setTextViewTextSize(R.id.widget_content, android.util.TypedValue.COMPLEX_UNIT_SP, BASE_TEXT_SIZE_SP)

        return views
    }

    private fun updateOneWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        val views = buildViews(context, appWidgetManager, appWidgetId)
        views.setOnClickPendingIntent(R.id.widget_root, buildLaunchAppIntent(context, appWidgetId))
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateOneWidget(context, appWidgetManager, appWidgetId)
        }
        scheduleNextTick(context)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        // وقتی کاربر اندازه‌ی ویجت را تغییر می‌دهد، چیدمان دوباره بازسازی می‌شود.
        updateOneWidget(context, appWidgetManager, appWidgetId)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_TICK) {
            // چون ساعت هم یکی از متغیرهای همان متنِ پویاست، برای تیکِ هر دقیقه
            // هم کل محتوا با updateOneWidget بازسازی می‌شود.
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val ids = appWidgetManager.getAppWidgetIds(ComponentName(context, WeatherClockWidgetProvider::class.java))
            for (appWidgetId in ids) {
                updateOneWidget(context, appWidgetManager, appWidgetId)
            }
            // زمان‌بندی تیک دقیق بعدی
            scheduleNextTick(context)
        }
    }

    private fun buildLaunchAppIntent(context: Context, appWidgetId: Int): PendingIntent {
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        return PendingIntent.getActivity(context, appWidgetId, launchIntent, flags)
    }

    private fun currentTimeText(): String {
        // اعداد انگلیسی (بدون تبدیل به فارسی)، به‌صورت ۲۴ ساعتی.
        val calendar = Calendar.getInstance()
        val hour24 = calendar.get(Calendar.HOUR_OF_DAY)
        val minute = calendar.get(Calendar.MINUTE)
        return String.format(Locale.US, "%02d:%02d", hour24, minute)
    }

    override fun onEnabled(context: Context) {
        scheduleNextTick(context)
    }

    override fun onDisabled(context: Context) {
        cancelPeriodicTick(context)
    }
}
