package com.example.seventy_five_hard_tracker.widget

import android.app.Activity
import android.app.TimePickerDialog
import android.os.Bundle
import android.text.format.DateFormat
import android.view.WindowManager
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.Switch
import android.widget.TextView
import android.widget.Toast
import com.example.seventy_five_hard_tracker.R
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/**
 * Floating dialog launched from the widget's "+" button. Saves the task into
 * the shared pending queue (the app materializes it into Hive on next open)
 * and, when a reminder time is picked, schedules a native alarm so it fires
 * even if the app is never opened.
 */
class QuickAddTaskActivity : Activity() {

    private var reminderHour: Int? = null
    private var reminderMinute: Int? = null

    private lateinit var titleInput: EditText
    private lateinit var reminderSwitch: Switch
    private lateinit var reminderTimeText: TextView
    private lateinit var reminderRow: LinearLayout

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_quick_add_task)
        window.setLayout(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
        )

        titleInput = findViewById(R.id.quick_add_title)
        reminderSwitch = findViewById(R.id.quick_add_reminder_switch)
        reminderTimeText = findViewById(R.id.quick_add_time)
        reminderRow = findViewById(R.id.quick_add_reminder_row)

        findViewById<Button>(R.id.quick_add_cancel).setOnClickListener {
            finish()
        }
        findViewById<Button>(R.id.quick_add_save).setOnClickListener {
            save()
        }
        reminderRow.setOnClickListener {
            if (reminderSwitch.isChecked) showTimePicker()
        }
        reminderSwitch.setOnCheckedChangeListener { _, isChecked ->
            if (isChecked && reminderHour == null) {
                // Default the picker to the next round hour.
                val cal = Calendar.getInstance()
                cal.add(Calendar.HOUR_OF_DAY, 1)
                cal.set(Calendar.MINUTE, 0)
                reminderHour = cal.get(Calendar.HOUR_OF_DAY)
                reminderMinute = 0
                updateTimeText()
            }
            reminderTimeText.isEnabled = isChecked
            reminderTimeText.alpha = if (isChecked) 1f else 0.4f
        }

        updateTimeText()
        titleInput.requestFocus()
        window.setSoftInputMode(
            WindowManager.LayoutParams.SOFT_INPUT_STATE_VISIBLE
        )
    }

    private fun showTimePicker() {
        val now = Calendar.getInstance()
        TimePickerDialog(
            this,
            { _, hour, minute ->
                reminderHour = hour
                reminderMinute = minute
                updateTimeText()
            },
            reminderHour ?: now.get(Calendar.HOUR_OF_DAY),
            reminderMinute ?: now.get(Calendar.MINUTE),
            DateFormat.is24HourFormat(this),
        ).show()
    }

    private fun updateTimeText() {
        val hour = reminderHour
        val minute = reminderMinute
        reminderTimeText.text = if (hour == null || minute == null) {
            getString(R.string.widget_pick_time)
        } else {
            val cal = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, hour)
                set(Calendar.MINUTE, minute)
            }
            val pattern =
                if (DateFormat.is24HourFormat(this)) "HH:mm" else "h:mm a"
            SimpleDateFormat(pattern, Locale.getDefault()).format(
                Date(cal.timeInMillis)
            )
        }
        reminderTimeText.isEnabled = reminderSwitch.isChecked
        reminderTimeText.alpha = if (reminderSwitch.isChecked) 1f else 0.4f
    }

    private fun save() {
        val title = titleInput.text.toString().trim()
        if (title.isEmpty()) {
            titleInput.error = getString(R.string.widget_title_required)
            return
        }

        val id = "w${System.currentTimeMillis()}"
        val reminderOn =
            reminderSwitch.isChecked && reminderHour != null
        val reminderTime = if (reminderOn) {
            "once:%02d:%02d".format(reminderHour, reminderMinute ?: 0)
        } else {
            null
        }

        val task = WidgetStore.PendingTask(
            id = id,
            title = title,
            reminderTime = reminderTime,
            completed = false,
            createdAt = SimpleDateFormat(
                "yyyy-MM-dd'T'HH:mm:ss", Locale.US
            ).format(Date()),
            alarmRequestCode = (id.hashCode() and 0x7FFFFFFF),
        )

        // Queue for the app to drain into Hive on next open.
        WidgetStore.setPendingTasks(
            this,
            WidgetStore.getPendingTasks(this) + task,
        )
        // Show it in the widget immediately.
        WidgetStore.appendDisplayTask(
            this,
            WidgetStore.WidgetTask(
                id = task.id,
                title = task.title,
                completed = false,
                pending = true,
            ),
        )

        // Native alarm — fires even if the app is never opened.
        if (reminderTime != null) {
            WidgetAlarmScheduler.schedule(this, task)
        }

        DailyTasksWidgetProvider.refresh(this)
        Toast.makeText(
            this,
            getString(R.string.widget_task_saved),
            Toast.LENGTH_SHORT,
        ).show()
        finish()
    }
}
