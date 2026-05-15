import SwiftUI
import PhotosUI

struct ProfileView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss

    @State private var statsViewModel: UserStatsViewModel?
    @State private var pickedAvatar: PhotosPickerItem?
    @State private var isUploadingAvatar = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let user = appVM.currentUser {
                    avatarPicker(for: user)
                        .padding(.top, 16)
                }

                if let statsViewModel {
                    UserStatsCard(stats: statsViewModel.stats, title: "Moje statystyki")
                        .padding(.horizontal, 16)
                } else {
                    ProgressView()
                        .padding(.vertical, 40)
                }

                Spacer(minLength: 40)

                TerraButton(title: "Wyloguj się", style: .destructive) {
                    appVM.logout()
                    dismiss()
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 16)
        }
        .background(Color.terraBackground)
        .navigationTitle("Profil")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Zamknij") { dismiss() }
            }
        }
        .task {
            guard let user = appVM.currentUser else { return }
            let vm = UserStatsViewModel(dataService: appVM.dataService, userId: user.id)
            statsViewModel = vm
            await vm.load()
            // Keep the global stats bar in sync after pulling fresh data.
            await appVM.refreshUserStats()
        }
        .onChange(of: pickedAvatar) { _, newItem in
            guard let newItem else { return }
            Task { await handlePicked(newItem) }
        }
    }

    /// Wraps the profile header in a PhotosPicker — tapping the avatar opens the
    /// photo library; on selection we resize, encode, and upload.
    private func avatarPicker(for user: User) -> some View {
        PhotosPicker(selection: $pickedAvatar, matching: .images, photoLibrary: .shared()) {
            UserProfileHeader(
                username: user.username,
                email: user.email,
                photoURL: user.photoURL
            ) {
                ZStack {
                    Circle()
                        .fill(Color.terraPrimary)
                        .frame(width: 26, height: 26)
                    if isUploadingAvatar {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(.white)
                    } else {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .overlay(Circle().stroke(Color.terraBackground, lineWidth: 2))
                .offset(x: 2, y: 2)
            }
        }
        .buttonStyle(.plain)
        .disabled(isUploadingAvatar)
    }

    private func handlePicked(_ item: PhotosPickerItem) async {
        isUploadingAvatar = true
        defer {
            isUploadingAvatar = false
            pickedAvatar = nil
        }
        do {
            guard
                let data = try await item.loadTransferable(type: Data.self),
                let image = UIImage(data: data)
            else {
                Toast.shared.show("Nie udało się wczytać zdjęcia", style: .negative)
                return
            }
            try await appVM.uploadAvatar(image)
            Toast.shared.show("Zaktualizowano awatar", style: .positive)
        } catch let err {
            Toast.shared.show("Nie udało się zapisać zdjęcia", style: .negative)
            print(err)
        }
    }
}
