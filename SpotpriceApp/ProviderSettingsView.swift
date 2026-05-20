import SwiftUI

struct ProviderSettingsView: View {
    @State private var selectedProviderId = ""
    @State private var credentialValues: [String: String] = [:]
    @State private var testState: TestState = .idle

    private let settings = ConsumptionSettings.shared
    private let providers = ProviderRegistry.shared.allProviderMetadata()

    var body: some View {
        Form {
            providerSection
            credentialsSection
            connectionSection
        }
        .navigationTitle("Förbrukning")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadSettings)
        .onChange(of: selectedProviderId) { _, newValue in
            loadCredentials(for: newValue)
            testState = .idle
        }
    }

    private var providerSection: some View {
        Section {
            Picker("Leverantör", selection: $selectedProviderId) {
                Text("Ingen").tag("")
                ForEach(providers) { provider in
                    Text(provider.displayName).tag(provider.identifier)
                }
            }
        } header: {
            Text("Datakälla")
                .font(DS.Font.caption)
        } footer: {
            Text("Används för månadsförbrukning, effekttoppar och mer träffsäkra kostnader.")
                .font(DS.Font.micro)
        }
    }

    @ViewBuilder
    private var credentialsSection: some View {
        if let metadata = selectedMetadata {
            Section {
                ForEach(metadata.credentialFields) { field in
                    credentialField(field)
                }

                if let portalURL = metadata.portalURL {
                    Link(destination: portalURL) {
                        Label("Öppna \(metadata.displayName)", systemImage: "safari")
                    }
                    .font(DS.Font.callout)
                }
            } header: {
                Text("Inloggningsuppgifter")
                    .font(DS.Font.caption)
            } footer: {
                if let help = metadata.credentialHelpText, !help.isEmpty {
                    Text(help)
                        .font(DS.Font.micro)
                }
            }
        }
    }

    @ViewBuilder
    private var connectionSection: some View {
        if selectedMetadata != nil {
            Section {
                Button {
                    Task { await saveAndTestConnection() }
                } label: {
                    HStack {
                        Label("Spara och testa", systemImage: "checkmark.shield.fill")
                            .font(DS.Font.callout)
                        Spacer()
                        if case .testing = testState {
                            ProgressView()
                        }
                    }
                }
                .disabled(!canSave || testState == .testing)

                switch testState {
                case .idle:
                    EmptyView()
                case .testing:
                    Text("Testar anslutning...")
                        .font(DS.Font.micro)
                        .foregroundStyle(.secondary)
                case .success:
                    Label("Anslutningen fungerar", systemImage: "checkmark.circle.fill")
                        .font(DS.Font.callout)
                        .foregroundStyle(DS.Color.success)
                case .failure(let message):
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(DS.Font.callout)
                        .foregroundStyle(DS.Color.warning)
                }
            }
        }
    }

    private func credentialField(_ field: CredentialField) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            if field.isSecure {
                SecureField(field.label, text: binding(for: field.id))
                    .textContentType(.password)
                    .font(DS.Font.callout)
            } else {
                TextField(field.label, text: binding(for: field.id))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(DS.Font.callout)
            }

            if !field.hint.isEmpty {
                Text(field.hint)
                    .font(DS.Font.micro)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, DS.Spacing.xxs)
    }

    private var selectedMetadata: ProviderMetadata? {
        providers.first { $0.identifier == selectedProviderId }
    }

    private var canSave: Bool {
        guard let metadata = selectedMetadata else { return false }
        let credentials = ProviderCredentials(values: credentialValues)
        return credentials.isComplete(for: metadata.credentialFields)
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(
            get: { credentialValues[key] ?? "" },
            set: { credentialValues[key] = $0 }
        )
    }

    private func loadSettings() {
        selectedProviderId = settings.selectedProviderId
        loadCredentials(for: selectedProviderId)
    }

    private func loadCredentials(for providerId: String) {
        guard !providerId.isEmpty else {
            credentialValues = [:]
            return
        }
        credentialValues = settings.getCredentials(for: providerId).allValues
    }

    private func saveCredentials() {
        guard let metadata = selectedMetadata else { return }
        settings.selectedProviderId = metadata.identifier
        settings.setCredentials(ProviderCredentials(values: credentialValues), for: metadata.identifier)
    }

    private func saveAndTestConnection() async {
        guard let metadata = selectedMetadata else { return }
        saveCredentials()
        testState = .testing

        guard let provider = ProviderRegistry.shared.createProvider(
            identifier: metadata.identifier,
            credentials: ProviderCredentials(values: credentialValues)
        ) else {
            testState = .failure("Kunde inte skapa provider.")
            return
        }

        do {
            try await provider.testConnection()
            testState = .success
            NotificationCenter.default.post(name: .consumptionSettingsDidSave, object: nil)
        } catch {
            testState = .failure(error.localizedDescription)
        }
    }
}

private enum TestState: Equatable {
    case idle
    case testing
    case success
    case failure(String)
}

#Preview {
    NavigationStack {
        ProviderSettingsView()
    }
}
