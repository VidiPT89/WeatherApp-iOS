import SwiftUI

/// Admin-only: every registered account, newest first is not guaranteed (backend returns
/// natural id order), swipe-to-delete on every row except the caller's own -- deleting your
/// own admin account would leave the app with no admin, so that action is hidden entirely
/// rather than shown and then rejected.
struct AdminUsersView: View {
    let currentUserId: Int?

    @State private var viewModel = AdminUsersViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("A carregar...")
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
            } else if let errorMessage = viewModel.errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                    Text(errorMessage).font(.subheadline).multilineTextAlignment(.center)
                }
                .padding(.top, 40)
            } else if viewModel.users.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "person.2").font(.system(size: 36)).foregroundStyle(.secondary)
                    Text("Ainda não há outras contas.")
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)
            } else {
                List(viewModel.users) { user in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.email).font(.headline)
                            Text(user.createdAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(user.role == .admin ? "Admin" : "Utilizador")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                (user.role == .admin ? Color.accentColor : .secondary).opacity(0.15),
                                in: Capsule()
                            )
                            .foregroundStyle(user.role == .admin ? Color.accentColor : .secondary)
                    }
                    .swipeActions(edge: .trailing) {
                        if user.id != currentUserId {
                            Button(role: .destructive) {
                                Task { await viewModel.delete(user) }
                            } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
                            .disabled(viewModel.deletingUserId == user.id)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Gerir utilizadores")
        .task { await viewModel.loadUsers() }
        .refreshable { await viewModel.loadUsers() }
    }
}

#Preview {
    NavigationStack {
        AdminUsersView(currentUserId: 1)
    }
}
