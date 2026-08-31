package com.myassistant.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.os.Build
import android.os.Bundle
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import android.text.style.RelativeSizeSpan
import android.text.style.StyleSpan
import android.util.TypedValue
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

class WeatherClockWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val ACTION_TICK = "com.myassistant.app.WIDGET_TICK"

        // عرض/ارتفاع مرجعی که فونتِ پایه (۱۴sp) بر اساس آن طراحی شده؛
        // متناظر با اندازه‌ی پیش‌فرضِ ویجت یعنی ۳ ستون × ۱ ردیف.
        private const val BASE_WIDTH_DP = 180f
        private const val BASE_HEIGHT_DP = 40f
        private const val MIN_SCALE = 0.55f
        // فونت هرگز از اندازه‌ی پایه بزرگ‌تر نمی‌شود؛ وقتی ویجت بزرگ‌تر
        // می‌شود، جای اضافه صرفِ نمایشِ سطرهای بیشتر (تا ۳ سطر) می‌شود،
        // نه بزرگ‌شدنِ بی‌رویه‌ی فونت.
        private const val MAX_SCALE = 1.0f

        private const val BASE_TEXT_SP = 14f
        private const val SEPARATOR = "   •   "

        fun updateAllWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val ids = appWidgetManager.getAppWidgetIds(ComponentName(context, WeatherClockWidgetProvider::class.java))
            if (ids.isNotEmpty()) {
                val provider = WeatherClockWidgetProvider()
                provider.onUpdate(context, appWidgetManager, ids)
            }
        }

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

    /** یک بخش رنگی/با اندازه‌ی نسبیِ خودش را به متن ترکیبی اضافه می‌کند. */
    private fun SpannableStringBuilder.appendSegment(
        text: String,
        color: Int,
        relativeSize: Float,
        bold: Boolean = false,
    ) {
        if (text.isBlank()) return
        if (isNotEmpty()) append(SEPARATOR)
        val start = length
        append(text)
        val end = length
        setSpan(ForegroundColorSpan(color), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        setSpan(RelativeSizeSpan(relativeSize), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        if (bold) {
            setSpan(StyleSpan(Typeface.BOLD), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
    }

    /** ساخت متنِ پیوسته‌ی ترکیبی از همه‌ی فیلدها، به ترتیب اولویت. */
    private fun buildContent(context: Context): CharSequence {
        val widgetData = HomeWidgetPlugin.getData(context)
        val sb = SpannableStringBuilder()

        // ساعت - مهم‌ترین و بزرگ‌ترین
        sb.appendSegment(currentTimeText(), Color.parseColor("#FFFFFF"), 1.6f, bold = true)

        // شهر + دما + وضعیت هوا
        val city = widgetData.getString("city_name", "—") ?: "—"
        val temp = widgetData.getString("temperature", "--") ?: "--"
        val emoji = widgetData.getString("weather_emoji", "🌤️") ?: "🌤️"
        sb.appendSegment("$city $temp $emoji", Color.parseColor("#8ED8FF"), 1.3f, bold = true)

        // یادآوری
        sb.appendSegment(
            widgetData.getString("reminder_text", "0 یادآوری") ?: "0 یادآوری",
            Color.parseColor("#FFD54F"),
            0.9f,
            bold = true,
        )

        // روز هفته + تاریخ شمسی
        sb.appendSegment(widgetData.getString("weekday_text", "—") ?: "—", Color.parseColor("#EDE6FA"), 0.8f)
        sb.appendSegment(widgetData.getString("date_shamsi", "—") ?: "—", Color.parseColor("#EDE6FA"), 0.8f)

        // تاریخ قمری و میلادی
        sb.appendSegment(widgetData.getString("date_hijri", "—") ?: "—", Color.parseColor("#EDE6FA"), 0.8f)
        sb.appendSegment(widgetData.getString("date_gregorian", "—") ?: "—", Color.parseColor("#EDE6FA"), 0.8f)

        return sb
    }

    private fun buildBaseViews(context: Context): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.weather_clock_widget)
        views.setTextViewText(R.id.widget_content, buildContent(context))
        return views
    }

    /** تنظیم اندازه‌ی پایه‌ی فونت متناسب با عرض و ارتفاع واقعیِ ویجت. */
    private fun applyScaledSize(views: RemoteViews, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
        val minWidthDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, BASE_WIDTH_DP.toInt())
        val minHeightDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, BASE_HEIGHT_DP.toInt())

        val widthScale = minWidthDp / BASE_WIDTH_DP
        val heightScale = minHeightDp / BASE_HEIGHT_DP
        var scale = if (widthScale < heightScale) widthScale else heightScale
        if (scale < MIN_SCALE) scale = MIN_SCALE
        if (scale > MAX_SCALE) scale = MAX_SCALE

        views.setTextViewTextSize(R.id.widget_content, TypedValue.COMPLEX_UNIT_SP, BASE_TEXT_SP * scale)
    }

    private fun updateOneWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        val views = buildBaseViews(context)
        applyScaledSize(views, appWidgetManager, appWidgetId)
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
        updateOneWidget(context, appWidgetManager, appWidgetId)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_TICK) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val ids = appWidgetManager.getAppWidgetIds(ComponentName(context, WeatherClockWidgetProvider::class.java))
            for (appWidgetId in ids) {
                updateOneWidget(context, appWidgetManager, appWidgetId)
            }
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
