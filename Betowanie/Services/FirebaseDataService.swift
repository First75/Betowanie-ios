import Foundation
import FirebaseDatabase
import FirebaseFirestore

/// Firebase implementation of DataServiceProtocol.
///
/// Data sources:
/// - Games: Realtime Database at `matches/`, ordered by `timestamp`
/// - Teams: Realtime Database at `teams/`
/// - Bets: Firestore collection `bets`, doc ID = `{userId}_{gameId}`
/// - Finals bets: Firestore collection `finals`, doc ID = `{userId}_finals`
/// - Ranking: Computed client-side from bets + games
@Observable
final class FirebaseDataService: DataServiceProtocol {
    private static let accurateFinalsTeamPoints = 3

    private let realtimeDb = Database.database(url: "https://betowanie-ee389.europe-west1.firebasedatabase.app").reference()
    private let firestoreDb = Firestore.firestore()

    // Local caches for ranking computation
    private var cachedGames: [Game] = []
    private var lastGamesFetch: Date?
    private let gamesCacheLifetime: TimeInterval = 5  // seconds

    // MARK: - Games (Realtime Database)

    func fetchGames() async throws -> [Game] {
        let snapshot = try await realtimeDb
            .child("matches")
            .queryOrdered(byChild: "timestamp")
            .getData()

        guard let value = snapshot.value else {
            print("[Firebase READ] matches/ -> nil snapshot")
            return []
        }

        let games = Self.parseSnapshotArray(value, as: Game.self)
        cachedGames = games
        lastGamesFetch = Date()
        print("[Firebase READ] matches/ -> \(games.count) games parsed")
        return games
    }

    // MARK: - Teams (Realtime Database)

    func fetchTeams() async throws -> [Team] {
        let snapshot = try await realtimeDb
            .child("teams")
            .getData()

        guard let value = snapshot.value else {
            print("[Firebase READ] teams/ -> nil snapshot")
            return []
        }

        let teams = Self.parseSnapshotArray(value, as: Team.self)
        print("[Firebase READ] teams/ -> \(teams.count) teams parsed")
        return teams
    }

    // MARK: - Bets (Firestore)

    func fetchBets(forUser userId: String) async throws -> [Bet] {
        let snapshot = try await firestoreDb
            .collection("bets")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        let bets = snapshot.documents.compactMap { doc in
            try? Self.decodeBet(from: doc.data())
        }
        print("[Firebase READ] bets/ where userId=\(userId) -> \(bets.count) bets parsed")
        return bets
    }

    func fetchBets(forGame gameId: Int) async throws -> [Bet] {
        let snapshot = try await firestoreDb
            .collection("bets")
            .whereField("gameId", isEqualTo: gameId)
            .getDocuments()

        let bets = snapshot.documents.compactMap { doc in
            try? Self.decodeBet(from: doc.data())
        }
        print("[Firebase READ] bets/ where gameId=\(gameId) -> \(bets.count) bets parsed")
        return bets
    }

    func fetchAllBets() async throws -> [Bet] {
        let snapshot = try await firestoreDb
            .collection("bets")
            .getDocuments()

        let bets = snapshot.documents.compactMap { doc in
            try? Self.decodeBet(from: doc.data())
        }
        print("[Firebase READ] bets/ (all) -> \(bets.count) bets parsed")
        return bets
    }

    func placeBet(_ bet: Bet) async throws {
        let docId = "\(bet.userId)_\(bet.gameId)"
        let data: [String: Any] = [
            "username": bet.username,
            "userId": bet.userId,
            "gameId": bet.gameId,
            "awayGoals": bet.awayGoals,
            "homeGoals": bet.homeGoals,
            "winner": bet.winner.rawValue,
            "gameStage": bet.gameStage.rawValue,
        ]
        try await firestoreDb
            .collection("bets")
            .document(docId)
            .setData(data)
        print("[Firebase WRITE] bets/\(docId) -> \(bet.homeGoals)-\(bet.awayGoals), winner: \(bet.winner.rawValue)")
    }

    // MARK: - Finals Bets (Firestore)

    func fetchFinalsBet(forUser userId: String) async throws -> BetFinals? {
        let docId = "\(userId)_finals"
        let doc = try await firestoreDb
            .collection("finals")
            .document(docId)
            .getDocument()

        guard doc.exists, let data = doc.data() else {
            print("[Firebase READ] finals/\(docId) -> not found")
            return nil
        }

        let finalsBet = try Self.decodeFinalsBet(from: data, docId: docId)
        print("[Firebase READ] finals/\(docId) -> teams: \(finalsBet.teamBet)")
        return finalsBet
    }

    func fetchAllFinalsBets() async throws -> [BetFinals] {
        let snapshot = try await firestoreDb
            .collection("finals")
            .getDocuments()

        let finalsBets = snapshot.documents.compactMap { doc in
            try? Self.decodeFinalsBet(from: doc.data(), docId: doc.documentID)
        }
        print("[Firebase READ] finals/ (all) -> \(finalsBets.count) finals bets parsed")
        return finalsBets
    }

    func placeFinalsBet(_ bet: BetFinals) async throws {
        let docId = "\(bet.userId)_finals"
        let data: [String: Any] = [
            "userId": bet.userId,
            "username": bet.username,
            "teamBet": bet.teamBet,
        ]
        try await firestoreDb
            .collection("finals")
            .document(docId)
            .setData(data)
        print("[Firebase WRITE] finals/\(docId) -> teams: \(bet.teamBet)")
    }

    // MARK: - Ranking (computed client-side)

    func fetchRanking() async throws -> [RankingEntry] {
        // Refresh games if cache is stale
        if cachedGames.isEmpty || lastGamesFetch == nil
            || Date().timeIntervalSince(lastGamesFetch!) > gamesCacheLifetime {
            cachedGames = try await fetchGames()
        }

        let allBets = try await fetchAllBets()
        let allFinalsBets = try await fetchAllFinalsBets()
        let finalGame = cachedGames.first(where: { $0.stage == .final_ })
        let settledGames = Dictionary(
            uniqueKeysWithValues: cachedGames.filter { $0.isFinished }.map { ($0.id, $0) }
        )

        var totals: [String: (username: String, points: Int, exactScores: Int, correctOutcomes: Int)] = [:]

        for bet in allBets {
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
        let ranking = totals
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

        print("[Firebase READ] ranking computed -> \(ranking.count) entries")
        return ranking
    }

    // MARK: - Helpers

    /// Parses a Realtime Database snapshot value that may be an Array or Dictionary
    /// into a typed Swift array, matching the JS pattern from the web app.
    private static func parseSnapshotArray<T: Decodable>(_ value: Any, as type: T.Type) -> [T] {
        let jsonData: Data
        do {
            jsonData = try JSONSerialization.data(withJSONObject: value)
        } catch {
            print("[Firebase ERROR] Failed to serialize snapshot: \(error)")
            return []
        }

        // Realtime Database may return an Array (with nulls for missing indices)
        // or a Dictionary. Both need to be converted to [T].
        if let array = value as? [Any] {
            // Filter nulls, then decode each element
            return array.compactMap { element in
                guard !(element is NSNull) else { return nil }
                guard let elementData = try? JSONSerialization.data(withJSONObject: element) else { return nil }
                return try? JSONDecoder().decode(T.self, from: elementData)
            }
        } else if let dict = value as? [String: Any] {
            return dict.values.compactMap { element in
                guard !(element is NSNull) else { return nil }
                guard let elementData = try? JSONSerialization.data(withJSONObject: element) else { return nil }
                return try? JSONDecoder().decode(T.self, from: elementData)
            }
        } else {
            // Try decoding the whole thing as [T]
            return (try? JSONDecoder().decode([T].self, from: jsonData)) ?? []
        }
    }

    /// Decodes a Firestore document dictionary into a Codable type
    private static func decode<T: Decodable>(_ type: T.Type, from dict: [String: Any]) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private static func decodeFinalsBet(from dict: [String: Any], docId: String) throws -> BetFinals {
        do {
            return try decode(BetFinals.self, from: dict)
        } catch {
            print("[Firebase ERROR] finals/\(docId) decode failed: \(describeDecodingError(error))")
            print("[Firebase ERROR] finals/\(docId) payload: \(dict)")
            throw error
        }
    }

    private static func describeDecodingError(_ error: Error) -> String {
        guard let decodingError = error as? DecodingError else {
            return error.localizedDescription
        }

        switch decodingError {
        case .keyNotFound(let key, let context):
            return "Missing key '\(key.stringValue)' at path \(codingPathString(context.codingPath)). \(context.debugDescription)"
        case .typeMismatch(let type, let context):
            return "Type mismatch for \(type) at path \(codingPathString(context.codingPath)). \(context.debugDescription)"
        case .valueNotFound(let type, let context):
            return "Value not found for \(type) at path \(codingPathString(context.codingPath)). \(context.debugDescription)"
        case .dataCorrupted(let context):
            return "Data corrupted at path \(codingPathString(context.codingPath)). \(context.debugDescription)"
        @unknown default:
            return "Unknown decoding error: \(decodingError)"
        }
    }

    private static func codingPathString(_ path: [CodingKey]) -> String {
        let joined = path.map(\.stringValue).joined(separator: ".")
        return joined.isEmpty ? "<root>" : joined
    }

    private static func finalsPoints(for bet: BetFinals, finalGame: Game) -> Int {
        let finalistNames = [finalGame.homeTeamName, finalGame.awayTeamName]
        let hits = bet.teamBet.filter { finalistNames.contains($0.teamName) }.count
        return hits * accurateFinalsTeamPoints
    }

    /// Decodes a Bet from Firestore, handling the special empty-winner case
    private static func decodeBet(from dict: [String: Any]) throws -> Bet {
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(Bet.self, from: data)
    }
}
