package com.myassistant.app

import android.app.Application
import android.content.Intent
import android.content.IntentFilter

/**
 * کلاسِ Application سفارشی، فقط برای این‌که بتوانیم WidgetScreenReceiver
 * (شنونده‌ی SCREEN_ON/SCREEN_OFF) را همان اول کارِ پراسسِ برنامه، به‌صورت
 * پویا ثبت کنیم — این دو اکشن را نمی‌شود در AndroidManifest ثبت کرد.
 */
class MyApplication : Application() {

    private val screenReceiver = WidgetScreenReceiver()

    override fun onCreate() {
        super.onCreate()
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
        }
        registerReceiver(screenReceiver, filter)
    }
}
