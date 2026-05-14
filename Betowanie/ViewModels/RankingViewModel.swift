import SwiftUI

@Observable
final class RankingViewModel {
    var ranking: [RankingEntry] = []
    var isLoading = false

    private let dataService: any DataServiceProtocol

    init(dataService: any DataServiceProtocol) {
        self.dataService = dataService
    }

    func loadRanking() async {
        isLoading = true
        ranking = (try? await dataService.fetchRanking()) ?? []
        isLoading = false
    }
}
