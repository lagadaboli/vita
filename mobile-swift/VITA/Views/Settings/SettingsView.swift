import SwiftUI
import VITADesignSystem
#if canImport(UIKit)
import UIKit
#endif

struct SettingsView: View {
    var appState: AppState
    @State private var healthKitEnabled = true
    @State private var doordashEnabled = true
    @State private var rotimaticEnabled = true
    @State private var instantPotEnabled = true
    @State private var showingExportSheet = false
    @State private var showManualScreenTimeHelp = false

    private var isScreenTimeAuthorized: Bool {
        if case .authorized = appState.screenTimeStatus {
            return true
        }
        return false
    }

    private var screenTimeStatusText: String {
        switch appState.screenTimeStatus {
        case .authorized:
            return "Connected"
        case .notConfigured:
            return "Not connected"
        case .unavailable(let reason):
            return reason
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("HealthKit") {
                    Toggle("HealthKit Access", isOn: $healthKitEnabled)
                        .tint(VITAColors.teal)

                    HStack {
                        Text("Data Types")
                        Spacer()
                        Text("8 types")
                            .foregroundStyle(VITAColors.textSecondary)
                    }

                    HStack {
                        Text("Sync Frequency")
                        Spacer()
                        Text("Background")
                            .foregroundStyle(VITAColors.textSecondary)
                    }
                }

                Section("Screen Time") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(screenTimeStatusText)
                            .foregroundStyle(isScreenTimeAuthorized ? VITAColors.success : VITAColors.textSecondary)
                    }

                    Button {
                        openScreenTimeSystemSettings()
                    } label: {
                        HStack(spacing: VITASpacing.sm) {
                            Image(systemName: isScreenTimeAuthorized ? "gearshape" : "hourglass")
                            Text(isScreenTimeAuthorized ? "Manage Screen Time Access" : "Enable Screen Time Access")
                        }
                    }

                    if !isScreenTimeAuthorized {
                        Text("If permission stays denied, use iPhone Settings > Screen Time > Apps with Screen Time Access > VITA.")
                            .font(VITATypography.caption)
                            .foregroundStyle(VITAColors.textSecondary)
                    }
                }

                Section("Integrations") {
                    Toggle("DoorDash", isOn: $doordashEnabled)
                        .tint(VITAColors.teal)
                    Toggle("Rotimatic NEXT", isOn: $rotimaticEnabled)
                        .tint(VITAColors.teal)
                    Toggle("Instant Pot", isOn: $instantPotEnabled)
                        .tint(VITAColors.teal)
                }

                Section("Privacy") {
                    HStack {
                        Image(systemName: "lock.shield")
                            .foregroundStyle(VITAColors.teal)
                        Text("All data stored on-device")
                    }

                    HStack {
                        Image(systemName: "icloud.slash")
                            .foregroundStyle(VITAColors.teal)
                        Text("No raw health data leaves device")
                    }

                    NavigationLink {
                        PrivacyDetailView()
                    } label: {
                        Text("Privacy Policy")
                    }
                }

                Section("Data") {
                    Button("Export Health Data") {
                        showingExportSheet = true
                    }

                    NavigationLink {
                        CausalPatternsView(appState: appState)
                    } label: {
                        Text("Causal Patterns")
                    }

                    HStack {
                        Text("Database Size")
                        Spacer()
                        Text("Sample Data")
                            .foregroundStyle(VITAColors.textSecondary)
                    }
                }

                Section("Developer") {
                    HStack {
                        Text("Engine")
                        Spacer()
                        Text("Mock (Sample Data)")
                            .font(VITATypography.caption)
                            .foregroundStyle(VITAColors.amber)
                    }

                    HStack {
                        Text("Data Source")
                        Spacer()
                        Text("7-day generated dataset")
                            .font(VITATypography.caption)
                            .foregroundStyle(VITAColors.textSecondary)
                    }

                    HStack {
                        Text("Version")
                        Spacer()
                        Text("0.1.0 (alpha)")
                            .foregroundStyle(VITAColors.textSecondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Open Screen Time Manually", isPresented: $showManualScreenTimeHelp) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Go to iPhone Settings > Screen Time > Apps with Screen Time Access > VITA.")
            }
        }
    }

    private func openScreenTimeSystemSettings() {
        #if canImport(UIKit)
        let candidates = [
            URL(string: "App-prefs:SCREEN_TIME&path=APPS_WITH_SCREEN_TIME_ACCESS"),
            URL(string: "App-prefs:root=SCREEN_TIME&path=APPS_WITH_SCREEN_TIME_ACCESS"),
            URL(string: "App-prefs:SCREEN_TIME"),
            URL(string: "App-prefs:root=SCREEN_TIME"),
            URL(string: "App-prefs:"),
        ].compactMap { $0 }
        openSettingsCandidate(candidates)
        #endif
    }

    private func openSettingsCandidate(_ candidates: [URL]) {
        guard let url = candidates.first else { return }
        UIApplication.shared.open(url, options: [:]) { opened in
            if !opened {
                let remaining = Array(candidates.dropFirst())
                if remaining.isEmpty {
                    showManualScreenTimeHelp = true
                } else {
                    openSettingsCandidate(remaining)
                }
            }
        }
    }
}

struct PrivacyDetailView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VITASpacing.lg) {
                Text("Privacy by Design")
                    .font(VITATypography.title2)

                Text("VITA processes all health data entirely on your device. No raw health data — glucose readings, heart rate, HRV, sleep stages, or meal information — ever leaves your iPhone.")
                    .font(VITATypography.body)

                Text("Anonymized Causal Patterns")
                    .font(VITATypography.headline)

                Text("The only data eligible for cloud sync are anonymized causal patterns — statistical relationships between categories of events (e.g., 'high-GI meal correlates with glucose spike'). These contain no timestamps, food names, or personally identifiable information.")
                    .font(VITATypography.body)

                Text("A pattern must have at least 5 observations and a strength threshold of 0.6 before becoming sync-eligible, preventing re-identification through uniqueness.")
                    .font(VITATypography.body)
                    .foregroundStyle(VITAColors.textSecondary)
            }
            .padding(VITASpacing.lg)
        }
        .navigationTitle("Privacy")
    }
}

struct CausalPatternsView: View {
    var appState: AppState

    var body: some View {
        List {
            Section("Discovered Patterns") {
                Text("high_gi_meal -> glucose_spike > 160 -> hrv_suppression")
                    .font(VITATypography.caption)
                Text("white_flour -> glucose_spike -> reactive_hypoglycemia")
                    .font(VITATypography.caption)
                Text("slow_cook_legumes -> lectin_retention -> gi_distress")
                    .font(VITATypography.caption)
                Text("late_meal_>21h -> reduced_deep_sleep")
                    .font(VITATypography.caption)
                Text("passive_screen > 40min -> dopamine_debt > 70")
                    .font(VITATypography.caption)
            }
        }
        .navigationTitle("Causal Patterns")
    }
}
