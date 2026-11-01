package com.example.seventy_five_hard_tracker.widget

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Re-arms widget quick-add alarms after reboot or app update. */
class WidgetBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            -> WidgetAlarmScheduler.rescheduleAll(context)
        }
    }
}
