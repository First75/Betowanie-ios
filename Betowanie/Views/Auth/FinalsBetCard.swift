import SwiftUI

struct FinalsBetCard: View {
    @Environment(AppViewModel.self) private var appVM

    let userId: String
    let username: String
    let bettingClosesAt: Date

    @State private var teams: [Team] = []
    @State private var myBet: BetFinals?
    @State private var otherBets: [BetFinals] = []
    @State private var isSaving = false
    @State private var isLoadingOtherBets = false
    @State private var isShowingOtherBetsSheet = false

    @State private var selectedTeam1Id: Int?
    @State private var selectedTeam2Id: Int?

    private var isBettingOpen: Bool { Date() < bettingClosesAt }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Typ na finalistów")
                .font(.terraTitle(20))
                .foregroundStyle(Color.terraTextPrimary)

            if isBettingOpen {
                beforeStartContent
            } else {
                afterStartContent
            }
        }
        .padding(16)
        .terraCard()
        .task { await loadData() }
        .sheet(isPresented: $isShowingOtherBetsSheet) {
            otherBetsSheet
        }
    }

    private var beforeStartContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                teamMenu(title: selectedTeam1Name ?? "Wybierz drużynę 1", selection: $selectedTeam1Id)
                teamMenu(title: selectedTeam2Name ?? "Wybierz drużynę 2", selection: $selectedTeam2Id)
            }
            TerraButton(title: "Zapisz typ", isLoading: isSaving) {
                saveBet()
            }
            .disabled(!canSave)
        }
    }

    private var afterStartContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let myBet {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Twój typ")
                        .font(.terraCaption(12))
                        .foregroundStyle(Color.terraTextSecondary)
                    finalistsRow(for: myBet, emphasized: true)
                }
            } else {
                Text("Brak Twojego typu finalistów")
                    .font(.terraBody())
                    .foregroundStyle(Color.terraTextSecondary)
            }

            TerraButton(title: "Zobacz typy innych", style: .secondary) {
                isShowingOtherBetsSheet = true
            }
        }
    }

    private func teamMenu(title: String, selection: Binding<Int?>) -> some View {
        Menu {
            ForEach(teams) { team in
                Button(team.name) { selection.wrappedValue = team.id }
            }
        } label: {
            HStack {
                Text(title)
                    .font(.terraBody())
                    .foregroundStyle(Color.terraTextPrimary)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.terraTextSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.terraCardFill)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func finalistPill(_ name: String?) -> some View {
        Text(name ?? "?")
            .font(.terraCaption(12))
            .foregroundStyle(Color.terraTextPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.terraCardFill)
            .clipShape(Capsule())
    }

    @ViewBuilder
    private func finalistsRow(for bet: BetFinals, emphasized: Bool = false) -> some View {
        let firstTeamBet = bet.teamBet.first
        let secondTeamBet = bet.teamBet.dropFirst().first
        let firstTeam = team(for: firstTeamBet)
        let secondTeam = team(for: secondTeamBet)

        HStack(spacing: 10) {
            finalistTeamPill(for: firstTeam, fallbackName: firstTeamBet?.teamName, emphasized: emphasized)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.terraTertiary)
                .frame(width: 20)
            finalistTeamPill(for: secondTeam, fallbackName: secondTeamBet?.teamName, emphasized: emphasized)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func finalistTeamPill(for team: Team?, fallbackName: String?, emphasized: Bool) -> some View {
        HStack(spacing: 8) {
            if let team {
                TeamLogoView(urlString: team.icon, teamName: team.name, size: 28)
            } else {
                Circle()
                    .fill(Color.terraPrimary.opacity(0.14))
                    .frame(width: 28, height: 28)
                    .overlay {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.terraPrimary)
                    }
            }

            Text(team?.name ?? fallbackName ?? "?")
                .font(emphasized ? .terraLabel() : .terraBody(15))
                .foregroundStyle(Color.terraTextPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(emphasized ? Color.terraPrimary.opacity(0.10) : Color.terraCardFill)
        .clipShape(Capsule())
    }

    private var otherBetsSheet: some View {
        NavigationStack {
            ZStack {
                Color.terraBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        sheetHero

                        if isLoadingOtherBets {
                            loadingOtherBetsView
                        } else if otherBets.isEmpty {
                            emptyOtherBetsView
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(otherBets) { bet in
                                    otherBetRow(for: bet)
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Typy finalistów")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zamknij") {
                        isShowingOtherBetsSheet = false
                    }
                }
            }
        }
        .task(id: isShowingOtherBetsSheet) {
            guard isShowingOtherBetsSheet else { return }
            await loadOtherBets()
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var sheetHero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Poznaj typy pozostałych graczy")
                .font(.terraTitle(22))
                .foregroundStyle(Color.terraTextPrimary)

            Text("Po starcie turnieju wszystkie typy finalistów są już odkryte.")
                .font(.terraBody(15))
                .foregroundStyle(Color.terraTextSecondary)

            HStack(spacing: 12) {
                summaryStat(title: "Inni gracze", value: "\(otherBets.count)")
                summaryStat(title: "Twój typ", value: myBet == nil ? "Brak" : "Zapisany")
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color.terraPrimary.opacity(0.18), Color.terraCardFill],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func summaryStat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.terraCaption(11))
                .foregroundStyle(Color.terraTextSecondary)
            Text(value)
                .font(.terraTitle(18))
                .foregroundStyle(Color.terraTextPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var loadingOtherBetsView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Ładowanie typów innych graczy…")
                .font(.terraBody())
                .foregroundStyle(Color.terraTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .terraCard()
    }

    private var emptyOtherBetsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 34))
                .foregroundStyle(Color.terraTextSecondary.opacity(0.6))
            Text("Brak typów innych użytkowników")
                .font(.terraBody())
                .foregroundStyle(Color.terraTextPrimary)
            Text("Gdy pozostali gracze zapiszą swoich finalistów, pojawią się tutaj.")
                .font(.terraCaption())
                .foregroundStyle(Color.terraTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .terraCard()
    }

    private func otherBetRow(for bet: BetFinals) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(bet.username)
                        .font(.terraLabel())
                        .foregroundStyle(Color.terraTextPrimary)
                    Text("Typ finałowy")
                        .font(.terraCaption(12))
                        .foregroundStyle(Color.terraTextSecondary)
                }
                Spacer()
                Image(systemName: "person.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.terraPrimary)
                    .padding(10)
                    .background(Color.terraPrimary.opacity(0.10))
                    .clipShape(Circle())
            }

            finalistsRow(for: bet)
        }
        .padding(16)
        .background(Color.terraCardFill)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func team(for teamBet: TeamBet?) -> Team? {
        guard let teamBet else { return nil }

        if let team = teams.first(where: { String($0.id) == teamBet.teamId }) {
            return team
        }

        return teams.first(where: { $0.name == teamBet.teamName })
    }

    private var selectedTeam1Name: String? { teams.first(where: { $0.id == selectedTeam1Id })?.name }
    private var selectedTeam2Name: String? { teams.first(where: { $0.id == selectedTeam2Id })?.name }

    private var canSave: Bool {
        if let a = selectedTeam1Id, let b = selectedTeam2Id, a != b { return true }
        return false
    }

    private func loadData() async {
        async let fetchedTeams = appVM.dataService.fetchTeams()
        async let my = appVM.dataService.fetchFinalsBet(forUser: userId)
        if let teams = try? await fetchedTeams { self.teams = teams }
        if let myBet = try? await my { self.myBet = myBet }
        // Preselect from existing bet
        if let myBet, selectedTeam1Id == nil, selectedTeam2Id == nil {
            if let first = team(for: myBet.teamBet.first)?.id,
               let second = team(for: myBet.teamBet.dropFirst().first)?.id {
                selectedTeam1Id = first
                selectedTeam2Id = second
            }
        }
    }

    @MainActor
    private func loadOtherBets() async {
        guard !isBettingOpen else {
            otherBets = []
            return
        }

        isLoadingOtherBets = true
        defer { isLoadingOtherBets = false }

        do {
            let allBets = try await appVM.dataService.fetchAllFinalsBets()
            otherBets = allBets
                .filter { $0.userId != userId }
                .sorted { $0.username.localizedCaseInsensitiveCompare($1.username) == .orderedAscending }
            print("[FinalsBetCard] Loaded \(otherBets.count) other finals bets for userId=\(userId)")
        } catch {
            otherBets = []
            print("[FinalsBetCard] Failed to load other finals bets: \(error.localizedDescription)")
        }
    }

    private func saveBet() {
        guard let aId = selectedTeam1Id, let bId = selectedTeam2Id, aId != bId else { return }
        guard let firstTeam = teams.first(where: { $0.id == aId }),
              let secondTeam = teams.first(where: { $0.id == bId }) else { return }
        isSaving = true
        let bet = BetFinals(
            userId: userId,
            username: username,
            teamBet: [
                TeamBet(teamId: String(firstTeam.id), teamName: firstTeam.name),
                TeamBet(teamId: String(secondTeam.id), teamName: secondTeam.name),
            ]
        )
        Task {
            try? await appVM.dataService.placeFinalsBet(bet)
            myBet = bet
            isSaving = false
        }
    }
}
