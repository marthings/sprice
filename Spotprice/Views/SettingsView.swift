//
//  SettingsView.swift
//  Spotprice
//
//  Settings window for consumption configuration

import SwiftUI
import WidgetKit

struct SettingsView: View {
    @Bindable var settings = ConsumptionSettings.shared
    @State private var selectedPriceArea = "SE3"
    @State private var connectionStatus: ConnectionStatus = .unknown
    @State private var availableDSOs: [DSOOption] = []
    @State private var isLoadingDSOs = false
    @State private var dsoLoadError: String?

    private let priceAreas = ["SE1", "SE2", "SE3", "SE4"]
    private let gridTariffService = GridTariffService()

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    // Prisområde
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        Text("Prisområde")
                            .font(DS.Font.bold(12))
                            .foregroundStyle(.primary)

                        Picker("", selection: $selectedPriceArea) {
                            ForEach(priceAreas, id: \.self) { area in
                                Text(area).tag(area)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.palette)
                        .onChange(of: selectedPriceArea) { _, newValue in
                            settings.priceArea = newValue
                            NotificationCenter.default.post(name: .consumptionSettingsDidSave, object: nil)
                            WidgetCenter.shared.reloadAllTimelines()
                        }

                        Text("Välj ditt elområde i Sverige")
                            .font(DS.Font.micro)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    // Provider selection
                    ProviderPicker(selectedProviderId: $settings.selectedProviderId)
                        .onChange(of: settings.selectedProviderId) { _, _ in
                            connectionStatus = .unknown
                        }

                    Divider()
                    
                    // Nätägare (DSO) selection
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        Text("Nätägare (DSO)")
                            .font(DS.Font.bold(12))
                            .foregroundStyle(.primary)
                        
                        if isLoadingDSOs {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Laddar nätägare...")
                                    .font(DS.Font.regular(11))
                                    .foregroundStyle(.secondary)
                            }
                        } else if let error = dsoLoadError {
                            Text(error)
                                .foregroundStyle(DS.Color.danger)
                                .font(DS.Font.regular(11))
                        } else {
                            Picker("Välj nätägare", selection: $settings.selectedDSOOrgNo) {
                                Text("Ingen vald").tag("")
                                ForEach(availableDSOs) { dso in
                                    Text(dso.name).tag(dso.id)
                                }
                            }
                            .pickerStyle(.menu)
                            .onChange(of: settings.selectedDSOOrgNo) { _, _ in
                                NotificationCenter.default.post(name: .consumptionSettingsDidSave, object: nil)
                            }
                            
                            if !settings.selectedDSOOrgNo.isEmpty,
                               let selectedDSO = availableDSOs.first(where: { $0.id == settings.selectedDSOOrgNo }) {
                                Text("Nätavgifter från \(selectedDSO.name) läggs till i kostnadsberäkningar")
                                    .font(DS.Font.regular(11))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Välj din nätägare för att få fullständiga kostnadsberäkningar inklusive nätavgifter")
                                    .font(DS.Font.regular(11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .task {
                        await loadDSOs()
                    }

                    Divider()
                    
                    // Fuse size selection
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        Text("Huvudsäkring")
                            .font(DS.Font.bold(12))
                            .foregroundStyle(.primary)
                        
                        Picker("Välj säkringsstorlek", selection: $settings.fuseSize) {
                            Text("16A").tag(16)
                            Text("20A").tag(20)
                            Text("25A").tag(25)
                            Text("35A").tag(35)
                            Text("50A").tag(50)
                            Text("63A").tag(63)
                        }
                        .pickerStyle(.menu)
                        .onChange(of: settings.fuseSize) { _, _ in
                            NotificationCenter.default.post(name: .consumptionSettingsDidSave, object: nil)
                        }
                        
                        Text("Din huvudsäkrings storlek påverkar den fasta månadsavgiften från nätägaren")
                            .font(DS.Font.regular(11))
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    // Provider-specific credential fields
                    ProviderCredentialsSection(
                        settings: settings,
                        providerId: settings.selectedProviderId
                    )
                    
                    Divider()
                    
                    // Electricity provider costs (metadata-driven)
                    ElhandelSection(settings: settings)
                    
                    Divider()
                    
                    // Swedish taxes and fees (informational)
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        Text("Skatter & Avgifter")
                            .font(DS.Font.bold(12))
                            .foregroundStyle(.primary)
                        
                        HStack {
                            Text("Energiskatt:")
                                .font(DS.Font.regular(11))
                            Spacer()
                            // Show energiskatt based on selected DSO (Jönköping has 45 öre from 2026)
                            Text(energyTaxText)
                                .font(DS.Font.regular(11))
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack {
                            Text("Elcertifikat:")
                                .font(DS.Font.regular(11))
                            Spacer()
                            Text("1,75 öre/kWh")
                                .font(DS.Font.regular(11))
                                .foregroundStyle(.secondary)
                        }
                        
                        Text(taxInfoText)
                            .font(DS.Font.regular(11))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(DS.Spacing.lg)
            }

            // Sticky Footer
            VStack(spacing: 0) {
                Divider()
                
                HStack(spacing: 8) {
                    Group {
                        switch connectionStatus {
                        case .unknown:
                            if settings.isConfigured {
                                Label("Verifiera dina uppgifter genom att spara", systemImage: "questionmark.circle.fill")
                                    .foregroundStyle(DS.Color.warning)
                            } else {
                                Label("Ej konfigurerad", systemImage: "exclamationmark.circle.fill")
                                    .foregroundStyle(DS.Color.warning)
                            }
                        case .testing:
                            HStack(spacing: 4) {
                                ProgressView().scaleEffect(0.7)
                                Text("Testar...")
                            }
                            .foregroundStyle(.secondary)
                        case .connected:
                            Label("Kopplad!", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(DS.Color.success)
                        case .failed(let message):
                            Label(message, systemImage: "xmark.circle.fill")
                                .foregroundStyle(DS.Color.danger)
                        }
                    }
                    .font(DS.Font.caption)

                    Spacer()

                    Button {
                        Task {
                            connectionStatus = .testing
                            do {
                                try await ConsumptionService().testConnection()
                                connectionStatus = .connected
                                NotificationCenter.default.post(name: .consumptionSettingsDidSave, object: nil)
                                WidgetCenter.shared.reloadAllTimelines()
                            } catch {
                                connectionStatus = .failed(error.localizedDescription)
                            }
                        }
                    } label: {
                        Text("Spara")
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.vertical, DS.Spacing.sm)
                            .font(DS.Font.bold(12))
                            .foregroundStyle(.white)
                            .background(DS.Color.brand, in: .rect(cornerRadius: DS.Radius.md))
                    }
                    .buttonStyle(.plain)
                    .disabled(!settings.isConfigured || connectionStatus == .testing)
                }
                .padding(DS.Spacing.lg)
                .background(.background)
            }
        }
        .frame(width: DS.Size.settingsWidth, height: 520)
        .onAppear {
            selectedPriceArea = settings.priceArea
        }
    }
    
    // MARK: - Computed Properties
    
    private var energyTaxText: String {
        // Jönköping has reduced energy tax from 2026
        if settings.selectedDSOOrgNo == "jonkoping" {
            return "45,0 öre/kWh"
        }
        return "54,88 öre/kWh"
    }
    
    private var taxInfoText: String {
        if settings.selectedDSOOrgNo == "jonkoping" {
            return "Energiskatt sänktes till 45 öre/kWh från januari 2026"
        }
        return "Svenska standardvärden 2025 (ingår automatiskt i beräkningar)"
    }
    
    // MARK: - Helper Methods
    
    private func loadDSOs() async {
        isLoadingDSOs = true
        dsoLoadError = nil
        
        do {
            availableDSOs = try await gridTariffService.fetchAvailableDSOs()
        } catch {
            dsoLoadError = "Kunde inte ladda nätägare: \(error.localizedDescription)"
        }
        
        isLoadingDSOs = false
    }
}

#Preview {
    SettingsView()
}
