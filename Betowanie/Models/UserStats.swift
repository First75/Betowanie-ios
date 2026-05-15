import Foundation

/// Aggregated, display-ready statistics for a single user. Computed from the
/// user's bets, the full game list, and the user's entry in the ranking.
struct UserStats {
    let position: Int
    let totalPoints: Int
    /// Total finished games in the competition (used as the denominator for
    /// points-per-game and to derive missed bets).
    let totalFinishedGames: Int
    /// Bets the user placed on already-finished games.
    let totalSettledBets: Int
    /// Bets where the exact score matched the final result.
    let perfectScores: Int
    /// Finished games where the user did not place a bet.
    let missedBets: Int

    /// Perfect scores / total settled bets, in 0...1.
    var accuracy: Double {
        totalSettledBets == 0 ? 0 : Double(perfectScores) / Double(totalSettledBets)
    }

    /// Points per finished game (counts missed games too — they pull the average down).
    var pointsPerGame: Double {
        totalFinishedGames == 0 ? 0 : Double(totalPoints) / Double(totalFinishedGames)
    }

    static let empty = UserStats(
        position: 0, totalPoints: 0, totalFinishedGames: 0,
        totalSettledBets: 0, perfectScores: 0, missedBets: 0
    )

    init(
        position: Int,
        totalPoints: Int,
        totalFinishedGames: Int,
        totalSettledBets: Int,
        perfectScores: Int,
        missedBets: Int
    ) {
        self.position = position
        self.totalPoints = totalPoints
        self.totalFinishedGames = totalFinishedGames
        self.totalSettledBets = totalSettledBets
        self.perfectScores = perfectScores
        self.missedBets = missedBets
    }

    init(userId: String, bets: [Bet], games: [Game], rankingEntry: RankingEntry?) {
        let finishedGames = games.filter { $0.isFinished }
        let finishedIds = Set(finishedGames.map { $0.id })
        let gameLookup = Dictionary(uniqueKeysWithValues: games.map { ($0.id, $0) })

        let settled: [(Bet, Game)] = bets.compactMap { bet in
            guard let game = gameLookup[bet.gameId], game.isFinished else { return nil }
            return (bet, game)
        }
        let perfect = settled.filter { $0.0.points(against: $0.1).scoreHit }.count
        let betGameIds = Set(bets.map { $0.gameId })
        let missed = finishedIds.subtracting(betGameIds).count

        self.init(
            position: rankingEntry?.position ?? 0,
            totalPoints: rankingEntry?.totalPoints ?? 0,
            totalFinishedGames: finishedGames.count,
            totalSettledBets: settled.count,
            perfectScores: perfect,
            missedBets: missed
        )
    }
}
