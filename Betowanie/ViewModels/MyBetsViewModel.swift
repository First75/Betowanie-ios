import SwiftUI

@Observable
final class MyBetsViewModel {
    enum Filter: String, CaseIterable {
        case open = "Otwarte"
        case closed = "Zamknięte"
    }

    var bets: [Bet] = []
    var games: [Game] = []
    var selectedFilter: Filter = .open
    var isLoading = false

    private let dataService: any DataServiceProtocol
    private let userId: String

    init(dataService: any DataServiceProtocol, userId: String) {
        self.dataService = dataService
        self.userId = userId
    }

    var gamesById: [Int: Game] {
        Dictionary(uniqueKeysWithValues: games.map { ($0.id, $0) })
    }

    var filteredBets: [(bet: Bet, game: Game)] {
        let lookup = gamesById
        return bets.compactMap { bet in
            guard let game = lookup[bet.gameId] else { return nil }
            switch selectedFilter {
            case .open:
                return game.isUpcoming || game.isLive ? (bet, game) : nil
            case .closed:
                return game.isFinished ? (bet, game) : nil
            }
        }
        .sorted { pair1, pair2 in
            pair1.game.timestamp > pair2.game.timestamp
        }
    }

    func loadData() async {
        isLoading = true
        async let fetchedGames = dataService.fetchGames()
        async let fetchedBets = dataService.fetchBets(forUser: userId)
        games = (try? await fetchedGames) ?? []
        bets = (try? await fetchedBets) ?? []
        isLoading = false
    }
}
