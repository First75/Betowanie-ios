import SwiftUI

struct MatchCard: View {
    let game: Game
    var bet: Bet?
    var showBetInfo: Bool = true

    var body: some View {
        VStack(spacing: 12) {
            // Stage label
            Text(game.stage.displayName.uppercased())
                .font(.terraCaption(11))
                .foregroundStyle(Color.terraTextSecondary)
                .tracking(1)

            // Teams and score
            HStack(spacing: 0) {
                // Home team
                HStack(spacing: 8) {
                    TeamLogoView(urlString: game.homeTeamIcon, teamName: game.homeTeamName, size: 32)
                    Text(game.homeTeamName)
                        .font(.terraLabel(15))
                        .foregroundStyle(Color.terraTextPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Score
                if game.isFinished || game.isLive {
                    Text(game.displayScore)
                        .font(.terraTitle(22))
                        .foregroundStyle(game.isLive ? Color.terraError : Color.terraTextPrimary)
                        .monospacedDigit()
                        .padding(.horizontal, 12)
                } else {
                    Text(game.date.polishDateTimeString)
                        .font(.terraCaption(12))
                        .foregroundStyle(Color.terraTextSecondary)
                        .padding(.horizontal, 8)
                }

                // Away team
                HStack(spacing: 8) {
                    Text(game.awayTeamName)
                        .font(.terraLabel(15))
                        .foregroundStyle(Color.terraTextPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    TeamLogoView(urlString: game.awayTeamIcon, teamName: game.awayTeamName, size: 32)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            // Bet info
            if showBetInfo {
                Divider()
                    .background(Color.terraTextSecondary.opacity(0.2))

                if let bet {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Wynik: \(bet.displayBet)")
                                .font(.terraCaption())
                                .foregroundStyle(Color.terraTextSecondary)
                            Text("Zwycięzca: \(bet.winner.displayName(homeTeamName: game.homeTeamName, awayTeamName: game.awayTeamName))")
                                .font(.terraCaption(11))
                                .foregroundStyle(Color.terraTextSecondary.opacity(0.8))
                        }

                        Spacer()

                        if game.isFinished || game.isLive {
                            BetResultBadge(result: BetResultBadge.result(for: bet, game: game))
                        }
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.terraTextSecondary.opacity(0.7))
                        Text(game.isFinished ? "Nie obstawiono tego meczu" : "Nie obstawiono jeszcze tego meczu")
                            .font(.terraCaption())
                            .foregroundStyle(Color.terraTextSecondary)
                        Spacer()
                    }
                }
            }
        }
        .terraCard()
    }
}
