import SwiftUI

struct MatchDetailView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss
    let game: Game

    @State private var homeGoals: Int = 0
    @State private var awayGoals: Int = 0
    @State private var selectedWinner: WinnerResult = .draw
    @State private var existingBet: Bet?
    @State private var otherBets: [Bet] = []
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Match header
                    matchHeader

                    if game.isFinished {
                        finishedContent
                    } else {
                        betPlacementContent
                    }
                }
                .padding(16)
            }
            .background(Color.terraBackground)
            .navigationTitle(game.stage.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zamknij") { dismiss() }
                }
            }
            .task {
                await loadData()
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Match Header

    private var matchHeader: some View {
        VStack(spacing: 16) {
            Text(game.stage.displayName.uppercased())
                .font(.terraCaption(11))
                .foregroundStyle(Color.terraTextSecondary)
                .tracking(1)

            HStack(spacing: 0) {
                VStack(spacing: 8) {
                    TeamLogoView(urlString: game.homeTeamIcon, teamName: game.homeTeamName, size: 48)
                    Text(game.homeTeamName)
                        .font(.terraLabel())
                        .foregroundStyle(Color.terraTextPrimary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 4) {
                    if game.isFinished || game.isLive {
                        Text(game.displayScore)
                            .font(.terraHeadline(28))
                            .foregroundStyle(game.isLive ? Color.terraError : Color.terraTextPrimary)
                    } else {
                        Text("vs")
                            .font(.terraTitle())
                            .foregroundStyle(Color.terraTextSecondary)
                    }
                    Text(game.date.polishDateTimeString)
                        .font(.terraCaption(11))
                        .foregroundStyle(Color.terraTextSecondary)
                }
                .frame(width: 100)

                VStack(spacing: 8) {
                    TeamLogoView(urlString: game.awayTeamIcon, teamName: game.awayTeamName, size: 48)
                    Text(game.awayTeamName)
                        .font(.terraLabel())
                        .foregroundStyle(Color.terraTextPrimary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .terraCard()
    }

    // MARK: - Bet Placement

    private var betPlacementContent: some View {
        VStack(spacing: 20) {
            Text(existingBet != nil ? "Zmień zakład" : "Obstaw wynik")
                .font(.terraTitle())
                .foregroundStyle(Color.terraTextPrimary)

            // Score stepper
            HStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text(game.homeTeamName)
                        .font(.terraCaption())
                        .foregroundStyle(Color.terraTextSecondary)
                    Stepper(value: $homeGoals, in: 0...20) {
                        Text("\(homeGoals)")
                            .font(.terraHeadline(32))
                            .foregroundStyle(Color.terraTextPrimary)
                            .monospacedDigit()
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity)

                Text(":")
                    .font(.terraHeadline(32))
                    .foregroundStyle(Color.terraTextSecondary)

                VStack(spacing: 8) {
                    Text(game.awayTeamName)
                        .font(.terraCaption())
                        .foregroundStyle(Color.terraTextSecondary)
                    Stepper(value: $awayGoals, in: 0...20) {
                        Text("\(awayGoals)")
                            .font(.terraHeadline(32))
                            .foregroundStyle(Color.terraTextPrimary)
                            .monospacedDigit()
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 8)

            // Winner picker (independent of score)
            VStack(spacing: 8) {
                Text("Zwycięzca")
                    .font(.terraCaption())
                    .foregroundStyle(Color.terraTextSecondary)

                HStack(spacing: 8) {
                    winnerButton(.homeTeam, label: game.homeTeamName)
                    winnerButton(.draw, label: "Remis")
                    winnerButton(.awayTeam, label: game.awayTeamName)
                }
            }

            TerraButton(
                title: existingBet != nil ? "Zmień zakład" : "Zatwierdź zakład",
                isLoading: isSaving
            ) {
                saveBet()
            }
        }
        .terraCard()
    }

    private func winnerButton(_ winner: WinnerResult, label: String) -> some View {
        let isSelected = selectedWinner == winner
        return Button {
            selectedWinner = winner
        } label: {
            Text(label)
                .font(.terraCaption(13))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(isSelected ? Color.terraPrimary : Color.terraCardFill)
                .foregroundStyle(isSelected ? .white : Color.terraTextPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? Color.terraPrimary : Color.terraTextSecondary.opacity(0.2), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Finished Content

    private var finishedContent: some View {
        VStack(spacing: 16) {
            Text("Zakłady graczy")
                .font(.terraTitle())
                .foregroundStyle(Color.terraTextPrimary)

            if otherBets.isEmpty {
                Text("Brak zakładów dla tego meczu")
                    .font(.terraBody())
                    .foregroundStyle(Color.terraTextSecondary)
                    .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(otherBets) { bet in
                        betRow(bet)
                    }
                }
            }
        }
        .terraCard()
    }

    private func betRow(_ bet: Bet) -> some View {
        let isCurrentUser = bet.userId == appVM.currentUser?.id
        let pts = bet.finalPoints(against: game)

        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(bet.username)
                    .font(.terraLabel())
                    .foregroundStyle(isCurrentUser ? Color.terraPrimary : Color.terraTextPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(bet.winner.displayName(homeTeamName: game.homeTeamName, awayTeamName: game.awayTeamName))
                    .font(.terraCaption(11))
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
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isCurrentUser ? Color.terraPrimary.opacity(0.05) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Actions

    private func loadData() async {
        if let userId = appVM.currentUser?.id {
            let userBets = (try? await appVM.dataService.fetchBets(forUser: userId)) ?? []
            existingBet = userBets.first { $0.gameId == game.id }
            if let existing = existingBet {
                homeGoals = existing.homeGoals
                awayGoals = existing.awayGoals
                selectedWinner = existing.winner
            }
        }
        otherBets = (try? await appVM.dataService.fetchBets(forGame: game.id)) ?? []
    }

    private func saveBet() {
        guard let user = appVM.currentUser else { return }
        isSaving = true

        let bet = Bet(
            username: user.username,
            userId: user.id,
            gameId: game.id,
            homeGoals: homeGoals,
            awayGoals: awayGoals,
            winner: selectedWinner,
            gameStage: game.stage
        )

        Task {
            do {
                try await appVM.dataService.placeBet(bet)
                await MainActor.run {
                    existingBet = bet
                    isSaving = false
                    Toast.shared.show("Postawiono zakład", style: .positive)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    Toast.shared.show("Nie udało się zapisać zakładu", style: .negative)
                }
            }
        }
    }
}
