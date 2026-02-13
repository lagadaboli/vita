import SwiftUI
import VITACore
import CausalityEngine

/// Central app state managing database, health graph, and causality engine.
@MainActor
@Observable
final class AppState {
    let database: VITADatabase
    let healthGraph: HealthGraph
    let causalityEngine: MockCausalityEngine
    var isLoaded = false
    var loadError: String?

    init() {
        do {
            let db = try VITADatabase.inMemory()
            self.database = db
            self.healthGraph = HealthGraph(database: db)
            self.causalityEngine = MockCausalityEngine(database: db, healthGraph: healthGraph)
        } catch {
            fatalError("Failed to initialize database: \(error)")
        }
    }

    func loadSampleData() {
        guard !isLoaded else { return }
        do {
            let generator = SampleDataGenerator(database: database, healthGraph: healthGraph)
            try generator.generateAll()
            isLoaded = true
        } catch {
            loadError = error.localizedDescription
        }
    }
}
