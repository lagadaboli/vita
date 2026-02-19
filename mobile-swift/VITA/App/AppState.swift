import SwiftUI
import VITACore
import CausalityEngine

@MainActor
@Observable
final class AppState {
    let database: VITADatabase
    let healthGraph: HealthGraph
    let causalityEngine: CausalityEngine
    var isLoaded = false
    var loadError: String?

    init() {
        do {
            let db = try VITADatabase.inMemory()
            self.database = db
            self.healthGraph = HealthGraph(database: db)
            self.causalityEngine = CausalityEngine(database: db, healthGraph: healthGraph)
        } catch {
            fatalError("Failed to initialize database: \(error)")
        }
    }

    func initialize() async {
        guard !isLoaded else { return }
        loadSampleData()
        isLoaded = true
    }

    func loadSampleData() {
        do {
            let generator = SampleDataGenerator(database: database, healthGraph: healthGraph)
            try generator.generateAll()
        } catch {
            loadError = error.localizedDescription
        }
    }
}
