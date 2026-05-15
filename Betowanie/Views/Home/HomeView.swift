import SwiftUI

struct HomeView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var games: [Game] = []
    @State private var bets: [Bet] = []
    @State private var isShowingRules = false

    private var shouldShowCountdownCard: Bool {
        EventConfig.lastMatchStartDate > Date()
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
                    if shouldShowCountdownCard {
                        CountdownCard()
                            .padding(.horizontal, 16)
                    }

                    rulesCard
                        .padding(.horizontal, 16)

                    StatsBar(position: appVM.userPosition, points: appVM.userPoints)
                        .padding(.horizontal, 16)

                    // Live games
                    if !liveGames.isEmpty {
                        sectionView(title: "Trwające mecze", games: liveGames)
                    }

                    // Finals bet
                    if let user = appVM.currentUser {
                        FinalsBetCard(
                            userId: user.id,
                            username: user.username,
                            bettingClosesAt: EventConfig.finalsBettingClosingDate
                        )
                        .padding(.horizontal, 16)
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
            .profileAccessSheet()
            .refreshable {
                await refresh()
            }
            .task {
                await refresh()
            }
            .sheet(isPresented: $isShowingRules) {
                RulesSheet()
            }
        }
    }

    private var rulesCard: some View {
        Button {
            isShowingRules = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "book.closed")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.terraPrimary)
                    .frame(width: 40, height: 40)
                    .background(Color.terraPrimary.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Zasady")
                        .font(.terraTitle(18))
                        .foregroundStyle(Color.terraTextPrimary)
                    Text("Punktacja, nagrody i terminy")
                        .font(.terraCaption(12))
                        .foregroundStyle(Color.terraTextSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.terraTextSecondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.terraCardFill)
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    private func refresh() async {
        async let fetchedGames = appVM.dataService.fetchGames()
        async let stats: Void = appVM.refreshUserStats()
        games = (try? await fetchedGames) ?? []
        _ = await stats

        if let userId = appVM.currentUser?.id {
            bets = (try? await appVM.dataService.fetchBets(forUser: userId)) ?? []
        } else {
            bets = []
        }
    }

    private func bet(for gameId: Int) -> Bet? {
        bets.first { $0.gameId == gameId }
    }

    private func sectionView(title: String, games: [Game]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.terraTitle(18))
                .foregroundStyle(Color.terraTextPrimary)
                .padding(.horizontal, 16)

            LazyVStack(spacing: 12) {
                ForEach(games) { game in
                    MatchCard(game: game, bet: bet(for: game.id), showBetInfo: true)
                        .padding(.horizontal, 16)
                }
            }
        }
    }
}

// MARK: - Countdown Card

/// Live countdown shown on the home screen.
///
/// Two phases:
/// - Before `finalsBettingClosingDate`: counts down to tournament kick-off.
/// - Between kick-off and `lastMatchStartDate`: counts down to the final match.
struct CountdownCard: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let phase = Phase.current(at: context.date)
            let countdown = countdownComponents(from: context.date, to: phase.targetDate)

            VStack(alignment: .leading, spacing: 14) {
                phase.titleView

                HStack(spacing: 10) {
                    countdownUnit(value: countdown.days, label: "dni")
                    countdownUnit(value: countdown.hours, label: "godz")
                    countdownUnit(value: countdown.minutes, label: "min")
                    countdownUnit(value: countdown.seconds, label: "sek")
                }

                if let footer = phase.footerText {
                    Text(footer)
                        .font(.terraCaption())
                        .foregroundStyle(Color.terraTextSecondary)
                }
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

    private enum Phase {
        case beforeStart
        case duringTournament

        static func current(at date: Date) -> Phase {
            date < EventConfig.finalsBettingClosingDate ? .beforeStart : .duringTournament
        }

        var targetDate: Date {
            switch self {
            case .beforeStart: return EventConfig.finalsBettingClosingDate
            case .duringTournament: return EventConfig.lastMatchStartDate
            }
        }

        @ViewBuilder
        var titleView: some View {
            switch self {
            case .beforeStart:
                Text("Turniej rozpoczyna się za")
                    .font(.terraTitle(18))
                    .foregroundStyle(Color.terraTextPrimary)
            case .duringTournament:
                (Text("Czeka nas ")
                    .font(.terraTitle(18))
                    .foregroundColor(Color.terraTextPrimary)
                 + Text("jeszcze trochę")
                    .font(.terraTitle(18))
                    .foregroundColor(Color.terraPrimary)
                 + Text(" dobrej rywalizacji i zabawy")
                    .font(.terraTitle(18))
                    .foregroundColor(Color.terraTextPrimary))
                .fixedSize(horizontal: false, vertical: true)
            }
        }

        var footerText: String? {
            switch self {
            case .beforeStart:
                return "Termin: \(EventConfig.finalsBettingClosingDate.polishDateString), \(EventConfig.finalsBettingClosingDate.polishTimeString)"
            case .duringTournament:
                return "Do meczu finałowego: \(EventConfig.lastMatchStartDate.polishDateString), \(EventConfig.lastMatchStartDate.polishTimeString)"
            }
        }
    }
}

// MARK: - Rules Sheet

private struct RulesSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    scoringSection
                    prizesSection
                    otherRulesSection
                }
                .padding(16)
            }
            .background(Color.terraBackground)
            .navigationTitle("Zasady")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zamknij") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: Scoring

    private var scoringSection: some View {
        sectionContainer(title: "Punktacja", icon: "target") {
            VStack(spacing: 10) {
                scoreRow(
                    points: "+1",
                    title: "Trafiony zwycięzca",
                    subtitle: "Wytypujesz wynik 1, X lub 2."
                )
                scoreRow(
                    points: "+2",
                    title: "Dokładny wynik",
                    subtitle: "Trafisz dokładną liczbę bramek."
                )
                scoreRow(
                    points: "+3",
                    title: "Bonus finalisty",
                    subtitle: "Za każdego trafionego finalistę (maks. 6 pkt)."
                )
            }

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.terraTextSecondary)
                    .padding(.top, 2)
                Text("Dokładny wynik liczy się niezależnie od tego, na kogo obstawisz zwycięzcę.")
                    .font(.terraCaption(12))
                    .foregroundStyle(Color.terraTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 4)
        }
    }

    private func scoreRow(points: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Text(points)
                .font(.terraHeadline(20))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(Color.terraPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.terraLabel(15))
                    .foregroundStyle(Color.terraTextPrimary)
                Text(subtitle)
                    .font(.terraCaption(12))
                    .foregroundStyle(Color.terraTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: Prizes

    private var prizesSection: some View {
        sectionContainer(title: "Nagrody", icon: "trophy.fill") {
            HStack(spacing: 10) {
                prizeTile(medal: "🥇", percent: "60%", subtitle: "1. miejsce")
                prizeTile(medal: "🥈", percent: "25%", subtitle: "2. miejsce")
                prizeTile(medal: "🥉", percent: "15%", subtitle: "3. miejsce")
            }
            Text("Pula nagród pochodzi z wpisowego.")
                .font(.terraCaption(12))
                .foregroundStyle(Color.terraTextSecondary)
                .padding(.top, 4)
        }
    }

    private func prizeTile(medal: String, percent: String, subtitle: String) -> some View {
        VStack(spacing: 4) {
            Text(medal)
                .font(.system(size: 28))
            Text(percent)
                .font(.terraHeadline(20))
                .foregroundStyle(Color.terraTextPrimary)
            Text(subtitle)
                .font(.terraCaption(11))
                .foregroundStyle(Color.terraTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.terraBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: Other rules

    private var otherRulesSection: some View {
        sectionContainer(title: "Pozostałe zasady", icon: "list.bullet.rectangle") {
            VStack(spacing: 14) {
                iconRule(
                    icon: "stopwatch",
                    title: "Tylko czas regulaminowy",
                    text: "Mecze rozliczane są po regulaminowym czasie z doliczonym. Dogrywka i karne się nie liczą."
                )
                iconRule(
                    icon: "equal.circle",
                    title: "Remis w rankingu",
                    text: "Przy tej samej liczbie punktów decyduje większa liczba trafionych dokładnych wyników."
                )
                iconRule(
                    icon: "clock",
                    title: "Terminy zakładów",
                    text: "Bonus finalisty — przed startem turnieju. Zakłady meczowe — do planowego rozpoczęcia meczu."
                )
            }
        }
    }

    private func iconRule(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.terraPrimary)
                .frame(width: 36, height: 36)
                .background(Color.terraPrimary.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.terraLabel(14))
                    .foregroundStyle(Color.terraTextPrimary)
                Text(text)
                    .font(.terraBody(13))
                    .foregroundStyle(Color.terraTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: Section container

    @ViewBuilder
    private func sectionContainer<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.terraPrimary)
                Text(title)
                    .font(.terraTitle(18))
                    .foregroundStyle(Color.terraTextPrimary)
            }
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.terraCardFill)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
