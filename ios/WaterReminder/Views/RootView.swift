import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack { TodayView() }
                .tabItem { Label("喝水", systemImage: "drop.fill") }

            NavigationStack { StatsView() }
                .tabItem { Label("统计", systemImage: "chart.bar.fill") }

            NavigationStack { SettingsView() }
                .tabItem { Label("设置", systemImage: "gearshape.fill") }
        }
    }
}

#Preview {
    RootView().environmentObject(DrinkStore.shared)
}
