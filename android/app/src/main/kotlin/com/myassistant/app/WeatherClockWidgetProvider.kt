package com.myassistant.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Paint
import android.os.Build
import android.os.Bundle
import android.util.TypedValue
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

class WeatherClockWidgetProvider : AppWidgetProvider() {

    /** سبک ظاهریِ یک متغیر: معمولی، بولد، یا ساعت (بولد + بزرگ‌تر + درخشان). */
    private enum class ItemStyle { REGULAR, BOLD, CLOCK }

    /** یک متغیرِ منفرد که باید پشت سر بقیه‌ی متغیرهای همان گروه چیده شود. */
    private data class FlowItem(val text: String, val color: Int, val baseSp: Float, val style: ItemStyle)

    companion object {
        private const val ACTION_TICK = "com.myassistant.app.WIDGET_TICK"

        // عرض و ارتفاع مرجعی که فونت‌های پایه بر اساس آن‌ها طراحی شده‌اند
        private const val BASE_WIDTH_DP = 320f
        private const val BASE_HEIGHT_DP = 60f
        private const val MIN_SCALE = 0.55f
        // فونت هرگز از اندازه‌ی پایه بزرگ‌تر نمی‌شود؛ فقط برای ویجت‌های کوچک
        // کوچک‌تر می‌شود. این کار از هم‌پوشانیِ متن‌ها در گوشی‌ها و لانچرهای
        // مختلف (که گاهی اندازه‌ی واقعی ویجت را نادرست گزارش می‌کنند) جلوگیری
        // می‌کند؛ فضای اضافیِ ویجت‌های بزرگ‌تر به‌جای بزرگ‌ترشدنِ فونت‌ها،
        // صرفِ جا دادنِ متغیرهای بیشتر در هر ردیف (پیش از انتقال به ردیف بعد) می‌شود.
        private const val MAX_SCALE = 1.0f

        // فاصله‌ی افقی بین دو متغیرِ پشت سر هم (باید با layout_marginStart در
        // widget_flow_item[_bold].xml یکی باشد تا اندازه‌گیریِ عرض دقیق بماند)
        private const val ITEM_GAP_DP = 8f
        // پدینگ چپ/راستِ ریشه‌ی ویجت (باید با paddingLeft/paddingRight در
        // weather_clock_widget.xml یکی باشد)
        private const val ROOT_PADDING_DP = 4f

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

    /**
     * متغیرهای دریافتی را به‌ترتیب، پشت سر هم اندازه می‌گیرد و به ردیف‌هایی
     * تقسیم می‌کند که هرکدام در عرضِ واقعیِ ویجت جا می‌شوند؛ به‌محض اینکه
     * متغیرِ بعدی در ردیفِ جاری جا نشود (از جمله وقتی این اتفاق برای آخرین
     * متغیر بیفتد)، همان و بقیه‌ی متغیرها به ردیف بعدی منتقل می‌شوند. هیچ
     * متغیری هرگز بریده (ellipsize) نمی‌شود.
     */
    private fun packIntoLines(context: Context, items: List<FlowItem>, maxWidthPx: Float): List<List<FlowItem>> {
        val metrics = context.resources.displayMetrics
        val gapPx = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, ITEM_GAP_DP, metrics)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)

        val lines = mutableListOf<MutableList<FlowItem>>()
        var current = mutableListOf<FlowItem>()
        var currentWidth = 0f

        for (item in items) {
            paint.textSize = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, item.baseSp, metrics)
            paint.isFakeBoldText = item.style != ItemStyle.REGULAR
            val itemWidth = gapPx + paint.measureText(item.text)
            if (current.isNotEmpty() && currentWidth + itemWidth > maxWidthPx) {
                lines.add(current)
                current = mutableListOf()
                currentWidth = 0f
            }
            current.add(item)
            currentWidth += itemWidth
        }
        if (current.isNotEmpty()) lines.add(current)
        return lines
    }

    /** ردیف‌های ساخته‌شده از یک گروه از متغیرها را داخل ویو-گروهِ مقصد اضافه می‌کند. */
    private fun appendFlowGroup(context: Context, container: RemoteViews, containerId: Int, lines: List<List<FlowItem>>) {
        for (line in lines) {
            val rowViews = RemoteViews(context.packageName, R.layout.widget_flow_row)
            for (item in line) {
                val layoutRes = when (item.style) {
                    ItemStyle.CLOCK -> R.layout.widget_flow_item_clock
                    ItemStyle.BOLD -> R.layout.widget_flow_item_bold
                    ItemStyle.REGULAR -> R.layout.widget_flow_item
                }
                val itemViews = RemoteViews(context.packageName, layoutRes)
                itemViews.setTextViewText(R.id.flow_text, item.text)
                itemViews.setTextColor(R.id.flow_text, item.color)
                itemViews.setTextViewTextSize(R.id.flow_text, TypedValue.COMPLEX_UNIT_SP, item.baseSp)
                rowViews.addView(R.id.widget_flow_row, itemViews)
            }
            container.addView(containerId, rowViews)
        }
    }

    /** ساخت کاملِ RemoteViews: متن‌های فعلی را می‌خواند، اندازه‌گیری می‌کند و به ردیف‌های چیدمانی تبدیل می‌کند. */
    private fun buildViews(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int): RemoteViews {
        val widgetData = HomeWidgetPlugin.getData(context)
        val views = RemoteViews(context.packageName, R.layout.weather_clock_widget)

        val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
        val minWidthDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, BASE_WIDTH_DP.toInt())
        val minHeightDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, BASE_HEIGHT_DP.toInt())

        val widthScale = minWidthDp / BASE_WIDTH_DP
        val heightScale = minHeightDp / BASE_HEIGHT_DP
        // هر کدام از عرض/ارتفاع که رشد کمتری داشته، مقیاس نهایی را تعیین می‌کند.
        var scale = if (widthScale < heightScale) widthScale else heightScale
        if (scale < MIN_SCALE) scale = MIN_SCALE
        if (scale > MAX_SCALE) scale = MAX_SCALE

        val metrics = context.resources.displayMetrics
        val rootPaddingPx = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, ROOT_PADDING_DP * 2, metrics)
        val widthPx = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, minWidthDp.toFloat(), metrics)
        val maxWidthPx = (widthPx - rootPaddingPx).coerceAtLeast(1f)

        // گروه ۰ (اول از همه، جدا از بقیه، در ردیف خودش): ساعت — بزرگ‌تر و با
        // رنگی درخشان‌تر از بقیه‌ی متغیرها (جزئیاتِ درخشش در
        // widget_flow_item_clock.xml تعریف شده است)
        val group0 = listOf(
            FlowItem(currentTimeText(), 0xFF00E5FF.toInt(), 32f * scale, ItemStyle.CLOCK),
        )

        // گروه ۱ (همان ترتیبِ قبلی، بدون ساعت): یادآوری، شهر، دما، ابر
        val group1 = listOf(
            FlowItem(widgetData.getString("reminder_text", "0 یادآوری") ?: "0 یادآوری", 0xFFFFD54F.toInt(), 12f * scale, ItemStyle.BOLD),
            FlowItem(widgetData.getString("city_name", "—") ?: "—", 0xFF8ED8FF.toInt(), 13f * scale, ItemStyle.BOLD),
            FlowItem(widgetData.getString("temperature", "--") ?: "--", 0xFF8ED8FF.toInt(), 18f * scale, ItemStyle.BOLD),
            FlowItem(widgetData.getString("weather_emoji", "🌤️") ?: "🌤️", 0xFF8ED8FF.toInt(), 20f * scale, ItemStyle.REGULAR),
        )

        // گروه ۲ (همان ترتیبِ قبلی): تاریخ میلادی، تاریخ قمری، روز هفته، تاریخ شمسی
        val group2 = listOf(
            FlowItem(widgetData.getString("date_gregorian", "—") ?: "—", 0xFF000000.toInt(), 11f * scale, ItemStyle.REGULAR),
            FlowItem(widgetData.getString("date_hijri", "—") ?: "—", 0xFF000000.toInt(), 11f * scale, ItemStyle.REGULAR),
            FlowItem(widgetData.getString("weekday_text", "—") ?: "—", 0xFF1B5E20.toInt(), 11f * scale, ItemStyle.BOLD),
            FlowItem(widgetData.getString("date_shamsi", "—") ?: "—", 0xFF000000.toInt(), 11f * scale, ItemStyle.REGULAR),
        )

        appendFlowGroup(context, views, R.id.widget_flow_group0, packIntoLines(context, group0, maxWidthPx))
        appendFlowGroup(context, views, R.id.widget_flow_group1, packIntoLines(context, group1, maxWidthPx))
        appendFlowGroup(context, views, R.id.widget_flow_group2, packIntoLines(context, group2, maxWidthPx))

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
        // وقتی کاربر اندازه‌ی ویجت را تغییر می‌دهد، چیدمان و فونت‌ها دوباره
        // متناسب با عرض/ارتفاع جدید بازسازی می‌شوند.
        updateOneWidget(context, appWidgetManager, appWidgetId)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_TICK) {
            // چون ساعت هم یکی از متغیرهای همان چیدمانِ پویاست (نه یک View با
            // شناسه‌ی ثابت)، برای تیکِ هر دقیقه هم کل چیدمان با
            // updateOneWidget بازسازی می‌شود؛ برای این ویجتِ سبک، هزینه‌ی این
            // کار ناچیز است.
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
