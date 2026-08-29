package com.myassistant.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

class WeatherClockWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val ACTION_TICK = "com.myassistant.app.WIDGET_TICK"

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

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        val widgetData = HomeWidgetPlugin.getData(context)

        for (appWidgetId in appWidgetIds) {
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

            views.setOnClickPendingIntent(R.id.widget_root, buildLaunchAppIntent(context, appWidgetId))

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        schedulePeriodicTick(context)
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
