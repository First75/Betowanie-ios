import SwiftUI

struct MatchesView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var viewModel: MatchesViewModel?
    @State private var selectedGame: Game?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    VStack(spacing: 0) {
                        // Filter picker
                        Picker("Filtr", selection: Bindable(viewModel).selectedFilter) {
                            ForEach(MatchesViewModel.Filter.allCases, id: \.self) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        // Games list
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                if viewModel.filteredGames.isEmpty {
                                    emptyStateView
                                } else {
                                    ForEach(viewModel.filteredGames) { game in
                                        MatchCard(game: game, showBetInfo: false)
                                            .padding(.horizontal, 16)
                                            .onTapGesture {
                                                selectedGame = game
                                            }
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                } else {
                    ProgressView()
                }
            }
            .background(Color.terraBackground)
            .navigationTitle("Mecze")
            .profileAccessSheet()
            .sheet(item: $selectedGame) { game in
                MatchDetailView(game: game)
            }
            .task {
                let vm = MatchesViewModel(dataService: appVM.dataService)
                viewModel = vm
                await vm.loadGames()
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "sportscourt")
                .font(.system(size: 40))
                .foregroundStyle(Color.terraTextSecondary.opacity(0.5))
            Text("Brak meczów")
                .font(.terraBody())
                .foregroundStyle(Color.terraTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
