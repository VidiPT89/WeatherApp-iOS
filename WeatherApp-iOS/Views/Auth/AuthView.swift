import SwiftUI

/// Combined Login/Register screen: a mode switcher over one email+password form.
struct AuthView: View {
    @Environment(AuthStore.self) private var authStore
    @State private var viewModel: AuthViewModel?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "cloud.sun.rain.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.blue.gradient)
                    .padding(.top, 32)

                Text("WeatherApp")
                    .font(.largeTitle.bold())

                if let viewModel {
                    AuthFormContent(viewModel: viewModel)
                }

                Spacer()
            }
            .padding()
            .navigationBarHidden(true)
        }
        .task {
            if viewModel == nil {
                viewModel = AuthViewModel(authStore: authStore)
            }
        }
    }
}

private struct AuthFormContent: View {
    @Bindable var viewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 16) {
            Picker("Modo", selection: $viewModel.mode) {
                ForEach(AuthMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            VStack(spacing: 12) {
                TextField("Email", text: $viewModel.email)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("auth.email")

                SecureField("Password (mín. 8 caracteres)", text: $viewModel.password)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("auth.password")
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await viewModel.submit() }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text(viewModel.mode == .login ? "Entrar" : "Criar conta")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoading)
            .accessibilityIdentifier("auth.submit")
        }
        .padding(.horizontal)
    }
}

#Preview {
    AuthView()
        .environment(AuthStore())
}
