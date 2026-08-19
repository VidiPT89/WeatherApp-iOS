import SwiftUI

/// Shows/updates the saved unit preference, language, appearance, and lets
/// the user log out.
struct SettingsView: View {
    @Environment(AuthStore.self) private var authStore
    @State private var viewModel = SettingsViewModel()
    @State private var showAuthSheet = false
    @AppStorage(AppLocale.storageKey) private var appLocaleRaw: String = AppLocale.default.rawValue
    @AppStorage(AppTheme.storageKey) private var appThemeRaw: String = AppTheme.default.rawValue

    var body: some View {
        NavigationStack {
            Form {
                if authStore.isAuthenticated {
                    Section("Unidades") {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Picker("Temperatura", selection: Binding(
                                get: { viewModel.units },
                                set: { newUnits in Task { await viewModel.updateUnits(to: newUnits) } }
                            )) {
                                ForEach(Units.allCases) { units in
                                    Text(units.displayName).tag(units)
                                }
                            }
                            .pickerStyle(.inline)
                            .labelsHidden()
                        }

                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage).font(.footnote).foregroundStyle(.red)
                        } else if let confirmation = viewModel.saveConfirmation {
                            Text(confirmation).font(.footnote).foregroundStyle(.green)
                        }
                    }
                }

                Section {
                    Picker("Idioma", selection: $appLocaleRaw) {
                        ForEach(AppLocale.allCases) { locale in
                            Text(locale.titleKey).tag(locale.rawValue)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Idioma")
                } footer: {
                    Text("Idioma usado em toda a aplicação.")
                }

                Section {
                    Picker("Modo", selection: $appThemeRaw) {
                        ForEach(AppTheme.allCases) { theme in
                            Label {
                                Text(theme.titleKey)
                            } icon: {
                                Image(systemName: theme.symbolName)
                            }
                            .tag(theme.rawValue)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Aparência")
                } footer: {
                    Text("Escolhe entre tema claro, escuro, ou o do sistema.")
                }

                Section {
                    Link(destination: URL(string: "https://ividi.dev")!) {
                        Label("O meu site", systemImage: "globe")
                    }
                    Link(destination: URL(string: "https://github.com/VidiPT89")!) {
                        Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                } header: {
                    Text("Sobre o criador")
                } footer: {
                    Text("Esta app foi criada por David Arsénio Martins.")
                }

                if authStore.isAdmin {
                    Section {
                        NavigationLink("Gerir utilizadores") {
                            AdminUsersView(currentUserId: authStore.currentUser?.id)
                        }
                    } header: {
                        Text("Administração")
                    }
                }

                Section {
                    if authStore.isAuthenticated {
                        Button("Terminar sessão", role: .destructive) {
                            authStore.logout()
                        }
                    } else {
                        Button("Iniciar sessão / Criar conta") {
                            showAuthSheet = true
                        }
                    }
                } footer: {
                    if !authStore.isAuthenticated {
                        Text("A pesquisa de tempo funciona sem conta. Inicia sessão para guardar favoritos e histórico.")
                    }
                }
            }
            .navigationTitle("Definições")
            .task(id: authStore.isAuthenticated) {
                await viewModel.loadPreferences(isAuthenticated: authStore.isAuthenticated)
            }
            .sheet(isPresented: $showAuthSheet) {
                AuthView()
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(AuthStore())
}
