import SwiftUI

struct ProfileAccessModifier: ViewModifier {
    @Environment(AppViewModel.self) private var appVM
    @State private var isShowingProfile = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingProfile = true
                    } label: {
                        profileAvatar
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Profil")
                }
            }
            .sheet(isPresented: $isShowingProfile) {
                NavigationStack {
                    ProfileView()
                }
                .presentationDetents([.large])
            }
    }

    @ViewBuilder
    private var profileAvatar: some View {
        if let user = appVM.currentUser {
            let initials = String(user.username.prefix(2)).uppercased()

            Text(initials.isEmpty ? "?" : initials)
                .font(.terraCaption(12))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Color.terraPrimary)
                .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(Color.terraPrimary)
        }
    }
}

extension View {
    func profileAccessSheet() -> some View {
        modifier(ProfileAccessModifier())
    }
}
