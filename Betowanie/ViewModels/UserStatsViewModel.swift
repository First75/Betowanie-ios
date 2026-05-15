import Foundation

/// Loads bets, games, and ranking for a single user, and exposes computed
/// `UserStats`. Used by `ProfileView` for the logged-in user and by
/// `UserBetsView` when tapping another user from the ranking.
@Observable
final class UserStatsViewModel {
    var stats: UserStats = .empty
    var isLoading = false

    private let dataService: any DataServiceProtocol
    private let userId: String

    init(dataService: any DataServiceProtocol, userId: String) {
        self.dataService = dataService
        self.userId = userId
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        async let bets = dataService.fetchBets(forUser: userId)
        async let games = dataService.fetchGames()
        async let ranking = dataService.fetchRanking()

        let resolvedBets = (try? await bets) ?? []
        let resolvedGames = (try? await games) ?? []
        let entry = (try? await ranking)?.first(where: { $0.id == userId })

        stats = UserStats(
            userId: userId,
            bets: resolvedBets,
            games: resolvedGames,
            rankingEntry: entry
        )
    }
}
