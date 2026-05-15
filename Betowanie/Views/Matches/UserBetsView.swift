import SwiftUI
import Charts

struct UserBetsView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss

    let userId: String
    let username: String

    @State private var viewModel: MyBetsViewModel?
    @State private var statsViewModel: UserStatsViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    ScrollView {
                        VStack(spacing: 16) {
                            UserProfileHeader(username: username)
                                .padding(.top, 8)

                            if let statsViewModel {
                                UserStatsCard(stats: statsViewModel.stats)
                                    .padding(.horizontal, 16)
                            }

                            // Points over time chart
                            if !buildPointsSamples(from: viewModel.filteredBets).isEmpty {
                                pointsChart(samples: buildPointsSamples(from: viewModel.filteredBets))
                                    .padding(.horizontal, 16)
                            }

                            // Bets list
                            if viewModel.filteredBets.isEmpty {
                                emptyStateView
                            } else {
                                LazyVStack(spacing: 8) {
                                    ForEach(viewModel.filteredBets, id: \.bet.id) { pair in
                                        userBetRow(bet: pair.bet, game: pair.game)
                                    }
                                }
                                .padding(12)
                                .terraCard()
                                .padding(.horizontal, 16)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                } else {
                    ProgressView()
                }
            }
            .background(Color.terraBackground)
            .navigationTitle(username)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zamknij") { dismiss() }
                }
            }
            .task {
                let vm = MyBetsViewModel(dataService: appVM.dataService, userId: userId)
                viewModel = vm
                vm.selectedFilter = .closed
                let statsVM = UserStatsViewModel(dataService: appVM.dataService, userId: userId)
                statsViewModel = statsVM
                async let bets: Void = vm.loadData()
                async let stats: Void = statsVM.load()
                _ = await (bets, stats)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 40))
                .foregroundStyle(Color.terraTextSecondary.opacity(0.5))
            Text("Brak zakładów")
                .font(.terraBody())
                .foregroundStyle(Color.terraTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
private struct PointsSample: Identifiable {
    let id = UUID()
    let date: Date
    let cumulative: Int
}

private func buildPointsSamples(from pairs: [(bet: Bet, game: Game)]) -> [PointsSample] {
    let finished = pairs.filter { $0.game.isFinished }
        .sorted { $0.game.timestamp < $1.game.timestamp }
    var total = 0
    var samples: [PointsSample] = []
    for pair in finished {
        total += pair.bet.finalPoints(against: pair.game)
        samples.append(PointsSample(date: pair.game.date, cumulative: total))
    }
    return samples
}

@ViewBuilder
private func pointsChart(samples: [PointsSample]) -> some View {
    VStack(alignment: .leading, spacing: 12) {
        Text("Punkty w czasie")
            .font(.terraTitle(18))
            .foregroundStyle(Color.terraTextPrimary)
        Chart(samples) {
            LineMark(
                x: .value("Data", $0.date),
                y: .value("Punkty", $0.cumulative)
            )
            .interpolationMethod(.monotone)
            PointMark(
                x: .value("Data", $0.date),
                y: .value("Punkty", $0.cumulative)
            )
            .symbolSize(20)
        }
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 3)) }
        .chartYAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
        .frame(height: 180)
    }
    .padding(16)
    .terraCard()
}

private func userBetRow(bet: Bet, game: Game) -> some View {
    let pts = bet.finalPoints(against: game)

    return HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(game.homeTeamName) vs \(game.awayTeamName)")
                .font(.terraBody())
                .foregroundStyle(Color.terraTextPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Text(game.isFinished || game.isLive ? game.displayScore : game.date.polishDateTimeString)
                .font(.terraCaption(12))
                .foregroundStyle(Color.terraTextSecondary)
        }

        Spacer()

        Text(bet.displayBet)
            .font(.terraBody())
            .foregroundStyle(Color.terraTextSecondary)
            .monospacedDigit()

        BetResultBadge(result: BetResultBadge.result(for: bet, game: game))

        Text("\(pts) pkt")
            .font(.terraLabel())
            .foregroundStyle(Color.terraTertiary)
            .frame(width: 50, alignment: .trailing)
    }
    .padding(.vertical, 10)
}

