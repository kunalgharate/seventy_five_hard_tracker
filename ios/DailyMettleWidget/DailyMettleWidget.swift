import SwiftUI
import WidgetKit

@main
struct DailyMettleWidgetBundle: WidgetBundle {
    var body: some Widget {
        DailyTasksWidget()
    }
}

struct DailyTasksEntry: TimelineEntry {
    let date: Date
    let tasks: [WidgetTask]
}

struct DailyTasksTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyTasksEntry {
        DailyTasksEntry(date: Date(), tasks: Self.sample)
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (DailyTasksEntry) -> Void
    ) {
        completion(DailyTasksEntry(date: Date(), tasks: WidgetStore.tasks()))
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<DailyTasksEntry>) -> Void
    ) {
        let entry = DailyTasksEntry(
            date: Date(), tasks: WidgetStore.tasks())
        // Refresh at midnight so the day label rolls over; every change
        // triggers an explicit reload anyway.
        let midnight = Calendar.current.startOfDay(
            for: Date().addingTimeInterval(86_400))
        completion(
            Timeline(entries: [entry], policy: .after(midnight)))
    }

    private static let sample = [
        WidgetTask(id: "1", title: "Drink 3L water",
                   completed: true, pending: false),
        WidgetTask(id: "2", title: "45-min workout",
                   completed: false, pending: false),
        WidgetTask(id: "3", title: "Read 10 pages",
                   completed: false, pending: false),
    ]
}

struct DailyTasksWidget: Widget {
    let kind = "DailyMettleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyTasksTimelineProvider()) {
            entry in
            if #available(iOSApplicationExtension 17.0, *) {
                DailyTasksWidgetView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                DailyTasksWidgetView(entry: entry)
                    .padding(8)
            }
        }
        .configurationDisplayName("Daily Tasks")
        .description(
            "Check off today's tasks or add a new one."
        )
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
