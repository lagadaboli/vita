import Foundation

struct ReportAnswers {
    var primaryConcern: String = "Glucose Management"
    var sleepQuality: String = "Fair"
    var digestiveIssues: String = "None"
    var exerciseFrequency: String = "1–2 days"
    var providerGoal: String = "Review Data & Trends"
}

@MainActor
@Observable
final class HealthReportViewModel {

    // MARK: - State

    enum GenerationState: Equatable {
        case idle
        case generatingDocument
        case optimizingPDF
        case complete
        case error(String)
    }

    var answers = ReportAnswers()
    var state: GenerationState = .idle
    var pdfData: Data?
    var isShowingShareSheet = false

    // MARK: - Computed

    var formattedFileSize: String {
        guard let data = pdfData else { return "" }
        let bytes = data.count
        if bytes < 1_024 { return "\(bytes) B" }
        if bytes < 1_024 * 1_024 { return String(format: "%.1f KB", Double(bytes) / 1_024) }
        return String(format: "%.1f MB", Double(bytes) / (1_024 * 1_024))
    }

    // MARK: - Questions metadata

    static let questions: [(question: String, options: [String])] = [
        (
            "What is your primary health concern?",
            ["Glucose Management", "Weight", "Sleep Quality", "Energy Levels", "Skin Health", "Digestive Health"]
        ),
        (
            "How has your sleep been recently?",
            ["Poor", "Fair", "Good", "Excellent"]
        ),
        (
            "Any digestive symptoms?",
            ["None", "Occasional", "Frequent", "Chronic"]
        ),
        (
            "How often did you exercise this week?",
            ["None", "1–2 days", "3–4 days", "5+ days"]
        ),
        (
            "What is your goal for this provider visit?",
            ["Review Data & Trends", "Dietary Guidance", "Sleep Improvement", "Holistic Health Review"]
        ),
    ]

    // MARK: - Actions

    func generate(appState: AppState, dashVM: DashboardViewModel, skinVM: SkinHealthViewModel) {
        state = .generatingDocument
        pdfData = nil

        Task {
            do {
                let config = FoxitConfig.current

                let values = HealthReportService.buildDocumentValues(
                    appState: appState,
                    dashVM: dashVM,
                    skinVM: skinVM,
                    answers: answers
                )
                let templateBase64 = DocxTemplateBuilder.build().base64EncodedString()
                let rawPDF = try await FoxitDocumentGenerationService.generate(
                    templateBase64: templateBase64,
                    values: values,
                    config: config
                )

                state = .optimizingPDF

                let optimizedPDF = try await FoxitPDFServicesService.optimize(pdfData: rawPDF, config: config)
                pdfData = optimizedPDF
                state = .complete
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }

    func reset() {
        state = .idle
        pdfData = nil
        isShowingShareSheet = false
    }
}
