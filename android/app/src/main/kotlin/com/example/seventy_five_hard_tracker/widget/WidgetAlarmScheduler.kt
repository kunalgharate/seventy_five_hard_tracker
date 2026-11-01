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
        val triggerAt = nextTrigger(task) ?: return
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

    /**
     * Next trigger across the task's reminder schedule. TaskReminderReceiver
     * re-arms after every fire, so returning the single next occurrence is
     * enough for multi-time, hourly and interval schedules to repeat.
     */
    fun nextTrigger(task: WidgetStore.PendingTask): Long? {
        val now = Calendar.getInstance()
        return when (task.reminderType()) {
            "multiple", "custom" -> {
                val times = task.reminderTimes()
                times.mapNotNull { (h, m) -> todayAt(h, m, onlyFuture = true) }
                    .minOrNull()
                    ?: times.minOfOrNull { it.first * 60 + it.second }?.let {
                        tomorrowAt(it / 60, it % 60)
                    }
            }
            "hourly" -> {
                val start = task.reminderStartTime()?.first
                    ?: task.reminderStartHour
                hourlyNext(start, task.reminderEndHour, now)
            }
            "interval" -> {
                val interval = task.intervalMinutes() ?: return null
                val start = task.reminderStartTime() ?: return null
                intervalNext(start, interval, task.reminderEndHour, now)
            }
            else -> task.reminderHourMinute()?.let { (h, m) ->
                nextOccurrence(h, m)
            }
        }
    }

    /** Today at h:m — null when the time already passed. */
    private fun todayAt(hour: Int, minute: Int, onlyFuture: Boolean): Long? {
        val t = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        return if (!onlyFuture || t.after(Calendar.getInstance()))
            t.timeInMillis
        else
            null
    }

    private fun tomorrowAt(hour: Int, minute: Int): Long =
        Calendar.getInstance().apply {
            add(Calendar.DAY_OF_YEAR, 1)
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis

    /** Next hour boundary between [startHour] and [endHour]; tomorrow at
     * [startHour] when today's window is over. */
    private fun hourlyNext(startHour: Int, endHour: Int, now: Calendar): Long {
        var h = now.get(Calendar.HOUR_OF_DAY)
        if (now.get(Calendar.MINUTE) > 0 || now.get(Calendar.SECOND) > 0) h += 1
        if (h < startHour) h = startHour
        return if (h <= endHour) {
            todayAt(h, 0, onlyFuture = false) ?: tomorrowAt(startHour, 0)
        } else {
            tomorrowAt(startHour, 0)
        }
    }

    /** Start at [start], step [intervalMin] until [endHour]:59; the first
     * slot still ahead of now wins, otherwise tomorrow's start. */
    private fun intervalNext(
        start: Pair<Int, Int>,
        intervalMin: Int,
        endHour: Int,
        now: Calendar,
    ): Long {
        val t = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, start.first)
            set(Calendar.MINUTE, start.second)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val end = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, endHour)
            set(Calendar.MINUTE, 59)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        while (!t.after(now) && t.before(end)) {
            t.add(Calendar.MINUTE, intervalMin)
        }
        return if (t.before(end)) {
            t.timeInMillis
        } else {
            tomorrowAt(start.first, start.second)
        }
    }
}
