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
            "teamBet": bet.teamBet.map {
                [
                    "teamId": $0.teamId,
                    "teamName": $0.teamName,
                ]
            },
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

        let activeUsers = try await fetchActiveUsers()
        let allBets = try await fetchAllBets()
        let allFinalsBets = try await fetchAllFinalsBets()
        let finalGame = cachedGames.first(where: { $0.stage == .final_ })
        // Include live matches so their in-play scores count toward the live ranking.
        let scoringGames = Dictionary(
            uniqueKeysWithValues: cachedGames
                .filter { $0.isFinished || $0.isLive }
                .map { ($0.id, $0) }
        )

        var totals: [String: UserTotals] = [:]

        // Seed every active user so accounts with 0 points still appear in the ranking.
        for user in activeUsers {
            totals[user.id] = UserTotals(username: user.username)
        }

        for bet in allBets {
            // Skip bets from inactive/unknown users so the ranking only shows active accounts.
            guard var existing = totals[bet.userId] else { continue }
            guard let game = scoringGames[bet.gameId] else { continue }
            let breakdown = bet.points(against: game)

            existing.points += breakdown.points
            existing.exactScores += breakdown.accurateScores
            existing.correctOutcomes += breakdown.winnerHit ? 1 : 0
            existing.livePoints += breakdown.livePoints
            existing.liveExactScores += breakdown.liveAccurateScores
            totals[bet.userId] = existing
        }

        if let finalGame {
            for finalsBet in allFinalsBets {
                guard var existing = totals[finalsBet.userId] else { continue }
                let pts = Self.finalsPoints(for: finalsBet, finalGame: finalGame)
                existing.points += pts
                existing.livePoints += pts
                totals[finalsBet.userId] = existing
            }
        }

        // Base positions: standings using only finished-match points (live matches ignored).
        let basePositions = Self.assignPositions(totals: totals, useLiveValues: false)
        // Live positions: include in-play / paused match results in the standings.
        let ranking = Self.buildRanking(totals: totals, basePositions: basePositions)

        print("[Firebase READ] ranking computed -> \(ranking.count) entries")
        return ranking
    }

    /// Per-user totals tracked while computing the ranking. Mirrors both the finished-only
    /// values (used for the pre-live "base" positions) and the live values (used for the
    /// currently displayed standings).
    private struct UserTotals {
        let username: String
        var points: Int = 0
        var exactScores: Int = 0
        var correctOutcomes: Int = 0
        var livePoints: Int = 0
        var liveExactScores: Int = 0
    }

    /// Sorts `totals` and assigns competition-style positions (1,1,1,4,...). Pass
    /// `useLiveValues = true` to rank by live points / live exact scores; otherwise
    /// uses finished-only points / exact scores.
    private static func assignPositions(totals: [String: UserTotals], useLiveValues: Bool) -> [String: Int] {
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

    /// Builds the ordered ranking using live points/exact scores for display and the
    /// supplied base positions to compute each user's `positionChange`.
    private static func buildRanking(totals: [String: UserTotals], basePositions: [String: Int]) -> [RankingEntry] {
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

    /// Fetches active users from Firestore `users/` so the ranking can include
    /// every approved account, including those who haven't placed any bets yet.
    private func fetchActiveUsers() async throws -> [(id: String, username: String)] {
        let snapshot = try await firestoreDb
            .collection("users")
            .whereField("isActive", isEqualTo: true)
            .getDocuments()

        let users: [(id: String, username: String)] = snapshot.documents.compactMap { doc in
            let data = doc.data()
            let username = (data["username"] as? String) ?? "Użytkownik"
            return (id: doc.documentID, username: username)
        }
        print("[Firebase READ] users/ where isActive=true -> \(users.count) users parsed")
        return users
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
