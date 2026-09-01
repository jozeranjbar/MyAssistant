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
import java.text.SimpleDateFormat
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

    /** یک گروه از متغیرها را به یک متنِ پیوسته (با جداکننده «•») تبدیل می‌کند و به انتهای builder اضافه می‌کند. */
    private fun appendGroup(builder: SpannableStringBuilder, items: List<FlowItem>) {
        for ((index, item) in items.withIndex()) {
            if (builder.isNotEmpty()) builder.append("  •  ")
            val start = builder.length
            builder.append(item.text)
            val end = builder.length
            builder.setSpan(ForegroundColorSpan(item.color), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            builder.setSpan(RelativeSizeSpan(item.relativeSize), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            if (item.style != ItemStyle.REGULAR) {
                builder.setSpan(StyleSpan(Typeface.BOLD), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            }
        }
    }

    /** ساخت کاملِ RemoteViews: متن‌های فعلی را می‌خواند و به یک متنِ رنگی و پیوسته تبدیل می‌کند. */
    private fun buildViews(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int): RemoteViews {
        val widgetData = HomeWidgetPlugin.getData(context)
        val views = RemoteViews(context.packageName, R.layout.weather_clock_widget)

        // گروه ۰: ساعت — بزرگ‌تر و با رنگی درخشان‌تر از بقیه‌ی متغیرها
        val group0 = listOf(
            FlowItem(currentTimeText(), 0xFF00E5FF.toInt(), 1.7f, ItemStyle.CLOCK),
        )

        // گروه ۱: یادآوری، شهر، دما، ابر
        val group1 = listOf(
            FlowItem(widgetData.getString("reminder_text", "0 یادآوری") ?: "0 یادآوری", 0xFFFFD54F.toInt(), 0.9f, ItemStyle.BOLD),
            FlowItem(widgetData.getString("city_name", "—") ?: "—", 0xFF8ED8FF.toInt(), 1.0f, ItemStyle.BOLD),
            FlowItem(widgetData.getString("temperature", "--") ?: "--", 0xFF8ED8FF.toInt(), 1.3f, ItemStyle.BOLD),
            FlowItem(widgetData.getString("weather_emoji", "🌤️") ?: "🌤️", 0xFF8ED8FF.toInt(), 1.4f, ItemStyle.REGULAR),
        )

        // گروه ۲: تاریخ میلادی، تاریخ قمری، روز هفته، تاریخ شمسی
        val group2 = listOf(
            FlowItem(widgetData.getString("date_gregorian", "—") ?: "—", 0xFFFFFFFF.toInt(), 0.8f, ItemStyle.REGULAR),
            FlowItem(widgetData.getString("date_hijri", "—") ?: "—", 0xFFFFFFFF.toInt(), 0.8f, ItemStyle.REGULAR),
            FlowItem(widgetData.getString("weekday_text", "—") ?: "—", 0xFFA5D6A7.toInt(), 0.8f, ItemStyle.BOLD),
            FlowItem(widgetData.getString("date_shamsi", "—") ?: "—", 0xFFFFFFFF.toInt(), 0.8f, ItemStyle.REGULAR),
        )

        val builder = SpannableStringBuilder()
        appendGroup(builder, group0)
        if (builder.isNotEmpty()) builder.append("\n")
        appendGroup(builder, group1)
        if (builder.isNotEmpty()) builder.append("  •  ")
        appendGroup(builder, group2)

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
        // اعداد انگلیسی، بدون تبدیل به فارسی
        val formatter = SimpleDateFormat("HH:mm", Locale.US)
        return formatter.format(Calendar.getInstance().time)
    }

    override fun onEnabled(context: Context) {
        scheduleNextTick(context)
    }

    override fun onDisabled(context: Context) {
        cancelPeriodicTick(context)
    }
}
