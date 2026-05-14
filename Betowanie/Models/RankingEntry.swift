import Foundation

struct RankingEntry: Identifiable {
    let id: String
    let username: String
    let totalPoints: Int
    let position: Int
    let correctScores: Int
    let correctOutcomes: Int
}
