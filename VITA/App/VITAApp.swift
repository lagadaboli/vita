import SwiftUI

/// VITA — Personal Health Causality Engine
/// Main app entry point. Initializes the HealthKit bridge and displays the dashboard.
@main
struct VITAApp: App {
    var body: some Scene {
        WindowGroup {
            DashboardView()
        }
    }
}
