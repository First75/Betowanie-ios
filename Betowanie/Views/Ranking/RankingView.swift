import SwiftUI

struct RankingView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var viewModel: RankingViewModel?

    @State private var selectedUser: SelectedUser?

    private struct SelectedUser: Identifiable {
        let id: String
        let username: String
    }

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            if viewModel.ranking.isEmpty && !viewModel.isLoading {
                                emptyStateView
                            } else {
                                ForEach(viewModel.ranking) { entry in
                                    rankingRow(entry)
                                }
                            }
                        }
                        .padding(16)
                    }
                    .refreshable {
                        async let reload: Void = viewModel.loadRanking()
                        async let stats: Void = appVM.refreshUserStats()
                        _ = await (reload, stats)
                    }
                } else {
                    ProgressView()
                }
            }
            .background(Color.terraBackground)
            .navigationTitle("Ranking")
            .profileAccessSheet()
            .sheet(item: $selectedUser, content: { user in
                UserBetsView(userId: user.id, username: user.username)
                    .presentationDetents([.large])
            })
            .task {
                let vm = RankingViewModel(dataService: appVM.dataService)
                viewModel = vm
                await vm.loadRanking()
            }
        }
    }

    private func rankingRow(_ entry: RankingEntry) -> some View {
        let isCurrentUser = entry.id == appVM.currentUser?.id

        return HStack(spacing: 16) {
            // Position + live position-change indicator
            VStack(spacing: 4) {
                positionBadge(entry.position)
                if entry.positionChange != 0 {
                    positionChangeLabel(entry.positionChange)
                }
            }

            // User info
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.username)
                    .font(.terraLabel())
                    .foregroundStyle(isCurrentUser ? Color.terraPrimary : Color.terraTextPrimary)
                Text("Dok.: \(entry.correctScores) | Wynik: \(entry.correctOutcomes)")
                    .font(.terraCaption(11))
                    .foregroundStyle(Color.terraTextSecondary)
            }

            Spacer()

            // Points
            Text("\(entry.totalPoints)")
                .font(.terraTitle(20))
                .foregroundStyle(Color.terraTertiary)
            Text("pkt")
                .font(.terraCaption(11))
                .foregroundStyle(Color.terraTextSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(isCurrentUser ? Color.terraPrimary.opacity(0.08) : Color.terraCardFill)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            selectedUser = SelectedUser(id: entry.id, username: entry.username)
        }
    }

    private func positionBadge(_ position: Int) -> some View {
        ZStack {
            Circle()
                .fill(positionColor(position))
                .frame(width: 36, height: 36)
            Text("\(position)")
                .font(.terraLabel())
                .foregroundStyle(.white)
        }
    }

    /// Small green/red label showing how many positions the user has gained or lost
    /// due to currently in-play matches.
    private func positionChangeLabel(_ change: Int) -> some View {
        let isPositive = change > 0
        let magnitude = abs(change)
        let color: Color = isPositive ? Color.terraSuccess : Color.terraError
        return HStack(spacing: 2) {
            Image(systemName: isPositive ? "arrow.up" : "arrow.down")
                .font(.system(size: 8, weight: .bold))
            Text("\(magnitude)")
                .font(.terraCaption(10))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }

    private func positionColor(_ position: Int) -> Color {
        switch position {
        case 1: return Color(red: 212/255, green: 175/255, blue: 55/255)   // Gold
        case 2: return Color(red: 167/255, green: 167/255, blue: 173/255)  // Silver
        case 3: return Color(red: 176/255, green: 141/255, blue: 87/255)   // Bronze
        default: return Color.terraTextSecondary.opacity(0.5)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "trophy")
                .font(.system(size: 40))
                .foregroundStyle(Color.terraTextSecondary.opacity(0.5))
            Text("Ranking jest pusty")
                .font(.terraBody())
                .foregroundStyle(Color.terraTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
