package com.example.seventy_five_hard_tracker.widget

import android.app.Activity
import android.app.TimePickerDialog
import android.os.Bundle
import android.text.format.DateFormat
import android.view.View
import android.view.WindowManager
import android.widget.AdapterView
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.Spinner
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
 * and, when a reminder is configured, schedules native alarms so they fire
 * even if the app is never opened.
 *
 * The reminder options mirror the app's reminder bottom sheet: Once,
 * Multiple Times, Every Hour, Every X Hours, and Custom Schedule — encoded
 * into the same reminderTime string format the app understands.
 */
class QuickAddTaskActivity : Activity() {

    /** Interval options matching the app's reminder sheet (15 min - 12 h). */
    private val intervalMinutes =
        intArrayOf(15, 30, 60, 120, 180, 240, 360, 480, 720)
    private val intervalLabels = arrayOf(
        "15 min", "30 min", "1 hour", "2 hours", "3 hours",
        "4 hours", "6 hours", "8 hours", "12 hours",
    )
    private val typeLabels = arrayOf(
        "Once", "Multiple Times", "Every Hour", "Every X Hours",
        "Custom Schedule",
    )

    private var reminderHour: Int? = null
    private var reminderMinute: Int? = null
    private val customTimes = mutableListOf<Pair<Int, Int>>()

    private lateinit var titleInput: EditText
    private lateinit var reminderSwitch: Switch
    private lateinit var typeRow: LinearLayout
    private lateinit var typeSpinner: Spinner
    private lateinit var singleTimeRow: LinearLayout
    private lateinit var timeLabel: TextView
    private lateinit var reminderTimeText: TextView
    private lateinit var intervalRow: LinearLayout
    private lateinit var intervalSpinner: Spinner
    private lateinit var timesContainer: LinearLayout
    private lateinit var timesList: LinearLayout
    private lateinit var addTimeButton: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_quick_add_task)
        window.setLayout(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
        )

        titleInput = findViewById(R.id.quick_add_title)
        reminderSwitch = findViewById(R.id.quick_add_reminder_switch)
        typeRow = findViewById(R.id.quick_add_type_row)
        typeSpinner = findViewById(R.id.quick_add_type)
        singleTimeRow = findViewById(R.id.quick_add_single_time_row)
        timeLabel = findViewById(R.id.quick_add_time_label)
        reminderTimeText = findViewById(R.id.quick_add_time)
        intervalRow = findViewById(R.id.quick_add_interval_row)
        intervalSpinner = findViewById(R.id.quick_add_interval)
        timesContainer = findViewById(R.id.quick_add_times_container)
        timesList = findViewById(R.id.quick_add_times_list)
        addTimeButton = findViewById(R.id.quick_add_add_time)

        typeSpinner.adapter = ArrayAdapter(
            this,
            android.R.layout.simple_spinner_item,
            typeLabels,
        ).apply {
            setDropDownViewResource(
                android.R.layout.simple_spinner_dropdown_item)
        }
        intervalSpinner.adapter = ArrayAdapter(
            this,
            android.R.layout.simple_spinner_item,
            intervalLabels,
        ).apply {
            setDropDownViewResource(
                android.R.layout.simple_spinner_dropdown_item)
        }
        intervalSpinner.setSelection(3) // 2 hours — same default as the app

        typeSpinner.onItemSelectedListener =
            object : AdapterView.OnItemSelectedListener {
                override fun onItemSelected(
                    parent: AdapterView<*>?, view: View?, pos: Int, id: Long,
                ) = updateReminderUi()

                override fun onNothingSelected(parent: AdapterView<*>?) {}
            }

        findViewById<Button>(R.id.quick_add_cancel).setOnClickListener {
            finish()
        }
        findViewById<Button>(R.id.quick_add_save).setOnClickListener {
            save()
        }
        singleTimeRow.setOnClickListener {
            if (reminderSwitch.isChecked) showTimePicker()
        }
        addTimeButton.setOnClickListener { showAddTimePicker() }
        reminderSwitch.setOnCheckedChangeListener { _, isChecked ->
            if (isChecked && reminderHour == null) {
                // Default the picker to the next round hour.
                val cal = Calendar.getInstance()
                cal.add(Calendar.HOUR_OF_DAY, 1)
                cal.set(Calendar.MINUTE, 0)
                reminderHour = cal.get(Calendar.HOUR_OF_DAY)
                reminderMinute = 0
            }
            updateReminderUi()
        }

        updateReminderUi()
        titleInput.requestFocus()
        window.setSoftInputMode(
            WindowManager.LayoutParams.SOFT_INPUT_STATE_VISIBLE
        )
    }

    private fun reminderType(): String = when (typeSpinner.selectedItemPosition) {
        1 -> "multiple"
        2 -> "hourly"
        3 -> "interval"
        4 -> "custom"
        else -> "once"
    }

    private fun updateReminderUi() {
        val on = reminderSwitch.isChecked
        val type = reminderType()
        typeRow.visibility = if (on) View.VISIBLE else View.GONE

        val needsSingleTime = on &&
            (type == "once" || type == "hourly" || type == "interval")
        singleTimeRow.visibility =
            if (needsSingleTime) View.VISIBLE else View.GONE
        timeLabel.setText(
            if (type == "once") R.string.widget_reminder_time
            else R.string.widget_start_time
        )

        intervalRow.visibility =
            if (on && type == "interval") View.VISIBLE else View.GONE
        timesContainer.visibility =
            if (on && (type == "multiple" || type == "custom"))
                View.VISIBLE
            else View.GONE

        updateTimeText()
        renderTimesList()
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

    private fun showAddTimePicker() {
        val now = Calendar.getInstance()
        TimePickerDialog(
            this,
            { _, hour, minute ->
                if (!customTimes.contains(Pair(hour, minute))) {
                    customTimes.add(Pair(hour, minute))
                    customTimes.sortBy { it.first * 60 + it.second }
                    renderTimesList()
                }
            },
            now.get(Calendar.HOUR_OF_DAY),
            now.get(Calendar.MINUTE),
            DateFormat.is24HourFormat(this),
        ).show()
    }

    private fun renderTimesList() {
        timesList.removeAllViews()
        for (time in customTimes) {
            val row = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
            }
            val label = TextView(this).apply {
                layoutParams = LinearLayout.LayoutParams(
                    0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f
                )
                text = formatTime(time.first, time.second)
                textSize = 15f
                setTextColor(0xFF1F1B16.toInt())
            }
            val remove = TextView(this).apply {
                text = getString(R.string.widget_remove)
                setTextColor(0xFFFF5449.toInt())
                textSize = 13f
                setOnClickListener {
                    customTimes.remove(time)
                    renderTimesList()
                }
            }
            row.addView(label)
            row.addView(remove)
            timesList.addView(row)
        }
    }

    private fun formatTime(hour: Int, minute: Int): String {
        val cal = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
        }
        val pattern =
            if (DateFormat.is24HourFormat(this)) "HH:mm" else "h:mm a"
        return SimpleDateFormat(pattern, Locale.getDefault())
            .format(Date(cal.timeInMillis))
    }

    private fun updateTimeText() {
        val hour = reminderHour
        val minute = reminderMinute
        reminderTimeText.text = if (hour == null || minute == null) {
            getString(R.string.widget_pick_time)
        } else {
            formatTime(hour, minute)
        }
    }

    /** Encodes the reminder config exactly like the app's reminder sheet. */
    private fun encodeReminder(): String? {
        if (!reminderSwitch.isChecked) return null
        val h = reminderHour
        val m = reminderMinute ?: 0
        val hhmm = if (h != null) String.format(Locale.US, "%02d:%02d", h, m) else null
        return when (reminderType()) {
            "once" -> hhmm?.let { "once:$it" }
            "hourly" -> hhmm?.let { "hourly:$it" }
            "interval" -> hhmm?.let {
                val interval =
                    intervalMinutes[intervalSpinner.selectedItemPosition]
                "interval:$interval:$it"
            }
            "multiple" -> customTimes
                .takeIf { it.isNotEmpty() }
                ?.joinToString(",", prefix = "multiple:") {
                    String.format(Locale.US, "%02d:%02d", it.first, it.second)
                }
            "custom" -> customTimes
                .takeIf { it.isNotEmpty() }
                ?.joinToString(",", prefix = "custom:") {
                    String.format(Locale.US, "%02d:%02d", it.first, it.second)
                }
            else -> null
        }
    }

    private fun save() {
        val title = titleInput.text.toString().trim()
        if (title.isEmpty()) {
            titleInput.error = getString(R.string.widget_title_required)
            return
        }
        if (reminderSwitch.isChecked) {
            val type = reminderType()
            val needsSingleTime =
                type == "once" || type == "hourly" || type == "interval"
            if (needsSingleTime && reminderHour == null) {
                Toast.makeText(
                    this,
                    getString(R.string.widget_pick_time),
                    Toast.LENGTH_SHORT,
                ).show()
                return
            }
            if (type == "multiple" && customTimes.size < 2) {
                Toast.makeText(
                    this,
                    getString(R.string.widget_two_times_required),
                    Toast.LENGTH_SHORT,
                ).show()
                return
            }
            if (type == "custom" && customTimes.isEmpty()) {
                Toast.makeText(
                    this,
                    getString(R.string.widget_times_required),
                    Toast.LENGTH_SHORT,
                ).show()
                return
            }
        }

        val id = "w${System.currentTimeMillis()}"
        val reminderTime = encodeReminder()

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

        // Native alarms — fire even if the app is never opened.
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
