import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 2

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Strona główna", systemImage: "house.fill", value: 0) {
                HomeView()
            }

            Tab("Mecze", systemImage: "sportscourt.fill", value: 1) {
                MatchesView()
            }

            Tab("Moje zakłady", systemImage: "list.bullet.clipboard.fill", value: 2) {
                MyBetsView()
            }

            Tab("Ranking", systemImage: "trophy.fill", value: 3) {
                RankingView()
            }

            Tab("Profil", systemImage: "person.fill", value: 4) {
                ProfileView()
            }
        }
        .tint(.terraPrimary)
    }
}
