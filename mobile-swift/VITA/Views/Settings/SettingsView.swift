import SwiftUI
import VITADesignSystem

struct SettingsView: View {
    var appState: AppState

    var body: some View {
        NavigationStack {
            List {
                Section("Integrations") {
                    HStack {
                        Text("DoorDash")
                        Spacer()
                        Text("Mock data")
                            .foregroundStyle(VITAColors.textSecondary)
                    }
                    HStack {
                        Text("Instacart")
                        Spacer()
                        Text("Mock data")
                            .foregroundStyle(VITAColors.textSecondary)
                    }
                    HStack {
                        Text("Rotimatic NEXT")
                        Spacer()
                        Text("Mock data")
                            .foregroundStyle(VITAColors.textSecondary)
                    }
                    HStack {
                        Text("Instant Pot")
                        Spacer()
                        Text("Mock data")
                            .foregroundStyle(VITAColors.textSecondary)
                    }
                }

                Section("Ask VITA AI") {
                    NavigationLink {
                        GeminiCredentialsView()
                    } label: {
                        Text("Gemini API Key")
                    }

                    HStack {
                        Text("AI Chat Status")
                        Spacer()
                        if GeminiConfig.current.isConfigured {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.caption)
                                Text("Gemini \(GeminiConfig.current.model.replacingOccurrences(of: "gemini-", with: ""))")
                            }
                            .foregroundStyle(VITAColors.success)
                        } else {
                            Text("Using engine templates")
                                .foregroundStyle(VITAColors.amber)
                        }
                    }
                }

                Section("Foxit Report APIs") {
                    NavigationLink {
                        FoxitCredentialsView()
                    } label: {
                        Text("Foxit API Credentials (2 Apps)")
                    }

                    HStack {
                        Text("API Status")
                        Spacer()
                        if FoxitConfig.current.isConfigured {
                            Text("Ready")
                                .foregroundStyle(VITAColors.success)
                        } else {
                            Text("Missing credentials")
                                .foregroundStyle(VITAColors.amber)
                        }
                    }
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
                    NavigationLink {
                        CausalPatternsView(appState: appState)
                    } label: {
                        Text("Causal Patterns")
                    }

                    HStack {
                        Text("Database")
                        Spacer()
                        Text("In-memory (sample data)")
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
