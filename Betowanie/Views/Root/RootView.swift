import SwiftUI

struct RootView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var didRestoreSession = false

    var body: some View {
        Group {
            if appVM.isLoading || !didRestoreSession {
                SplashView()
            } else if let user = appVM.currentUser {
                if user.isActive {
                    MainTabView()
                } else {
                    AccountInactiveView()
                }
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appVM.currentUser?.id)
        .animation(.easeInOut(duration: 0.3), value: appVM.currentUser?.isActive)
        .animation(.easeInOut(duration: 0.3), value: appVM.isLoading)
        .toastHost()
        .task {
            guard !didRestoreSession else { return }
            await appVM.restoreSession()
            didRestoreSession = true
        }
        .task(id: appVM.currentUser?.id) {
            guard appVM.currentUser != nil else { return }
            await PushNotifications.shared.requestAuthorization()
            await appVM.syncFCMTokenIfAvailable()
        }
    }
}

private struct SplashView: View {
    var body: some View {
        ZStack {
            Color.terraBackground
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image("msLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180, height: 180)

                ProgressView()
                    .tint(Color.terraPrimary)
            }
            .padding(32)
        }
    }
}
