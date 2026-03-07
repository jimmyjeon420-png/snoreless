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
            // Migration failed — delete corrupt store and retry before falling back to in-memory
            print("[SnoreLessApp] ModelContainer 생성 실패 (migration?): \(error)")

            // Attempt to delete the default store file so a fresh DB is created
            let storeURL = modelConfiguration.url
            let storePaths = [
                storeURL,
                storeURL.appendingPathExtension("shm"),
                storeURL.appendingPathExtension("wal")
            ]
            for path in storePaths {
                try? FileManager.default.removeItem(at: path)
            }
            print("[SnoreLessApp] 기존 DB 삭제 후 재시도")
            if let retryContainer = try? ModelContainer(for: schema, configurations: [modelConfiguration]) {
                return retryContainer
            }

            // Last resort: in-memory fallback (data lost but no crash)
            print("[SnoreLessApp] 재시도 실패, 인메모리 fallback")
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [fallback])
            } catch {
                fatalError("인메모리 ModelContainer도 실패 — 복구 불가: \(error)")
            }
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
