import SwiftUI

/// Shown in place of Favorites/History content for an unauthenticated
/// (guest) user, since those two features are the only ones still gated
/// behind an account -- weather lookup itself works anonymously.
struct SignInRequiredView: View {
    let message: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            Button("Iniciar sessão / Criar conta", action: action)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SignInRequiredView(message: "Inicia sessão para guardares as tuas cidades favoritas.", action: {})
}
