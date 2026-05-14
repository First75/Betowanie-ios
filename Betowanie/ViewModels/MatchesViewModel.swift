import SwiftUI

@Observable
final class MatchesViewModel {
    enum Filter: String, CaseIterable {
        case upcoming = "Nadchodzące"
        case live = "Trwające"
        case finished = "Zakończone"
    }

    var games: [Game] = []
    var selectedFilter: Filter = .upcoming
    var isLoading = false

    private let dataService: any DataServiceProtocol

    init(dataService: any DataServiceProtocol) {
        self.dataService = dataService
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

    func loadGames() async {
        isLoading = true
        games = (try? await dataService.fetchGames()) ?? []
        isLoading = false
    }
}
