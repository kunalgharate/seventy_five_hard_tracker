package com.example.seventy_five_hard_tracker.widget

import android.content.Context
import android.content.SharedPreferences
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import org.json.JSONArray
import org.json.JSONObject

/**
 * Reads and writes the shared store used by the home_widget plugin
 * ("HomeWidgetPreferences"). Keys must stay in sync with
 * lib/core/services/widget_bridge_service.dart and the iOS widget extension.
 */
object WidgetStore {
    const val PREFS = "HomeWidgetPreferences"

    const val KEY_TASKS = "widget_tasks"
    const val KEY_PENDING_TASKS = "widget_pending_tasks"
    const val KEY_TOGGLE_EVENTS = "widget_toggle_events"

    fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    data class WidgetTask(
        val id: String,
        val title: String,
        val completed: Boolean,
        val pending: Boolean,
    )

    /**
     * Encoded reminder format shared with the app's reminder_bottom_sheet:
     * "once:HH:mm", "multiple:HH:mm,HH:mm,...", "hourly:HH:mm",
     * "interval:MINUTES:HH:mm", "custom:HH:mm,...", or legacy "HH:mm".
     */
    data class PendingTask(
        val id: String,
        val title: String,
        val reminderTime: String?,
        val completed: Boolean,
        val createdAt: String,
        val alarmRequestCode: Int,
        val reminderStartHour: Int = 8,
        val reminderEndHour: Int = 22,
        val allowNightReminders: Boolean = true,
    ) {
        fun reminderType(): String = when {
            reminderTime == null -> "none"
            reminderTime.startsWith("multiple:") -> "multiple"
            reminderTime.startsWith("hourly:") -> "hourly"
            reminderTime.startsWith("interval:") -> "interval"
            reminderTime.startsWith("custom:") -> "custom"
            else -> "once" // "once:HH:mm" or legacy "HH:mm"
        }

        fun reminderHourMinute(): Pair<Int, Int>? {
            val raw = reminderTime ?: return null
            val time = if (raw.startsWith("once:")) raw.substring(5) else raw
            return parseHHmm(time)
        }

        /** All explicit times for multiple:/custom: schedules (single-time
         * schedules return a one-element list). */
        fun reminderTimes(): List<Pair<Int, Int>> {
            val raw = reminderTime ?: return emptyList()
            val timesRaw = when {
                raw.startsWith("multiple:") -> raw.substring(9)
                raw.startsWith("custom:") -> raw.substring(7)
                else -> return reminderHourMinute()?.let { listOf(it) }
                    ?: emptyList()
            }
            return timesRaw.split(",").mapNotNull(::parseHHmm)
        }

        /** hourly:HH:mm / interval:MINUTES:HH:mm → the schedule start time. */
        fun reminderStartTime(): Pair<Int, Int>? {
            val raw = reminderTime ?: return null
            return when {
                raw.startsWith("hourly:") -> parseHHmm(raw.substring(7))
                raw.startsWith("interval:") -> {
                    val parts = raw.substring(9).split(":")
                    if (parts.size >= 3) parseHHmm("${parts[1]}:${parts[2]}")
                    else null
                }
                else -> null
            }
        }

        fun intervalMinutes(): Int? {
            val raw = reminderTime ?: return null
            if (!raw.startsWith("interval:")) return null
            return raw.substring(9).split(":").firstOrNull()?.toIntOrNull()
        }

        private fun parseHHmm(raw: String): Pair<Int, Int>? {
            val parts = raw.split(":")
            if (parts.size < 2) return null
            val h = parts[0].toIntOrNull() ?: return null
            val m = parts[1].toIntOrNull() ?: return null
            return Pair(h, m)
        }
    }

    // ── Display snapshot ──────────────────────────────────────────────

    fun getTasks(context: Context): List<WidgetTask> {
        val out = mutableListOf<WidgetTask>()
        forEach(context, KEY_TASKS) { item ->
            val id = item.optString("id")
            val title = item.optString("title")
            if (id.isNotEmpty() && title.isNotEmpty()) {
                out.add(
                    WidgetTask(
                        id = id,
                        title = title,
                        completed = item.optBoolean("completed"),
                        pending = item.optBoolean("pending"),
                    )
                )
            }
        }
        return out
    }

    fun setTasks(context: Context, tasks: List<WidgetTask>) {
        val array = JSONArray()
        for (task in tasks) {
            array.put(
                JSONObject()
                    .put("id", task.id)
                    .put("title", task.title)
                    .put("completed", task.completed)
                    .put("pending", task.pending)
            )
        }
        prefs(context).edit().putString(KEY_TASKS, array.toString()).apply()
    }

    fun appendDisplayTask(context: Context, task: WidgetTask) {
        setTasks(context, getTasks(context) + task)
    }

    // ── Pending quick-adds (drained into Hive by the app) ────────────

    fun getPendingTasks(context: Context): List<PendingTask> {
        val out = mutableListOf<PendingTask>()
        forEach(context, KEY_PENDING_TASKS) { item ->
            val id = item.optString("id")
            val title = item.optString("title")
            if (id.isNotEmpty() && title.isNotEmpty()) {
                out.add(
                    PendingTask(
                        id = id,
                        title = title,
                        reminderTime = item.optString("reminderTime")
                            .takeIf { it.isNotEmpty() && it != "null" },
                        completed = item.optBoolean("completed"),
                        createdAt = item.optString("createdAt"),
                        alarmRequestCode = item.optInt("alarmRequestCode"),
                        reminderStartHour = item.optInt("reminderStartHour", 8),
                        reminderEndHour = item.optInt("reminderEndHour", 22),
                        allowNightReminders =
                            item.optBoolean("allowNightReminders", true),
                    )
                )
            }
        }
        return out
    }

    fun setPendingTasks(context: Context, tasks: List<PendingTask>) {
        val array = JSONArray()
        for (task in tasks) {
            array.put(
                JSONObject()
                    .put("id", task.id)
                    .put("title", task.title)
                    .put("reminderTime", task.reminderTime ?: JSONObject.NULL)
                    .put("completed", task.completed)
                    .put("createdAt", task.createdAt)
                    .put("alarmRequestCode", task.alarmRequestCode)
                    .put("reminderStartHour", task.reminderStartHour)
                    .put("reminderEndHour", task.reminderEndHour)
                    .put("allowNightReminders", task.allowNightReminders)
            )
        }
        prefs(context).edit()
            .putString(KEY_PENDING_TASKS, array.toString())
            .apply()
    }

    fun findPendingTask(context: Context, taskId: String): PendingTask? =
        getPendingTasks(context).firstOrNull { it.id == taskId }

    // ── Toggle journaling ────────────────────────────────────────────

    /**
     * Flips [taskId]'s completed flag in the display snapshot, mirrors it
     * into pending quick-adds, and journals the event for the app to replay
     * into Hive on the next drain. Mirrors the Dart-side toggle logic in
     * widget_bridge_service.dart — last write per task wins.
     */
    fun toggleTask(context: Context, taskId: String): Boolean {
        var completed = true

        val tasks = getTasks(context).toMutableList()
        var displayTouched = false
        for (i in tasks.indices) {
            if (tasks[i].id == taskId) {
                completed = !tasks[i].completed
                tasks[i] = tasks[i].copy(completed = completed)
                displayTouched = true
            }
        }
        if (displayTouched) setTasks(context, tasks)

        val pending = getPendingTasks(context).toMutableList()
        var pendingTouched = false
        for (i in pending.indices) {
            if (pending[i].id == taskId) {
                pending[i] = pending[i].copy(completed = completed)
                pendingTouched = true
            }
        }
        if (pendingTouched) setPendingTasks(context, pending)

        val kept = JSONArray()
        try {
            val events =
                JSONArray(prefs(context).getString(KEY_TOGGLE_EVENTS, null) ?: "[]")
            for (i in 0 until events.length()) {
                val event = events.optJSONObject(i) ?: continue
                if (event.optString("taskId") != taskId) kept.put(event)
            }
        } catch (_: Exception) {
        }
        kept.put(
            JSONObject()
                .put("taskId", taskId)
                .put("completed", completed)
                .put(
                    "date",
                    SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date()),
                )
        )
        prefs(context).edit()
            .putString(KEY_TOGGLE_EVENTS, kept.toString())
            .apply()

        return completed
    }

    private inline fun forEach(
        context: Context,
        key: String,
        block: (JSONObject) -> Unit,
    ) {
        val raw = prefs(context).getString(key, null) ?: return
        try {
            val array = JSONArray(raw)
            for (i in 0 until array.length()) {
                array.optJSONObject(i)?.let(block)
            }
        } catch (_: Exception) {
        }
    }
}
