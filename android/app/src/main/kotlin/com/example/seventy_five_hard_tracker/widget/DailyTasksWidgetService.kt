package com.example.seventy_five_hard_tracker.widget

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import com.example.seventy_five_hard_tracker.R

/**
 * Backs the widget's task ListView. Rows are rebuilt from the shared store
 * on every [notifyAppWidgetViewDataChanged].
 */
class DailyTasksWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        DailyTasksFactory(applicationContext)
}

private class DailyTasksFactory(
    private val context: Context,
) : RemoteViewsService.RemoteViewsFactory {

    private var tasks: List<WidgetStore.WidgetTask> = emptyList()

    override fun onCreate() {}

    override fun onDataSetChanged() {
        tasks = WidgetStore.getTasks(context)
    }

    override fun onDestroy() {
        tasks = emptyList()
    }

    override fun getCount(): Int = tasks.size

    override fun getViewAt(position: Int): RemoteViews {
        val task = tasks[position]
        return RemoteViews(context.packageName, R.layout.widget_task_item)
            .apply {
                setTextViewText(R.id.widget_task_title, task.title)
                setTextColor(
                    R.id.widget_task_title,
                    if (task.completed) DONE_COLOR else TITLE_COLOR,
                )
                setImageViewResource(
                    R.id.widget_task_check,
                    if (task.completed) {
                        R.drawable.ic_widget_check_done
                    } else {
                        R.drawable.ic_widget_check
                    },
                )
                // Merged into the pending-intent template: the receiver sees
                // "dailymettle://toggle/<taskId>" and routes it to Dart.
                val fillIn = Intent().apply {
                    data = Uri.parse("dailymettle://toggle/${task.id}")
                }
                setOnClickFillInIntent(R.id.widget_task_row, fillIn)
            }
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long =
        tasks[position].id.hashCode().toLong()

    override fun hasStableIds(): Boolean = true

    companion object {
        private val TITLE_COLOR = Color.parseColor("#1F1B16")
        private val DONE_COLOR = Color.parseColor("#9E968E")
    }
}
