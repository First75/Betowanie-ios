import SwiftUI

struct MyBetsView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var viewModel: MyBetsViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            StatsBar(position: appVM.userPosition, points: appVM.userPoints)
                                .padding(.horizontal, 16)
                                .padding(.top, 8)

                            FinalsBetCard(
                                userId: appVM.currentUser?.id ?? "",
                                username: appVM.currentUser?.username ?? "",
                                bettingClosesAt: EventConfig.finalsBettingClosingDate
                            )
                            .padding(.horizontal, 16)

                            Picker("Filtr", selection: Bindable(viewModel).selectedFilter) {
                                ForEach(MyBetsViewModel.Filter.allCases, id: \.self) { filter in
                                    Text(filter.rawValue).tag(filter)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 4)

                            if viewModel.filteredBets.isEmpty {
                                emptyStateView
                                    .padding(.horizontal, 16)
                            } else {
                                ForEach(viewModel.filteredBets, id: \.bet.id) { pair in
                                    MatchCard(game: pair.game, bet: pair.bet)
                                        .padding(.horizontal, 16)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                } else {
                    ProgressView()
                }
            }
            .background(Color.terraBackground)
            .navigationTitle("Moje zakłady")
            .profileAccessSheet()
            .task {
                guard let userId = appVM.currentUser?.id else { return }
                let vm = MyBetsViewModel(dataService: appVM.dataService, userId: userId)
                viewModel = vm
                await vm.loadData()
                await appVM.refreshUserStats()
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 40))
                .foregroundStyle(Color.terraTextSecondary.opacity(0.5))
            Text("Brak zakładów")
                .font(.terraBody())
                .foregroundStyle(Color.terraTextSecondary)
            Text("Przejdź do zakładki Mecze, aby obstawić wynik")
                .font(.terraCaption())
                .foregroundStyle(Color.terraTextSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
