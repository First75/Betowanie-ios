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
        let settledGames = Dictionary(
            uniqueKeysWithValues: games.filter { $0.isFinished }.map { ($0.id, $0) }
        )

        var totals: [String: (username: String, points: Int, exactScores: Int, correctOutcomes: Int)] = [:]

        for bet in bets {
            guard let game = settledGames[bet.gameId] else { continue }
            let breakdown = bet.points(against: game)
            let existing = totals[bet.userId]

            totals[bet.userId] = (
                username: bet.username,
                points: (existing?.points ?? 0) + breakdown.points,
                exactScores: (existing?.exactScores ?? 0) + breakdown.accurateScores,
                correctOutcomes: (existing?.correctOutcomes ?? 0) + (breakdown.winnerHit ? 1 : 0)
            )
        }

        if let finalGame {
            for finalsBet in allFinalsBets {
                let existing = totals[finalsBet.userId]
                totals[finalsBet.userId] = (
                    username: existing?.username ?? finalsBet.username,
                    points: (existing?.points ?? 0) + Self.finalsPoints(for: finalsBet, finalGame: finalGame),
                    exactScores: existing?.exactScores ?? 0,
                    correctOutcomes: existing?.correctOutcomes ?? 0
                )
            }
        }

        // Sort by points descending, tiebreak by accurate scores descending (rule 7)
        return totals
            .sorted {
                if $0.value.points != $1.value.points {
                    return $0.value.points > $1.value.points
                }
                return $0.value.exactScores > $1.value.exactScores
            }
            .enumerated()
            .map { index, entry in
                RankingEntry(
                    id: entry.key,
                    username: entry.value.username,
                    totalPoints: entry.value.points,
                    position: index + 1,
                    correctScores: entry.value.exactScores,
                    correctOutcomes: entry.value.correctOutcomes
                )
            }
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
