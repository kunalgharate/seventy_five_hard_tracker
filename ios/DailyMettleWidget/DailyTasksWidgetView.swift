import SwiftUI
import WidgetKit

struct DailyTasksWidgetView: View {
    let entry: DailyTasksEntry
    @Environment(\.widgetFamily) private var family

    fileprivate static let orange =
        Color(red: 1.0, green: 0.475, blue: 0.094)

    private var remaining: Int {
        entry.tasks.filter { !$0.completed }.count
    }

    private var maxRows: Int {
        switch family {
        case .systemSmall: return 2
        case .systemMedium: return 4
        default: return 7
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            if entry.tasks.isEmpty {
                Spacer()
                emptyState
                Spacer()
            } else {
                taskRows
                if entry.tasks.count > maxRows {
                    Text("+\(entry.tasks.count - maxRows) more")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(WidgetStore.openTasksURL)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.date, format: .dateTime.weekday(.wide).day().month())
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Self.orange)
                Text(entry.tasks.isEmpty
                     ? "No tasks today"
                     : "\(remaining) remaining")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Link(destination: WidgetStore.addTaskURL) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Self.orange)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("No tasks yet")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
            Link(destination: WidgetStore.addTaskURL) {
                Label("Add a daily task", systemImage: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Self.orange, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var taskRows: some View {
        ForEach(entry.tasks.prefix(maxRows)) { task in
            TaskRow(task: task)
        }
    }
}

private struct TaskRow: View {
    let task: WidgetTask

    var body: some View {
        if #available(iOSApplicationExtension 17.0, *) {
            Button(intent: ToggleTaskIntent(taskID: task.id)) {
                rowContent
            }
            .buttonStyle(.plain)
        } else {
            // iOS 16: rows fall through to the widget's widgetURL and open
            // the app on the tasks tab.
            rowContent
        }
    }

    private var rowContent: some View {
        HStack(spacing: 8) {
            Image(
                systemName: task.completed
                    ? "checkmark.circle.fill" : "circle"
            )
            .font(.system(size: 18))
            .foregroundStyle(
                task.completed
                    ? DailyTasksWidgetView.orange : Color.secondary)
            Text(task.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(
                    task.completed ? Color.secondary : Color.primary
                )
                .strikethrough(task.completed, color: .secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }
}
