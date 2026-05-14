import SwiftUI

@Observable
final class MatchesViewModel {
    enum Filter: String, CaseIterable {
        case upcoming = "Nadchodzące"
        case live = "Trwające"
        case finished = "Zakończone"
    }

    var games: [Game] = []
    var bets: [Bet] = []
    var selectedFilter: Filter = .upcoming
    var isLoading = false

    private let dataService: any DataServiceProtocol
    private let userId: String?

    init(dataService: any DataServiceProtocol, userId: String?) {
        self.dataService = dataService
        self.userId = userId
    }

    var filteredGames: [Game] {
        switch selectedFilter {
        case .upcoming:
            return games.filter { $0.isUpcoming }.sorted { $0.timestamp < $1.timestamp }
        case .live:
            return games.filter { $0.isLive }.sorted { $0.timestamp < $1.timestamp }
        case .finished:
            return games.filter { $0.isFinished }.sorted { $0.timestamp > $1.timestamp }
        }
    }

    func bet(forGame gameId: Int) -> Bet? {
        bets.first { $0.gameId == gameId }
    }

    func loadGames() async {
        isLoading = true
        if let userId {
            async let fetchedGames = dataService.fetchGames()
            async let fetchedBets = dataService.fetchBets(forUser: userId)
            games = (try? await fetchedGames) ?? []
            bets = (try? await fetchedBets) ?? []
        } else {
            games = (try? await dataService.fetchGames()) ?? []
        }
        isLoading = false
    }
}
