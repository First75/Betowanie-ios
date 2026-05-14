import SwiftUI

struct RootView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var didRestoreSession = false

    var body: some View {
        Group {
            if appVM.currentUser != nil {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appVM.currentUser != nil)
        .task {
            guard !didRestoreSession else { return }
            didRestoreSession = true
            await appVM.restoreSession()
        }
    }
}
