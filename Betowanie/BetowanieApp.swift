//
//  BetowanieApp.swift
//  Betowanie
//
//  Created by Jakub Bartuś on 14/05/2026.
//

import SwiftUI
import FirebaseCore

@main
struct BetowanieApp: App {

    @UIApplicationDelegateAdaptor(BetowanieAppDelegate.self) private var appDelegate
    @State private var appVM: AppViewModel

    init() {
        FirebaseApp.configure()

        _appVM = State(initialValue: AppViewModel(
            dataService: FirebaseDataService(),
            authService: FirebaseAuthService()
        ))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appVM)
                .preferredColorScheme(.light)
                .task {
                    await TeamLogoView.preloadKnownTeamLogos()
                }
        }
    }
}
