import Foundation




@Observable
final class DummyDataService: DataServiceProtocol {
    private static let accurateFinalsTeamPoints = 3
    
  

    private var games: [Game] = []
    private var bets: [Bet] = []
    private var finalsBets: [BetFinals] = []

    init() {
        games = Self.decodeJSON(from: RawData.dummyGamesData) ?? []
        bets = Self.decodeJSON(from: RawData.dummyBetsData) ?? []
        
        print("Loaded \(games.count) gaems and \(bets.count) bets")
    }

    func fetchGames() async throws -> [Game] {
        games.sorted { $0.timestamp > $1.timestamp }
    }

    func fetchBets(forUser userId: String) async throws -> [Bet] {
        bets.filter { $0.userId == userId }
    }

    func fetchBets(forGame gameId: Int) async throws -> [Bet] {
        bets.filter { $0.gameId == gameId }
    }

    func fetchAllBets() async throws -> [Bet] {
        bets
    }

    func placeBet(_ bet: Bet) async throws {
        bets.removeAll { $0.userId == bet.userId && $0.gameId == bet.gameId }
        bets.append(bet)
    }

    // MARK: - Teams

    func fetchTeams() async throws -> [Team] {
        // No dummy teams data — return empty for now
        []
    }

    // MARK: - Finals Bets

    func fetchFinalsBet(forUser userId: String) async throws -> BetFinals? {
        finalsBets.first { $0.userId == userId }
    }

    func fetchAllFinalsBets() async throws -> [BetFinals] {
        finalsBets
    }

    func placeFinalsBet(_ bet: BetFinals) async throws {
        finalsBets.removeAll { $0.userId == bet.userId }
        finalsBets.append(bet)
    }

    // MARK: - Ranking

    func fetchRanking() async throws -> [RankingEntry] {
        let allFinalsBets = finalsBets
        let finalGame = games.first(where: { $0.stage == .final_ })
        // Include live matches so their in-play scores count toward the live ranking.
        let scoringGames = Dictionary(
            uniqueKeysWithValues: games.filter { $0.isFinished || $0.isLive }.map { ($0.id, $0) }
        )

        var totals: [String: DummyUserTotals] = [:]

        for bet in bets {
            guard let game = scoringGames[bet.gameId] else { continue }
            let breakdown = bet.points(against: game)
            var existing = totals[bet.userId] ?? DummyUserTotals(username: bet.username)
            existing.points += breakdown.points
            existing.exactScores += breakdown.accurateScores
            existing.correctOutcomes += breakdown.winnerHit ? 1 : 0
            existing.livePoints += breakdown.livePoints
            existing.liveExactScores += breakdown.liveAccurateScores
            totals[bet.userId] = existing
        }

        if let finalGame {
            for finalsBet in allFinalsBets {
                var existing = totals[finalsBet.userId] ?? DummyUserTotals(username: finalsBet.username)
                let pts = Self.finalsPoints(for: finalsBet, finalGame: finalGame)
                existing.points += pts
                existing.livePoints += pts
                totals[finalsBet.userId] = existing
            }
        }

        let basePositions = Self.dummyAssignPositions(totals: totals, useLiveValues: false)
        return Self.dummyBuildRanking(totals: totals, basePositions: basePositions)
    }

    private struct DummyUserTotals {
        let username: String
        var points: Int = 0
        var exactScores: Int = 0
        var correctOutcomes: Int = 0
        var livePoints: Int = 0
        var liveExactScores: Int = 0
    }

    private static func dummyAssignPositions(totals: [String: DummyUserTotals], useLiveValues: Bool) -> [String: Int] {
        let sorted = totals.sorted { lhs, rhs in
            let lPoints = useLiveValues ? lhs.value.livePoints : lhs.value.points
            let rPoints = useLiveValues ? rhs.value.livePoints : rhs.value.points
            if lPoints != rPoints { return lPoints > rPoints }
            let lExact = useLiveValues ? lhs.value.liveExactScores : lhs.value.exactScores
            let rExact = useLiveValues ? rhs.value.liveExactScores : rhs.value.exactScores
            if lExact != rExact { return lExact > rExact }
            return lhs.value.username.localizedCaseInsensitiveCompare(rhs.value.username) == .orderedAscending
        }

        var positions: [String: Int] = [:]
        var lastPoints: Int?
        var lastExact: Int?
        var lastPosition = 0
        for (index, entry) in sorted.enumerated() {
            let pts = useLiveValues ? entry.value.livePoints : entry.value.points
            let exact = useLiveValues ? entry.value.liveExactScores : entry.value.exactScores
            let position: Int
            if pts == lastPoints && exact == lastExact {
                position = lastPosition
            } else {
                position = index + 1
                lastPosition = position
                lastPoints = pts
                lastExact = exact
            }
            positions[entry.key] = position
        }
        return positions
    }

    private static func dummyBuildRanking(totals: [String: DummyUserTotals], basePositions: [String: Int]) -> [RankingEntry] {
        let sortedLive = totals.sorted { lhs, rhs in
            if lhs.value.livePoints != rhs.value.livePoints {
                return lhs.value.livePoints > rhs.value.livePoints
            }
            if lhs.value.liveExactScores != rhs.value.liveExactScores {
                return lhs.value.liveExactScores > rhs.value.liveExactScores
            }
            return lhs.value.username.localizedCaseInsensitiveCompare(rhs.value.username) == .orderedAscending
        }

        var ranking: [RankingEntry] = []
        var lastPoints: Int?
        var lastExact: Int?
        var lastPosition = 0
        for (index, entry) in sortedLive.enumerated() {
            let livePosition: Int
            if entry.value.livePoints == lastPoints && entry.value.liveExactScores == lastExact {
                livePosition = lastPosition
            } else {
                livePosition = index + 1
                lastPosition = livePosition
                lastPoints = entry.value.livePoints
                lastExact = entry.value.liveExactScores
            }
            let basePosition = basePositions[entry.key] ?? livePosition
            ranking.append(
                RankingEntry(
                    id: entry.key,
                    username: entry.value.username,
                    totalPoints: entry.value.livePoints,
                    position: livePosition,
                    correctScores: entry.value.liveExactScores,
                    correctOutcomes: entry.value.correctOutcomes,
                    positionChange: basePosition - livePosition
                )
            )
        }
        return ranking
    }

    private static func decodeJSON<T: Decodable>(from jsonString: String) -> T? {
        guard let data = jsonString.data(using: .utf8) else {
            print("❌ Failed to convert JSON string to Data")
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(T.self, from: data)
            return decoded
        } catch {
            print("❌ JSON Decoding Error: \(error)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("   Missing key '\(key.stringValue)' at path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                case .typeMismatch(let type, let context):
                    print("   Type mismatch for type '\(type)' at path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    print("   Debug: \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    print("   Value not found for type '\(type)' at path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                case .dataCorrupted(let context):
                    print("   Data corrupted at path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    print("   Debug: \(context.debugDescription)")
                @unknown default:
                    print("   Unknown decoding error")
                }
            }
            return nil
        }
    }
    
    private static func loadJSON<T: Decodable>(_ filename: String) -> T? {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private static func finalsPoints(for bet: BetFinals, finalGame: Game) -> Int {
        let finalistNames = [finalGame.homeTeamName, finalGame.awayTeamName]
        let hits = bet.teamBet.filter { finalistNames.contains($0.teamName) }.count
        return hits * accurateFinalsTeamPoints
    }
}
