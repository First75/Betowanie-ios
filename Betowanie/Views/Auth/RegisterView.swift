import SwiftUI

struct RegisterView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer(minLength: 20)

                VStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.terraPrimary)
                    Text("Utwórz konto")
                        .font(.terraHeadline(28))
                        .foregroundStyle(Color.terraTextPrimary)
                }

                VStack(spacing: 16) {
                    TerraTextField(title: "Nazwa użytkownika", text: $username)
                        .textContentType(.username)
                        .autocorrectionDisabled()

                    TerraTextField(title: "Email", text: $email)
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    TerraTextField(title: "Hasło", text: $password, isSecure: true)
                        .textContentType(.newPassword)

                    TerraTextField(title: "Potwierdź hasło", text: $confirmPassword, isSecure: true)
                        .textContentType(.newPassword)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.terraCaption())
                            .foregroundStyle(Color.terraError)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                TerraButton(title: "Zarejestruj się", isLoading: isLoading) {
                    performRegister()
                }
            }
            .padding(.horizontal, 24)
        }
        .background(Color.terraBackground)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func performRegister() {
        guard !email.isEmpty, !username.isEmpty, !password.isEmpty else {
            errorMessage = "Wypełnij wszystkie pola"
            return
        }
        guard password == confirmPassword else {
            errorMessage = "Hasła nie są identyczne"
            return
        }
        guard password.count >= 6 else {
            errorMessage = "Hasło musi mieć co najmniej 6 znaków"
            return
        }
        errorMessage = nil
        isLoading = true
        Task {
            do {
                try await appVM.register(email: email, username: username, password: password)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
