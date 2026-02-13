import SwiftUI

/// Minimal dashboard showing HealthKit permission status and last synced metrics.
struct DashboardView: View {
    @State private var healthKitAuthorized = false
    @State private var lastSyncDate: Date?

    var body: some View {
        NavigationStack {
            List {
                Section("HealthKit Status") {
                    HStack {
                        Text("Authorization")
                        Spacer()
                        Text(healthKitAuthorized ? "Granted" : "Not Requested")
                            .foregroundStyle(healthKitAuthorized ? .green : .secondary)
                    }

                    if let lastSync = lastSyncDate {
                        HStack {
                            Text("Last Sync")
                            Spacer()
                            Text(lastSync, style: .relative)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !healthKitAuthorized {
                        Button("Request HealthKit Access") {
                            requestHealthKitAccess()
                        }
                    }
                }

                Section("Metrics") {
                    MetricRow(name: "HRV (SDNN)", value: "—", unit: "ms")
                    MetricRow(name: "Resting HR", value: "—", unit: "bpm")
                    MetricRow(name: "Blood Glucose", value: "—", unit: "mg/dL")
                    MetricRow(name: "Sleep", value: "—", unit: "hrs")
                }

                Section("Causality Engine") {
                    Text("Collecting baseline data...")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("VITA")
        }
    }

    private func requestHealthKitAccess() {
        // Will connect to HealthKitManager
    }
}

struct MetricRow: View {
    let name: String
    let value: String
    let unit: String

    var body: some View {
        HStack {
            Text(name)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .monospacedDigit()
            Text(unit)
                .foregroundStyle(.secondary)
                .font(.caption)
        }
    }
}
