import SwiftUI
import SwiftData

@main
struct SnoreLessApp: App {
    // MARK: - SwiftData 컨테이너
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            SleepSession.self,
            SnoreEvent.self,
            DailyCheckIn.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("ModelContainer 생성 실패: \(error)")
        }
    }()

    // MARK: - WatchConnector (앱 수명주기 동안 유지)
    @StateObject private var watchConnector = WatchConnector()

    // MARK: - NotificationManager
    @StateObject private var notificationManager = NotificationManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(watchConnector)
                .environmentObject(notificationManager)
                .onAppear {
                    // WatchConnector에 ModelContext 주입
                    watchConnector.setModelContext(
                        sharedModelContainer.mainContext
                    )
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
