package com.example.seventy_five_hard_tracker.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.widget.RemoteViews
import com.example.seventy_five_hard_tracker.MainActivity
import com.example.seventy_five_hard_tracker.R
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Home-screen widget showing today's regular tasks. Row taps toggle
 * completion natively via [ACTION_TOGGLE_TASK] (WidgetStore flips the
 * snapshot and journals the event for the app's Hive drain); the "+" button
 * opens [QuickAddTaskActivity] — a floating dialog, not the full app.
 */
class DailyTasksWidgetProvider : HomeWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_TOGGLE_TASK) {
            // Row fill-in merged "dailymettle://toggle/<taskId>" here.
            // Handled natively (not via the home_widget background Dart
            // callback): the plugin's broadcast template is FLAG_IMMUTABLE,
            // which silently drops fill-in intents on API 31+ — and a
            // native flip updates the list instantly with no headless
            // engine round-trip.
            val taskId = intent.data?.lastPathSegment
            if (!taskId.isNullOrEmpty()) {
                WidgetStore.toggleTask(context, taskId)
                refresh(context)
            }
            return
        }
        super.onReceive(context, intent)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (widgetId in appWidgetIds) {
            val tasks = WidgetStore.getTasks(context)
            val remaining = tasks.count { !it.completed }

            val views =
                RemoteViews(context.packageName, R.layout.widget_daily_tasks)
                    .apply {
                        setTextViewText(
                            R.id.widget_date,
                            SimpleDateFormat("EEE, MMM d", Locale.getDefault())
                                .format(Date()),
                        )
                        setTextViewText(
                            R.id.widget_count,
                            if (tasks.isEmpty()) {
                                context.getString(R.string.widget_no_tasks)
                            } else {
                                context.getString(
                                    R.string.widget_remaining, remaining
                                )
                            },
                        )

                        // "+" → floating quick-add dialog (no full app launch).
                        val addIntent =
                            PendingIntent.getActivity(
                                context,
                                0,
                                Intent(context, QuickAddTaskActivity::class.java),
                                PendingIntent.FLAG_UPDATE_CURRENT or
                                    PendingIntent.FLAG_IMMUTABLE,
                            )
                        setOnClickPendingIntent(R.id.widget_add_button, addIntent)

                        // Header tap opens the app's regular-tasks tab.
                        val openAppIntent =
                            HomeWidgetLaunchIntent.getActivity(
                                context,
                                MainActivity::class.java,
                                Uri.parse("dailymettle://tasks?homeWidget"),
                            )
                        setOnClickPendingIntent(R.id.widget_header, openAppIntent)

                        // Task list rendered by DailyTasksWidgetService.
                        val serviceIntent =
                            Intent(
                                context,
                                DailyTasksWidgetService::class.java,
                            ).apply {
                                putExtra(
                                    AppWidgetManager.EXTRA_APPWIDGET_ID,
                                    widgetId,
                                )
                                // Make each intent unique per widget instance.
                                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
                            }
                        setRemoteAdapter(R.id.widget_task_list, serviceIntent)
                        setEmptyView(R.id.widget_task_list, R.id.widget_empty)

                        // Row taps fill this broadcast template with a
                        // per-task URI → onReceive(ACTION_TOGGLE_TASK).
                        // FLAG_MUTABLE is required on API 31+ or the fill-in
                        // data is silently dropped.
                        var toggleFlags = PendingIntent.FLAG_UPDATE_CURRENT
                        if (Build.VERSION.SDK_INT >= 31) {
                            toggleFlags =
                                toggleFlags or PendingIntent.FLAG_MUTABLE
                        }
                        val toggleTemplate =
                            PendingIntent.getBroadcast(
                                context,
                                0,
                                Intent(
                                        context,
                                        DailyTasksWidgetProvider::class.java,
                                    )
                                    .setAction(ACTION_TOGGLE_TASK),
                                toggleFlags,
                            )
                        setPendingIntentTemplate(
                            R.id.widget_task_list,
                            toggleTemplate,
                        )

                        // Empty state tap also opens quick-add.
                        setOnClickPendingIntent(R.id.widget_empty, addIntent)
                    }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    companion object {
        private const val ACTION_TOGGLE_TASK =
            "com.seventyfive.hard.challenge.action.TOGGLE_TASK"

        /**
         * Redraws every placed widget: re-runs onUpdate for the header and
         * reloads the list rows. Called after quick-adds and toggles.
         */
        fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, DailyTasksWidgetProvider::class.java)
            )
            if (ids.isEmpty()) return

            manager.notifyAppWidgetViewDataChanged(ids, R.id.widget_task_list)

            val updateIntent =
                Intent(context, DailyTasksWidgetProvider::class.java).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                }
            context.sendBroadcast(updateIntent)
        }
    }
}
