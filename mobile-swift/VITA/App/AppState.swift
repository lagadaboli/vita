import SwiftUI
import VITACore
import CausalityEngine

@MainActor
@Observable
final class AppState {
    enum MockDataScenario: String, CaseIterable, Identifiable {
        case doordashAndInstacartNotPositive
        case bodyScaleNotGood
        case screenTimeNotGood
        case allDataLooksGood

        var id: String { rawValue }

        var title: String {
            switch self {
            case .doordashAndInstacartNotPositive:
                return "Meals & Grocery Not Positive"
            case .bodyScaleNotGood:
                return "Body Scale Not Good"
            case .screenTimeNotGood:
                return "Screen Time Not Good"
            case .allDataLooksGood:
                return "All Data Looks Good"
            }
        }

        var subtitle: String {
            switch self {
            case .doordashAndInstacartNotPositive:
                return "DoorDash and Instacart trends look metabolically rough."
            case .bodyScaleNotGood:
                return "Weight trend and body metrics indicate poor progress."
            case .screenTimeNotGood:
                return "Passive usage, pickups, and sessions suggest overload."
            case .allDataLooksGood:
                return "Meals, body metrics, and behavior stay in healthy ranges."
            }
        }
    }

    enum AppTab: Hashable {
        case dashboard
        case askVITA
        case integrations
        case timeline
        case skinAudit
        case settings
    }

    let database: VITADatabase
    let healthGraph: HealthGraph
    let causalityEngine: CausalityEngine
    var isLoaded = false
    var loadError: String?
    var selectedTab: AppTab = .dashboard
    var askVITADraftQuestion: String?
    var selectedMockScenario: MockDataScenario {
        didSet {
            UserDefaults.standard.set(selectedMockScenario.rawValue, forKey: Self.mockScenarioDefaultsKey)
        }
    }

    private static let mockScenarioDefaultsKey = "vita.mock_data_scenario"

    init() {
        let storedScenario = UserDefaults.standard.string(forKey: Self.mockScenarioDefaultsKey)
        self.selectedMockScenario = MockDataScenario(rawValue: storedScenario ?? "") ?? .allDataLooksGood
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
        refreshIntegrationMockHistory()
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

    func applyMockScenario(_ scenario: MockDataScenario) {
        guard selectedMockScenario != scenario else { return }
        selectedMockScenario = scenario
        refreshIntegrationMockHistory()
    }

    func refreshIntegrationMockHistory() {
        let integrationsVM = IntegrationsViewModel()
        integrationsVM.load(from: self)
    }
}
