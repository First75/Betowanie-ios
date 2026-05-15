import Foundation

struct RankingEntry: Identifiable {
    let id: String
    let username: String
    let totalPoints: Int
    let position: Int
    let correctScores: Int
    let correctOutcomes: Int
    /// Positions gained (positive) or lost (negative) due to currently in-play / paused
    /// matches, compared to the standings using only finished matches. 0 when no live
    /// match is affecting this user's ranking.
    let positionChange: Int
}
