import SwiftUI

struct HomeView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var games: [Game] = []

    private var shouldShowFinalsCountdown: Bool {
        EventConfig.finalsBettingClosingDate > Date()
    }

    private var upcomingGames: [Game] {
        games.filter { $0.isUpcoming }
            .sorted { $0.timestamp < $1.timestamp }
            .prefix(5)
            .map { $0 }
    }

    private var liveGames: [Game] {
        games.filter { $0.isLive }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private var recentResults: [Game] {
        games.filter { $0.isFinished }
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if shouldShowFinalsCountdown {
                        finalsCountdownCard
                            .padding(.horizontal, 16)
                    }

                    StatsBar(position: appVM.userPosition, points: appVM.userPoints)
                        .padding(.horizontal, 16)

                    // Live games
                    if !liveGames.isEmpty {
                        sectionView(title: "Trwające mecze", games: liveGames)
                    }

                    // Upcoming games
                    if !upcomingGames.isEmpty {
                        sectionView(title: "Nadchodzące mecze", games: upcomingGames)
                    }

                    // Recent results
                    if !recentResults.isEmpty {
                        sectionView(title: "Ostatnie wyniki", games: recentResults)
                    }
                }
                .padding(.vertical, 16)
            }
            .background(Color.terraBackground)
            .navigationTitle(EventConfig.currentEvent)
            .toolbarTitleDisplayMode(.large)
            .task {
                games = (try? await appVM.dataService.fetchGames()) ?? []
                await appVM.refreshUserStats()
            }
        }
    }

    private var finalsCountdownCard: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let countdown = countdownComponents(from: context.date, to: EventConfig.finalsBettingClosingDate)

            VStack(alignment: .leading, spacing: 14) {
                Text("Typy finalistów zamykają się za")
                    .font(.terraTitle(18))
                    .foregroundStyle(Color.terraTextPrimary)

                HStack(spacing: 10) {
                    countdownUnit(value: countdown.days, label: "dni")
                    countdownUnit(value: countdown.hours, label: "godz")
                    countdownUnit(value: countdown.minutes, label: "min")
                    countdownUnit(value: countdown.seconds, label: "sek")
                }

                Text("Termin: \(EventConfig.finalsBettingClosingDate.polishDateString), \(EventConfig.finalsBettingClosingDate.polishTimeString)")
                    .font(.terraCaption())
                    .foregroundStyle(Color.terraTextSecondary)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Color.terraPrimary.opacity(0.18), Color.terraCardFill],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }

    private func countdownUnit(value: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text(String(format: "%02d", max(0, value)))
                .font(.terraHeadline(24))
                .foregroundStyle(Color.terraTextPrimary)
                .monospacedDigit()
            Text(label)
                .font(.terraCaption(11))
                .foregroundStyle(Color.terraTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func countdownComponents(from now: Date, to target: Date) -> (days: Int, hours: Int, minutes: Int, seconds: Int) {
        let remainingSeconds = max(0, Int(target.timeIntervalSince(now)))
        let days = remainingSeconds / 86_400
        let hours = (remainingSeconds % 86_400) / 3_600
        let minutes = (remainingSeconds % 3_600) / 60
        let seconds = remainingSeconds % 60
        return (days, hours, minutes, seconds)
    }

    private func sectionView(title: String, games: [Game]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.terraTitle(18))
                .foregroundStyle(Color.terraTextPrimary)
                .padding(.horizontal, 16)

            LazyVStack(spacing: 12) {
                ForEach(games) { game in
                    MatchCard(game: game, showBetInfo: false)
                        .padding(.horizontal, 16)
                }
            }
        }
    }
}
