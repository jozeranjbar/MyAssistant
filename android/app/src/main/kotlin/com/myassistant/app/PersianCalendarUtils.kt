package com.myassistant.app

/**
 * محاسبه‌ی تاریخِ شمسی، میلادی (به فارسی) و نامِ روزِ هفته، کاملاً به‌صورت
 * بومی (بدون نیاز به اجرای کدِ Dart). این‌ها دقیقاً همان مقادیری‌اند که
 * پیش‌تر فقط توسط برنامه‌ی فلاتر محاسبه و در حافظه‌ی مشترکِ ویجت ذخیره
 * می‌شدند؛ به همین دلیل بعد از روشن‌شدنِ گوشی (که فلاتر هنوز اجرا نشده)
 * ویجت تا چند دقیقه تاریخِ روزِ قبل را نشان می‌داد. حالا این سه مقدار هر
 * دقیقه، هم‌زمان با خودِ ساعت، بومی و زنده محاسبه می‌شوند.
 *
 * الگوریتمِ تبدیلِ میلادی↔شمسی، همان الگوریتمِ استاندارد و رایجِ
 * «jalaali» (بر پایه‌ی محاسبات دقیقِ سال‌کبیسه با چرخه‌ی ۳۳ ساله) است که
 * کتابخانه‌ی Dart با نام «shamsi_date» (استفاده‌شده در بقیه‌ی برنامه) هم بر
 * همان مبنا عمل می‌کند.
 *
 * توجه: تاریخِ قمری (هجری) عمداً اینجا محاسبه نمی‌شود، چون کتابخانه‌ی
 * «hijri» در سمتِ فلاتر بر پایه‌ی تقویمِ اُم‌القرا (جدولیِ رسمیِ عربستان)
 * کار می‌کند که یک فرمولِ ریاضیِ ساده ندارد؛ پس تاریخِ قمریِ ویجت همچنان
 * از آخرین مقدارِ ذخیره‌شده توسط برنامه خوانده می‌شود و ممکن است، درست
 * مثلِ قبل، تا اجرای بعدیِ برنامه چند دقیقه با یک‌روز تاخیر نمایش داده شود.
 */
object PersianCalendarUtils {

    val shamsiMonthNamesFa = arrayOf(
        "فروردین", "اردیبهشت", "خرداد", "تیر", "مرداد", "شهریور",
        "مهر", "آبان", "آذر", "دی", "بهمن", "اسفند",
    )

    val gregorianMonthNamesFa = arrayOf(
        "ژانویه", "فوریه", "مارس", "آوریل", "مه", "ژوئن",
        "ژوئیه", "آگوست", "سپتامبر", "اکتبر", "نوامبر", "دسامبر",
    )

    /** با اندیسِ ۰=شنبه ... ۶=جمعه؛ باید دقیقاً با shamsiWeekdayNamesFa سمتِ Dart یکی باشد. */
    val shamsiWeekdayNamesFa = arrayOf(
        "شنبه", "یکشنبه", "دوشنبه", "سه‌شنبه", "چهارشنبه", "پنجشنبه", "جمعه",
    )

    private val jalaliBreaks = intArrayOf(
        -61, 9, 38, 199, 426, 686, 756, 818, 1111, 1181, 1210, 1635,
        2060, 2097, 2192, 2262, 2324, 2394, 2456, 3178,
    )

    private fun jalCal(jy: Int): Pair<Int, Int> {
        val bl = jalaliBreaks.size
        val gy = jy + 621
        var leapJ = -14
        var jp = jalaliBreaks[0]
        var jump = 0
        var i = 1
        while (i < bl) {
            val jm = jalaliBreaks[i]
            jump = jm - jp
            if (jy < jm) break
            leapJ += (jump / 33) * 8 + ((jump % 33) / 4)
            jp = jm
            i += 1
        }
        var n = jy - jp
        leapJ += (n / 33) * 8 + ((n % 33 + 3) / 4)
        if (jump % 33 == 4 && jump - n == 4) leapJ += 1
        val leapG = gy / 4 - ((gy / 100 + 1) * 3) / 4 - 150
        val march = 20 + leapJ - leapG
        if (jump - n < 6) n = n - jump + (jump / 33) * 33
        var leap = ((n + 1) % 33 - 1) % 4
        if (leap == -1) leap = 4
        return Pair(leap, march)
    }

    /** شماره‌ی روزِ ژولینیِ تاریخِ میلادیِ (gy, gm, gd). */
    private fun g2d(gy: Int, gm: Int, gd: Int): Int {
        var d = ((gy + (gm - 8) / 6 + 100100) * 1461) / 4 +
            (153 * ((gm + 9) % 12) + 2) / 5 +
            gd - 34840408
        d -= (((gy + 100100 + (gm - 8) / 6) / 100) * 3) / 4
        d += 752
        return d
    }

    data class ShamsiDate(val year: Int, val month: Int, val day: Int)

    /** تبدیلِ تاریخِ میلادی به شمسی. */
    fun gregorianToJalali(gy: Int, gm: Int, gd: Int): ShamsiDate {
        val jdn = g2d(gy, gm, gd)
        var jy = gy - 621
        val (leap, march) = jalCal(jy)
        val jdn1f = g2d(gy, 3, march)
        var k = jdn - jdn1f
        if (k >= 0) {
            if (k <= 185) {
                return ShamsiDate(jy, 1 + k / 31, k % 31 + 1)
            }
            k -= 186
        } else {
            jy -= 1
            k += 179
            if (leap == 1) k += 1
        }
        val jm = 7 + k / 30
        val jd = k % 30 + 1
        return ShamsiDate(jy, jm, jd)
    }
}
