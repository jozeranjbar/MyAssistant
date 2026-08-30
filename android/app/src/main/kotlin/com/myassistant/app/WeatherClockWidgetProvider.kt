package com.myassistant.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.TypedValue
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

class WeatherClockWidgetProvider : AppWidgetProvider() {

    /** اندازه‌ی پایه‌ی هر فیلد (بر حسب sp) که در عرض مرجع BASE_WIDTH_DP طراحی شده. */
    private data class SizeSpec(val id: Int, val baseSp: Float)

    companion object {
        private const val ACTION_TICK = "com.myassistant.app.WIDGET_TICK"

        // عرض و ارتفاع مرجعی که فونت‌های پایه بر اساس آن‌ها طراحی شده‌اند
        private const val BASE_WIDTH_DP = 320f
        private const val BASE_HEIGHT_DP = 60f
        private const val MIN_SCALE = 0.55f
        // فونت هرگز از اندازه‌ی پایه بزرگ‌تر نمی‌شود؛ فقط برای ویجت‌های کوچک
        // کوچک‌تر می‌شود. این کار از هم‌پوشانی/بریده‌شدن متن‌ها در گوشی‌ها و
        // لانچرهای مختلف (که گاهی اندازه‌ی واقعی ویجت را نادرست گزارش می‌کنند)
        // جلوگیری می‌کند.
        private const val MAX_SCALE = 1.0f

        private val sizeSpecs = listOf(
            SizeSpec(R.id.widget_city, 13f),
            SizeSpec(R.id.widget_temp, 18f),
            SizeSpec(R.id.widget_weather_emoji, 20f),
            SizeSpec(R.id.widget_clock, 22f),
            SizeSpec(R.id.widget_reminder, 12f),
            SizeSpec(R.id.widget_weekday, 11f),
            SizeSpec(R.id.widget_date_shamsi, 11f),
            SizeSpec(R.id.widget_date_hijri, 11f),
            SizeSpec(R.id.widget_date_gregorian, 11f),
        )

        fun updateAllWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val ids = appWidgetManager.getAppWidgetIds(ComponentName(context, WeatherClockWidgetProvider::class.java))
            if (ids.isNotEmpty()) {
                val provider = WeatherClockWidgetProvider()
                provider.onUpdate(context, appWidgetManager, ids)
            }
        }

        private fun schedulePeriodicTick(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, WeatherClockWidgetProvider::class.java).apply {
                action = ACTION_TICK
            }
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val pendingIntent = PendingIntent.getBroadcast(context, 0, intent, flags)
            val triggerAt = Calendar.getInstance().apply {
                add(Calendar.MINUTE, 1)
                set(Calendar.SECOND, 0)
            }.timeInMillis
            alarmManager.setRepeating(AlarmManager.RTC, triggerAt, 60_000L, pendingIntent)
        }

        private fun cancelPeriodicTick(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, WeatherClockWidgetProvider::class.java).apply {
                action = ACTION_TICK
            }
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val pendingIntent = PendingIntent.getBroadcast(context, 0, intent, flags)
            alarmManager.cancel(pendingIntent)
        }
    }

    /** ساخت RemoteViews با متن‌های فعلی (بدون تنظیم اندازه‌ی فونت). */
    private fun buildBaseViews(context: Context): RemoteViews {
        val widgetData = HomeWidgetPlugin.getData(context)
        val views = RemoteViews(context.packageName, R.layout.weather_clock_widget)

        views.setTextViewText(R.id.widget_city, widgetData.getString("city_name", "—"))
        views.setTextViewText(R.id.widget_temp, widgetData.getString("temperature", "--"))
        views.setTextViewText(R.id.widget_weather_emoji, widgetData.getString("weather_emoji", "🌤️"))
        views.setTextViewText(R.id.widget_clock, currentTimeText())
        views.setTextViewText(R.id.widget_reminder, widgetData.getString("reminder_text", "0 یادآوری"))
        views.setTextViewText(R.id.widget_weekday, widgetData.getString("weekday_text", "—"))
        views.setTextViewText(R.id.widget_date_shamsi, widgetData.getString("date_shamsi", "—"))
        views.setTextViewText(R.id.widget_date_hijri, widgetData.getString("date_hijri", "—"))
        views.setTextViewText(R.id.widget_date_gregorian, widgetData.getString("date_gregorian", "—"))

        return views
    }

    /** تنظیم اندازه‌ی فونت‌ها متناسب با عرض و ارتفاع واقعی ویجت روی گوشیِ کاربر. */
    private fun applyScaledSizes(views: RemoteViews, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
        val minWidthDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, BASE_WIDTH_DP.toInt())
        val minHeightDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, BASE_HEIGHT_DP.toInt())

        val widthScale = minWidthDp / BASE_WIDTH_DP
        val heightScale = minHeightDp / BASE_HEIGHT_DP
        // هر کدام از عرض/ارتفاع که رشد کمتری داشته، مقیاس نهایی را تعیین می‌کند
        // تا فونت هیچ‌وقت از فضای واقعی موجود بزرگ‌تر نشود و به‌هم نریزد.
        var scale = if (widthScale < heightScale) widthScale else heightScale
        if (scale < MIN_SCALE) scale = MIN_SCALE
        if (scale > MAX_SCALE) scale = MAX_SCALE

        for (spec in sizeSpecs) {
            views.setTextViewTextSize(spec.id, TypedValue.COMPLEX_UNIT_SP, spec.baseSp * scale)
        }
    }

    private fun updateOneWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        val views = buildBaseViews(context)
        applyScaledSizes(views, appWidgetManager, appWidgetId)
        views.setOnClickPendingIntent(R.id.widget_root, buildLaunchAppIntent(context, appWidgetId))
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateOneWidget(context, appWidgetManager, appWidgetId)
        }
        schedulePeriodicTick(context)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        // وقتی کاربر اندازه‌ی ویجت را تغییر می‌دهد، فونت‌ها دوباره متناسب با
        // عرض جدید محاسبه می‌شوند.
        updateOneWidget(context, appWidgetManager, appWidgetId)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_TICK) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val ids = appWidgetManager.getAppWidgetIds(ComponentName(context, WeatherClockWidgetProvider::class.java))
            for (appWidgetId in ids) {
                val views = RemoteViews(context.packageName, R.layout.weather_clock_widget)
                views.setTextViewText(R.id.widget_clock, currentTimeText())
                views.setOnClickPendingIntent(R.id.widget_root, buildLaunchAppIntent(context, appWidgetId))
                appWidgetManager.partiallyUpdateAppWidget(appWidgetId, views)
            }
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
        schedulePeriodicTick(context)
    }

    override fun onDisabled(context: Context) {
        cancelPeriodicTick(context)
    }
}
