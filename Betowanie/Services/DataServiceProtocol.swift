import Foundation

protocol DataServiceProtocol {
    // MARK: - Games (Realtime Database: matches/)
    func fetchGames() async throws -> [Game]

    // MARK: - Teams (Realtime Database: teams/)
    func fetchTeams() async throws -> [Team]

    // MARK: - Bets (Firestore: bets/)
    func fetchBets(forUser userId: String) async throws -> [Bet]
    func fetchBets(forGame gameId: Int) async throws -> [Bet]
    func fetchAllBets() async throws -> [Bet]
    func placeBet(_ bet: Bet) async throws

    // MARK: - Finals Bets (Firestore: finals/)
    func fetchFinalsBet(forUser userId: String) async throws -> BetFinals?
    func fetchAllFinalsBets() async throws -> [BetFinals]
    func placeFinalsBet(_ bet: BetFinals) async throws

    // MARK: - Ranking (computed from bets + games)
    func fetchRanking() async throws -> [RankingEntry]
}
