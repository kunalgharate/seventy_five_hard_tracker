package com.example.seventy_five_hard_tracker.widget

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.example.seventy_five_hard_tracker.MainActivity
import com.example.seventy_five_hard_tracker.R

/**
 * Fires the native alarm for a widget quick-added task: posts a reminder
 * notification, then re-arms itself for the next day.
 *
 * Self-disables once the app has drained the pending task into Hive — the
 * app's SmartNotificationService takes over the reminder from then on.
 */
class TaskReminderReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val taskId = intent.getStringExtra(EXTRA_TASK_ID) ?: return
        val title = intent.getStringExtra(EXTRA_TASK_TITLE) ?: return
        val requestCode = intent.getIntExtra(EXTRA_REQUEST_CODE, 0)

        // If the pending entry is gone, the app owns the task now — the
        // app's own scheduling handles reminders; do not double-notify.
        val pending = WidgetStore.findPendingTask(context, taskId) ?: return

        if (!pending.completed) {
            postNotification(context, title, requestCode)
        }

        // Daily task → re-arm for tomorrow at the same time.
        WidgetAlarmScheduler.schedule(context, pending)
    }

    private fun postNotification(
        context: Context,
        title: String,
        requestCode: Int,
    ) {
        ensureChannel(context)

        val launchIntent =
            Intent(context, MainActivity::class.java).apply {
                data = Uri.parse("dailymettle://tasks?homeWidget")
                action =
                    "es.antonborri.home_widget.action.LAUNCH"
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
        val contentIntent = PendingIntent.getActivity(
            context,
            requestCode,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("\u23F0 $title")
            .setContentText(
                context.getString(R.string.widget_reminder_body)
            )
            .setContentIntent(contentIntent)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()

        try {
            NotificationManagerCompat.from(context)
                .notify(requestCode, notification)
        } catch (_: SecurityException) {
            // POST_NOTIFICATIONS not granted — nothing else we can do here.
        }
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE)
                as NotificationManager
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return

        val soundUri = Uri.parse(
            "android.resource://${context.packageName}/${R.raw.notification}"
        )
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Smart Task Reminders",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Smart reminders for pending tasks"
            setSound(
                soundUri,
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                    .build(),
            )
            enableVibration(true)
        }
        manager.createNotificationChannel(channel)
    }

    companion object {
        const val EXTRA_TASK_ID = "extra_task_id"
        const val EXTRA_TASK_TITLE = "extra_task_title"
        const val EXTRA_REQUEST_CODE = "extra_request_code"

        /** Same channel id the Dart side uses for task reminders. */
        const val CHANNEL_ID = "smart_reminders_v2"
    }
}
