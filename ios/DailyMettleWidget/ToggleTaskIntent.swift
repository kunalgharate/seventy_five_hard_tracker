import AppIntents
import WidgetKit

/// iOS 17+ interactive widget tap: flips the task in the shared snapshot
/// and journals the event for the app to replay into Hive — no app launch.
struct ToggleTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle task"
    static var description = IntentDescription(
        "Mark a daily task as done or pending."
    )

    @Parameter(title: "Task ID")
    var taskID: String

    init() {
        taskID = ""
    }

    init(taskID: String) {
        self.taskID = taskID
    }

    func perform() async throws -> some IntentResult {
        WidgetStore.toggleTask(taskID)
        WidgetCenter.shared.reloadTimelines(ofKind: "DailyMettleWidget")
        return .result()
    }
}
