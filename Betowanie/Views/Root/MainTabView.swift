import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Strona główna", systemImage: "house.fill", value: 0) {
                HomeView()
            }

            Tab("Mecze", systemImage: "sportscourt.fill", value: 1) {
                MatchesView()
            }

            Tab("Ranking", systemImage: "trophy.fill", value: 2) {
                RankingView()
            }
        }
        .tint(.terraPrimary)
    }
}
