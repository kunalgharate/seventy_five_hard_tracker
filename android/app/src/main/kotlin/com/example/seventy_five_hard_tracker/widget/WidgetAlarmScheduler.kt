package com.example.seventy_five_hard_tracker.widget

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import java.util.Calendar

/**
 * Schedules native alarms for widget quick-added tasks. The alarm posts a
 * reminder notification via [TaskReminderReceiver] even if the app is never
 * opened. Once the app drains the pending task into Hive, the receiver
 * self-disables (the pending entry is gone) and the app's own notification
 * pipeline takes over.
 */
object WidgetAlarmScheduler {

    fun schedule(context: Context, task: WidgetStore.PendingTask) {
        val hm = task.reminderHourMinute() ?: return
        val triggerAt = nextOccurrence(hm.first, hm.second)
        val alarmManager =
            context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = alarmIntent(context, task)

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            alarmManager.canScheduleExactAlarms()
        ) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent
            )
        } else {
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent
            )
        }
    }

    fun cancel(context: Context, requestCode: Int) {
        val alarmManager =
            context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, TaskReminderReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        alarmManager.cancel(pendingIntent)
    }

    /** Re-arms every pending task's alarm — used after reboot. */
    fun rescheduleAll(context: Context) {
        for (task in WidgetStore.getPendingTasks(context)) {
            schedule(context, task)
        }
    }

    private fun alarmIntent(
        context: Context,
        task: WidgetStore.PendingTask,
    ): PendingIntent {
        val intent =
            Intent(context, TaskReminderReceiver::class.java).apply {
                putExtra(TaskReminderReceiver.EXTRA_TASK_ID, task.id)
                putExtra(TaskReminderReceiver.EXTRA_TASK_TITLE, task.title)
                putExtra(
                    TaskReminderReceiver.EXTRA_REQUEST_CODE,
                    task.alarmRequestCode,
                )
            }
        return PendingIntent.getBroadcast(
            context,
            task.alarmRequestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /** Next wall-clock occurrence of [hour]:[minute] — today if still ahead. */
    fun nextOccurrence(hour: Int, minute: Int): Long {
        val now = Calendar.getInstance()
        val next = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        if (!next.after(now)) {
            next.add(Calendar.DAY_OF_YEAR, 1)
        }
        return next.timeInMillis
    }
}
