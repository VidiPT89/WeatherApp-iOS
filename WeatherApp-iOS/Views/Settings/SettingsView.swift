import SwiftUI

/// Shows/updates the saved unit preference, language, appearance, and lets
/// the user log out.
struct SettingsView: View {
    @Environment(AuthStore.self) private var authStore
    @State private var viewModel = SettingsViewModel()
    @AppStorage(AppLocale.storageKey) private var appLocaleRaw: String = AppLocale.default.rawValue
    @AppStorage(AppTheme.storageKey) private var appThemeRaw: String = AppTheme.default.rawValue

    var body: some View {
        NavigationStack {
            Form {
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
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage).font(.footnote).foregroundStyle(.red)
                    } else if let confirmation = viewModel.saveConfirmation {
                        Text(confirmation).font(.footnote).foregroundStyle(.green)
                    }
                }

                Section {
                    Picker("Idioma", selection: $appLocaleRaw) {
                        ForEach(AppLocale.allCases) { locale in
                            Text(locale.titleKey).tag(locale.rawValue)
                        }
                    }
                    .pickerStyle(.inline)
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
                } header: {
                    Text("Aparência")
                } footer: {
                    Text("Escolhe entre tema claro, escuro, ou o do sistema.")
                }

                Section {
                    Button("Terminar sessão", role: .destructive) {
                        authStore.logout()
                    }
                }
            }
            .navigationTitle("Definições")
            .task { await viewModel.loadPreferences() }
        }
    }
}

#Preview {
    SettingsView()
        .environment(AuthStore())
}
