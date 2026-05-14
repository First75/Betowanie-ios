import SwiftUI

struct ProfileView: View {
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Avatar
                    if let user = appVM.currentUser {
                        VStack(spacing: 12) {
                            let initials = user.username.prefix(2).uppercased()
                            Text(initials)
                                .font(.terraHeadline(28))
                                .foregroundStyle(.white)
                                .frame(width: 80, height: 80)
                                .background(Color.terraPrimary)
                                .clipShape(Circle())

                            Text(user.username)
                                .font(.terraTitle())
                                .foregroundStyle(Color.terraTextPrimary)

                            Text(user.email)
                                .font(.terraCaption())
                                .foregroundStyle(Color.terraTextSecondary)
                        }
                        .padding(.top, 16)
                    }

                    // Stats
                    VStack(spacing: 16) {
                        Text("Moje statystyki")
                            .font(.terraTitle(18))
                            .foregroundStyle(Color.terraTextPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 12) {
                            statCard(title: "Pozycja", value: "\(appVM.userPosition)", icon: "medal")
                            statCard(title: "Punkty", value: "\(appVM.userPoints)", icon: "star.fill")
                        }
                    }
                    .padding(.horizontal, 16)

                    Spacer(minLength: 40)

                    // Logout
                    TerraButton(title: "Wyloguj się", style: .destructive) {
                        appVM.logout()
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 16)
            }
            .background(Color.terraBackground)
            .navigationTitle("Profil")
            .task {
                await appVM.refreshUserStats()
            }
        }
    }

    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(Color.terraTertiary)
            Text(value)
                .font(.terraHeadline(24))
                .foregroundStyle(Color.terraTextPrimary)
            Text(title)
                .font(.terraCaption())
                .foregroundStyle(Color.terraTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.terraCardFill)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
