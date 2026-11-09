import SwiftUI

struct ProviderSettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var focusedField: String?

    @State private var selectedProviderId = ""
    @State private var credentialValues: [String: String] = [:]
    @State private var testState: TestState = .idle
    @State private var showSaved = false
    @State private var isReady = false
    @State private var pendingSave: Task<Void, Never>?
    @State private var hideSavedTask: Task<Void, Never>?

    private let settings = ConsumptionSettings.shared
    private let providers = ProviderRegistry.shared.allProviderMetadata()

    var body: some View {
        ZStack {
            AppCanvasBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    savedRow
                    providerCard
                    if selectedMetadata != nil {
                        credentialsCard
                        connectionCard
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.xl * 4)
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("Förbrukning")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        .onAppear {
            guard !isReady else { return }
            loadSettings()
        }
        .onDisappear {
            flushPendingSave()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                flushPendingSave()
            }
        }
        .onChange(of: selectedProviderId) { _, newValue in
            guard isReady else { return }
            loadCredentials(for: newValue)
            testState = .idle
            persistProviderSelection(newValue)
        }
        .onChange(of: credentialValues) { _, _ in
            scheduleCredentialSave()
        }
        .onChange(of: focusedField) { _, newValue in
            if newValue == nil {
                flushPendingSave()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Klar") {
                    focusedField = nil
                }
            }
        }
    }

    private var savedRow: some View {
        HStack {
            Spacer(minLength: 0)
            if showSaved {
                SettingsSavedLabel()
            }
        }
        .frame(minHeight: 16)
        .accessibilityHidden(!showSaved)
    }

    private var providerCard: some View {
        SettingsCard(
            title: "Datakälla",
            footer: "Används för månadsförbrukning, effekttoppar och mer träffsäkra kostnader."
        ) {
            Picker("Leverantör", selection: $selectedProviderId) {
                Text("Ingen").tag("")
                ForEach(providers) { provider in
                    Text(provider.displayName).tag(provider.identifier)
                }
            }
            .pickerStyle(.menu)
            .accessibilityLabel("Leverantör")
        }
    }

    @ViewBuilder
    private var credentialsCard: some View {
        if let metadata = selectedMetadata {
            SettingsCard(
                title: "Inloggningsuppgifter",
                footer: metadata.credentialHelpText
            ) {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    ForEach(metadata.credentialFields) { field in
                        credentialField(field)
                    }

                    if let portalURL = metadata.portalURL {
                        Link(destination: portalURL) {
                            Label("Öppna \(metadata.displayName)", systemImage: "safari")
                                .font(DS.Font.callout)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var connectionCard: some View {
        if selectedMetadata != nil {
            SettingsCard(
                title: "Anslutning",
                footer: canSave
                    ? "Uppgifterna sparas automatiskt. Testa när du vill kontrollera att inloggningen fungerar."
                    : "Fyll i uppgifterna innan du testar anslutningen."
            ) {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    Button {
                        Task { await testConnection() }
                    } label: {
                        HStack {
                            Label(verifyActionTitle, systemImage: verifyActionSymbol)
                                .font(DS.Font.callout)
                            Spacer()
                            if case .testing = testState {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(!canSave || testState == .testing)
                    .accessibilityHint("Sparar uppgifterna och testar anslutningen mot leverantören")

                    switch testState {
                    case .idle:
                        EmptyView()
                    case .testing:
                        Text("Testar anslutning...")
                            .font(DS.Font.micro)
                            .foregroundStyle(DS.Color.secondary)
                    case .success:
                        Label("Anslutningen fungerar", systemImage: "checkmark.circle.fill")
                            .font(DS.Font.callout)
                            .foregroundStyle(DS.Color.success)
                    case .failure(let message):
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .font(DS.Font.callout)
                            .foregroundStyle(DS.Color.warning)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func credentialField(_ field: CredentialField) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(field.label)
                .font(DS.Font.callout)

            if field.isSecure {
                SecureField(field.label, text: binding(for: field.id))
                    .textContentType(.password)
                    .font(DS.Font.callout)
                    .focused($focusedField, equals: field.id)
                    .submitLabel(.done)
                    .onSubmit { flushPendingSave() }
                    .accessibilityLabel(field.label)
            } else {
                TextField(field.label, text: binding(for: field.id))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(DS.Font.callout)
                    .focused($focusedField, equals: field.id)
                    .submitLabel(.next)
                    .onSubmit { flushPendingSave() }
                    .accessibilityLabel(field.label)
            }

            if !field.hint.isEmpty {
                Text(field.hint)
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var selectedMetadata: ProviderMetadata? {
        providers.first { $0.identifier == selectedProviderId }
    }

    private var canSave: Bool {
        guard let metadata = selectedMetadata else { return false }
        let credentials = ProviderCredentials(values: credentialValues)
        return credentials.isComplete(for: metadata.credentialFields)
    }

    private var verifyActionTitle: String {
        selectedProviderId == VaggerydProvider.identifier ? "Logga in" : "Testa anslutning"
    }

    private var verifyActionSymbol: String {
        selectedProviderId == VaggerydProvider.identifier ? "person.crop.circle.badge.checkmark" : "checkmark.shield.fill"
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
        isReady = true
    }

    private func loadCredentials(for providerId: String) {
        guard !providerId.isEmpty else {
            credentialValues = [:]
            return
        }
        credentialValues = settings.getCredentials(for: providerId).allValues
    }

    private func persistProviderSelection(_ providerId: String) {
        settings.selectedProviderId = providerId
        if providerId.isEmpty {
            credentialValues = [:]
            if settings.costProfile.confidence == .providerConnected {
                settings.costProfile = settings.costProfile.applyingInferredConfidence(
                    preservingProviderConnected: false,
                    configuredSource: .userEntered
                )
            }
            NotificationCenter.default.post(name: .consumptionSettingsDidSave, object: nil)
        }
        flashSaved()
    }

    private func scheduleCredentialSave() {
        guard isReady, !selectedProviderId.isEmpty else { return }
        pendingSave?.cancel()
        pendingSave = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            persistCredentials()
        }
    }

    private func flushPendingSave() {
        pendingSave?.cancel()
        persistCredentials()
    }

    private func persistCredentials() {
        guard isReady, let metadata = selectedMetadata else { return }
        let credentials = ProviderCredentials(values: credentialValues)
        let existing = settings.getCredentials(for: metadata.identifier)
        settings.selectedProviderId = metadata.identifier
        settings.setCredentials(credentials, for: metadata.identifier)
        if credentials != existing {
            flashSaved()
        }
    }

    private func testConnection() async {
        flushPendingSave()
        guard let metadata = selectedMetadata else { return }
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
            testState = .failure(error.userFacingMessage)
        }
    }

    private func flashSaved() {
        guard isReady else { return }
        showSaved = true
        hideSavedTask?.cancel()
        hideSavedTask = Task {
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            showSaved = false
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
