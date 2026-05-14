import Foundation

struct PointsBreakdown {
    let points: Int
    let livePoints: Int
    let accurateScores: Int
    let liveAccurateScores: Int
    let winnerHit: Bool
    let scoreHit: Bool

    var bothHit: Bool { winnerHit && scoreHit }

    static let zero = PointsBreakdown(
        points: 0, livePoints: 0,
        accurateScores: 0, liveAccurateScores: 0,
        winnerHit: false, scoreHit: false
    )
}

struct Bet: Codable, Identifiable {
    let id: String
    let username: String
    let userId: String
    let gameId: Int
    let homeGoals: Int
    let awayGoals: Int
    let winner: WinnerResult
    let gameStage: GameStage

    var displayBet: String {
        "\(homeGoals) - \(awayGoals)"
    }

    /// Calculates points for this bet against a finished (or live) game.
    ///
    /// Scoring rules:
    /// - Correct winner: +1 pt
    /// - Correct exact score: +2 pts (independent of winner bet)
    /// - Stage multiplier applied (currently ×1 for all stages)
    /// - Uses regularTimeScore (extra time / penalties not counted)
    func points(against game: Game) -> PointsBreakdown {
        guard let score = game.regularTimeScore else {
            return .zero
        }

        let isFinished = game.isFinished
        let isLiveOrFinished = game.isFinished || game.isLive

        let winnerHit = winner == score.winner
        let homeHit = homeGoals == score.home
        let awayHit = awayGoals == score.away
        let scoreHit = homeHit && awayHit

        var pts = 0
        var livePts = 0
        var accurateScores = 0
        var liveAccurateScores = 0

        if winnerHit {
            pts += isFinished ? 1 : 0
            livePts += isLiveOrFinished ? 1 : 0
        }
        if scoreHit {
            pts += isFinished ? 2 : 0
            livePts += isLiveOrFinished ? 2 : 0
            accurateScores += isFinished ? 1 : 0
            liveAccurateScores += isLiveOrFinished ? 1 : 0
        }

        let multiplier = game.stage.pointMultiplier
        pts *= multiplier
        livePts *= multiplier

        return PointsBreakdown(
            points: pts,
            livePoints: livePts,
            accurateScores: accurateScores,
            liveAccurateScores: liveAccurateScores,
            winnerHit: winnerHit && isFinished,
            scoreHit: scoreHit && isFinished
        )
    }

    /// Convenience for getting just the final points
    func finalPoints(against game: Game) -> Int {
        points(against: game).points
    }

    /// Creates a new Bet with a generated ID
    init(username: String, userId: String, gameId: Int, homeGoals: Int, awayGoals: Int, winner: WinnerResult, gameStage: GameStage) {
        self.id = "\(userId)_\(gameId)"
        self.username = username
        self.userId = userId
        self.gameId = gameId
        self.homeGoals = homeGoals
        self.awayGoals = awayGoals
        self.winner = winner
        self.gameStage = gameStage
    }

    // Custom decoding: JSON has no "id" field, and "winner" can be ""
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        username = try container.decode(String.self, forKey: .username)
        userId = try container.decode(String.self, forKey: .userId)
        gameId = try container.decode(Int.self, forKey: .gameId)
        homeGoals = try container.decode(Int.self, forKey: .homeGoals)
        awayGoals = try container.decode(Int.self, forKey: .awayGoals)
        gameStage = try container.decode(GameStage.self, forKey: .gameStage)

        // Handle empty winner string: derive from goals
        let rawWinner = try container.decode(String.self, forKey: .winner)
        if let parsed = WinnerResult(rawValue: rawWinner) {
            winner = parsed
        } else {
            // Derive winner from goals when empty or invalid
            if homeGoals > awayGoals {
                winner = .homeTeam
            } else if awayGoals > homeGoals {
                winner = .awayTeam
            } else {
                winner = .draw
            }
        }

        // Generate id from userId + gameId since JSON doesn't include it
        id = "\(userId)_\(gameId)"
    }

    private enum CodingKeys: String, CodingKey {
        case username, userId, gameId, homeGoals, awayGoals, winner, gameStage
    }
}
