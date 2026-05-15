import SwiftUI

enum BetResult {
    case exactScoreAndWinner  // Score + winner both correct
    case exactScore           // Only score correct
    case correctOutcome       // Only winner correct
    case wrong
    case pending

    var label: String {
        switch self {
        case .exactScoreAndWinner: return "Perfekcyjny!"
        case .exactScore: return "Dokładny!"
        case .correctOutcome: return "Trafiony"
        case .wrong: return "Pudło"
        case .pending: return "Oczekuje"
        }
    }

    var color: Color {
        switch self {
        case .exactScoreAndWinner: return Color.terraTertiary
        case .exactScore: return Color.terraPrimary
        case .correctOutcome: return Color.terraPrimary.opacity(0.7)
        case .wrong: return Color.terraError
        case .pending: return Color.terraTextSecondary
        }
    }

    var icon: String {
        switch self {
        case .exactScoreAndWinner: return "star.fill"
        case .exactScore: return "checkmark.seal.fill"
        case .correctOutcome: return "checkmark.circle.fill"
        case .wrong: return "xmark.circle.fill"
        case .pending: return "clock.fill"
        }
    }
}

struct BetResultBadge: View {
    let result: BetResult

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: result.icon)
                .font(.system(size: 11))
            Text(result.label)
                .font(.terraCaption(11))
                .lineLimit(1)
        }
        .foregroundStyle(result.color)
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(result.color.opacity(0.1))
        .clipShape(Capsule())
    }

    static func result(for bet: Bet, game: Game) -> BetResult {
        guard game.isFinished || game.isLive else { return .pending }
        guard let score = game.regularTimeScore else { return .pending }

        let winnerHit = bet.winner == score.winner
        let scoreHit = bet.homeGoals == score.home && bet.awayGoals == score.away

        switch (winnerHit, scoreHit) {
        case (true, true): return .exactScoreAndWinner
        case (false, true): return .exactScore
        case (true, false): return .correctOutcome
        case (false, false): return .wrong
        }
    }
}
