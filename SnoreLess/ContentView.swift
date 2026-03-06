import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("홈", systemImage: "house.fill")
                }

            HistoryView()
                .tabItem {
                    Label("기록", systemImage: "clock.fill")
                }

            SettingsView()
                .tabItem {
                    Label("설정", systemImage: "gearshape.fill")
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [SleepSession.self, SnoreEvent.self, DailyCheckIn.self], inMemory: true)
        .environmentObject(WatchConnector())
}
