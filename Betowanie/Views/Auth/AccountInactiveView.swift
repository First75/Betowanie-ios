import SwiftUI

/// Full-screen view shown after a successful login when the user account
/// has `isActive == false` in Firestore. Lets the user retry (throttled to
/// once per 30 seconds) or log out.
struct AccountInactiveView: View {
    @Environment(AppViewModel.self) private var appVM

    private static let refreshCooldown: TimeInterval = 30

    @State private var isRefreshing = false
    @State private var cooldownRemaining: Int = 0

    var body: some View {
        ZStack {
            Color.terraBackground
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "hourglass")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(Color.terraPrimary)

                VStack(spacing: 12) {
                    Text("Twoje konto nie zostało jeszcze aktywowane")
                        .font(.terraHeadline(24))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.terraTextPrimary)

                    Text("Skontaktuj się z administratorem, aby aktywować konto. Po aktywacji naciśnij „Odśwież”.")
                        .font(.terraBody())
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.terraTextSecondary)
                }
                .padding(.horizontal, 8)

                if cooldownRemaining > 0 {
                    Text("Możesz odświeżyć ponownie za \(cooldownRemaining) s")
                        .font(.terraCaption())
                        .foregroundStyle(Color.terraTextSecondary)
                }

                Spacer()

                VStack(spacing: 12) {
                    TerraButton(
                        title: cooldownRemaining > 0 ? "Odśwież (\(cooldownRemaining) s)" : "Odśwież",
                        isLoading: isRefreshing
                    ) {
                        performRefresh()
                    }
                    .disabled(cooldownRemaining > 0)

                    TerraButton(title: "Wyloguj", style: .secondary) {
                        appVM.logout()
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 40)
        }
    }

    private func performRefresh() {
        guard !isRefreshing, cooldownRemaining == 0 else { return }
        isRefreshing = true
        Task {
            await appVM.refreshActiveStatus()
            isRefreshing = false
            await runCooldown()
        }
    }

    private func runCooldown() async {
        cooldownRemaining = Int(Self.refreshCooldown)
        while cooldownRemaining > 0 {
            try? await Task.sleep(for: .seconds(1))
            if Task.isCancelled { return }
            cooldownRemaining -= 1
        }
    }
}
