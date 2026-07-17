import SwiftUI

/// Shows/updates the saved unit preference, and lets the user log out.
struct SettingsView: View {
    @Environment(AuthStore.self) private var authStore
    @State private var viewModel = SettingsViewModel()

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
