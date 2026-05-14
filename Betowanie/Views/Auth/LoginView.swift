import SwiftUI

struct LoginView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var email = "test1@test.com"
    @State private var password = "password"
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var showRegister = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    Spacer(minLength: 40)

                    // Logo
                    VStack(spacing: 8) {
                        Image(systemName: "soccerball")
                            .font(.system(size: 56))
                            .foregroundStyle(Color.terraPrimary)
                        Text("Betowanie")
                            .font(.terraHeadline(32))
                            .foregroundStyle(Color.terraTextPrimary)
                        Text("Mistrzostwa Świata 2026")
                            .font(.terraCaption())
                            .foregroundStyle(Color.terraTextSecondary)
                    }

                    // Fields
                    VStack(spacing: 16) {
                        TerraTextField(title: "Email", text: $email)
                            .textContentType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)

                        TerraTextField(title: "Hasło", text: $password, isSecure: true)
                            .textContentType(.password)

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.terraCaption())
                                .foregroundStyle(Color.terraError)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    // Actions
                    VStack(spacing: 12) {
                        TerraButton(title: "Zaloguj się", isLoading: isLoading) {
                            performLogin()
                        }

                        TerraButton(title: "Utwórz konto", style: .secondary) {
                            showRegister = true
                        }
                    }

                    // Hint for testing
                    VStack(spacing: 4) {
                        Text("Konto testowe:")
                            .font(.terraCaption(11))
                            .foregroundStyle(Color.terraTextSecondary)
                        Text("test1@test.com / password")
                            .font(.terraCaption(11))
                            .foregroundStyle(Color.terraTextSecondary)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 24)
            }
            .background(Color.terraBackground)
            .navigationDestination(isPresented: $showRegister) {
                RegisterView()
            }
        }
    }

    private func performLogin() {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Wypełnij wszystkie pola"
            return
        }
        errorMessage = nil
        isLoading = true
        Task {
            do {
                try await appVM.login(email: email, password: password)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
