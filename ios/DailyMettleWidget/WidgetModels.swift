import Foundation
import WidgetKit

/// Mirrors lib/core/services/widget_bridge_service.dart — the app publishes
/// this snapshot into the App Group store via home_widget.
struct WidgetTask: Identifiable {
    let id: String
    let title: String
    var completed: Bool
    var pending: Bool
}

enum WidgetStore {
    /// Must match the App Group in Runner.entitlements,
    /// DailyMettleWidget.entitlements and WidgetBridgeService.appGroupId.
    static let appGroup = "group.com.seventyfive.hard.challenge"

    static let tasksKey = "widget_tasks"
    static let toggleEventsKey = "widget_toggle_events"

    static var addTaskURL: URL {
        URL(string: "dailymettle://add-task?homeWidget")!
    }

    static var openTasksURL: URL {
        URL(string: "dailymettle://tasks?homeWidget")!
    }

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroup)
    }

    static func tasks() -> [WidgetTask] {
        guard let raw = defaults?.string(forKey: tasksKey),
              let data = raw.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data)
                as? [[String: Any]]
        else { return [] }

        return array.compactMap { item in
            guard let id = item["id"] as? String,
                  let title = item["title"] as? String,
                  !id.isEmpty, !title.isEmpty
            else { return nil }
            return WidgetTask(
                id: id,
                title: title,
                completed: item["completed"] as? Bool ?? false,
                pending: item["pending"] as? Bool ?? false
            )
        }
    }

    /// Flips a task's completed flag in the display snapshot and journals
    /// the toggle so the app can replay it into Hive on next launch.
    static func toggleTask(_ taskId: String) {
        guard let defaults else { return }

        var completedNow = true
        if let raw = defaults.string(forKey: tasksKey),
           let data = raw.data(using: .utf8),
           var array = try? JSONSerialization.jsonObject(with: data)
                as? [[String: Any]] {
            for i in array.indices where array[i]["id"] as? String == taskId {
                let was = array[i]["completed"] as? Bool ?? false
                array[i]["completed"] = !was
                completedNow = !was
            }
            if let encoded = try? JSONSerialization.data(
                withJSONObject: array),
               let json = String(data: encoded, encoding: .utf8) {
                defaults.set(json, forKey: tasksKey)
            }
        }

        var events: [[String: Any]] = []
        if let raw = defaults.string(forKey: toggleEventsKey),
           let data = raw.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data)
                as? [[String: Any]] {
            events = parsed
        }
        events.removeAll { $0["taskId"] as? String == taskId }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        events.append([
            "taskId": taskId,
            "completed": completedNow,
            "date": formatter.string(from: Date()),
        ])
        if let encoded = try? JSONSerialization.data(withJSONObject: events),
           let json = String(data: encoded, encoding: .utf8) {
            defaults.set(json, forKey: toggleEventsKey)
        }
    }
}
