import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        if hasCompletedOnboarding {
            mainTabView
                .preferredColorScheme(.dark)
        } else {
            OnboardingView()
        }
    }

    private var mainTabView: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label(String(localized: "홈"), systemImage: "house.fill")
                }

            HistoryView()
                .tabItem {
                    Label(String(localized: "기록"), systemImage: "clock.fill")
                }

            SettingsView()
                .tabItem {
                    Label(String(localized: "설정"), systemImage: "gearshape.fill")
                }
        }
        .tint(.cyan)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [SleepSession.self, SnoreEvent.self, DailyCheckIn.self], inMemory: true)
        .environmentObject(WatchConnector())
}
