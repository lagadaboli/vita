import Foundation

struct HealthReportService {

    // MARK: - Document value models

    struct DocumentValues: Encodable {
        let reportDate: String
        let reportId: String
        let primaryConcern: String
        let sleepQuality: String
        let digestiveIssues: String
        let exerciseFrequency: String
        let providerGoal: String
        let healthScore: String
        let hrv: String
        let heartRate: String
        let glucose: String
        let sleepHours: String
        let steps: String
        let skinScore: String
        let recentMeals: [MealRow]
        let skinConditions: [SkinConditionRow]
        let causalFindings: [CausalFindingRow]
        let recommendations: [RecommendationRow]

        struct MealRow: Encodable {
            let meal: String
            let source: String
            let glycemicLoad: String
            let impact: String
        }

        struct SkinConditionRow: Encodable {
            let condition: String
            let severity: String
            let zone: String
            let confidence: String
        }

        struct CausalFindingRow: Encodable {
            let finding: String
            let detail: String
            let source: String
        }

        struct RecommendationRow: Encodable {
            let rec: String
        }
    }

    // MARK: - Build document values

    @MainActor
    static func buildDocumentValues(
        appState: AppState,
        dashVM: DashboardViewModel,
        skinVM: SkinHealthViewModel,
        answers: ReportAnswers
    ) -> DocumentValues {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none

        let idFormatter = DateFormatter()
        idFormatter.dateFormat = "yyyyMMdd-HHmmss"

        let now = Date()

        let skinScore = skinVM.analysisResult.map { "\($0.overallScore)" } ?? "72"

        let skinConditionRows: [DocumentValues.SkinConditionRow]
        if let result = skinVM.analysisResult {
            skinConditionRows = result.conditions.map { condition in
                DocumentValues.SkinConditionRow(
                    condition: condition.type.rawValue.capitalized,
                    severity: String(format: "%.0f%%", condition.severity * 100),
                    zone: condition.affectedZones.map(\.rawValue).joined(separator: ", "),
                    confidence: String(format: "%.0f%%", condition.confidence * 100)
                )
            }
        } else {
            skinConditionRows = defaultSkinConditions()
        }

        let causalFindingRows: [DocumentValues.CausalFindingRow]
        if !skinVM.causalFindings.isEmpty {
            causalFindingRows = skinVM.causalFindings.map { finding in
                DocumentValues.CausalFindingRow(
                    finding: finding.cause,
                    detail: finding.detail,
                    source: finding.source
                )
            }
        } else {
            causalFindingRows = defaultCausalFindings()
        }

        let recommendationRows: [DocumentValues.RecommendationRow]
        if !skinVM.recommendations.isEmpty {
            recommendationRows = skinVM.recommendations.map { DocumentValues.RecommendationRow(rec: $0) }
        } else {
            recommendationRows = defaultRecommendations()
        }

        return DocumentValues(
            reportDate: dateFormatter.string(from: now),
            reportId: "VITA-\(idFormatter.string(from: now))",
            primaryConcern: answers.primaryConcern,
            sleepQuality: answers.sleepQuality,
            digestiveIssues: answers.digestiveIssues,
            exerciseFrequency: answers.exerciseFrequency,
            providerGoal: answers.providerGoal,
            healthScore: String(format: "%.0f", dashVM.healthScore),
            hrv: "\(Int(dashVM.currentHRV.rounded())) ms",
            heartRate: "\(Int(dashVM.currentHR.rounded())) bpm",
            glucose: "\(Int(dashVM.currentGlucose.rounded())) mg/dL",
            sleepHours: String(format: "%.1f hrs", dashVM.sleepHours),
            steps: "\(dashVM.steps)",
            skinScore: skinScore,
            recentMeals: mockRecentMeals(),
            skinConditions: skinConditionRows,
            causalFindings: causalFindingRows,
            recommendations: recommendationRows
        )
    }

    // MARK: - Full generation pipeline

    @MainActor
    static func generateReport(
        appState: AppState,
        dashVM: DashboardViewModel,
        skinVM: SkinHealthViewModel,
        answers: ReportAnswers,
        config: FoxitConfig
    ) async throws -> Data {
        let values = buildDocumentValues(appState: appState, dashVM: dashVM, skinVM: skinVM, answers: answers)
        let templateBase64 = DocxTemplateBuilder.build().base64EncodedString()
        let rawPDF = try await FoxitDocumentGenerationService.generate(
            templateBase64: templateBase64,
            values: values,
            config: config
        )
        return try await FoxitPDFServicesService.optimize(pdfData: rawPDF, config: config)
    }

    // MARK: - Mock / fallback data

    private static func mockRecentMeals() -> [DocumentValues.MealRow] {
        [
            DocumentValues.MealRow(
                meal: "Chole Bhature",
                source: "DoorDash",
                glycemicLoad: "42",
                impact: "High spike (+48 mg/dL)"
            ),
            DocumentValues.MealRow(
                meal: "Aloo Paratha",
                source: "Rotimatic NEXT",
                glycemicLoad: "38",
                impact: "Moderate spike (+32 mg/dL)"
            ),
            DocumentValues.MealRow(
                meal: "Paneer Butter Masala",
                source: "DoorDash",
                glycemicLoad: "28",
                impact: "Moderate spike (+25 mg/dL)"
            ),
            DocumentValues.MealRow(
                meal: "Poha",
                source: "Home",
                glycemicLoad: "18",
                impact: "Low spike (+12 mg/dL)"
            ),
        ]
    }

    private static func defaultSkinConditions() -> [DocumentValues.SkinConditionRow] {
        [
            DocumentValues.SkinConditionRow(
                condition: "Acne",
                severity: "65%",
                zone: "Forehead, Chin",
                confidence: "87%"
            ),
            DocumentValues.SkinConditionRow(
                condition: "Dark Circles",
                severity: "48%",
                zone: "Under Eyes",
                confidence: "79%"
            ),
        ]
    }

    private static func defaultCausalFindings() -> [DocumentValues.CausalFindingRow] {
        [
            DocumentValues.CausalFindingRow(
                finding: "High-GL Late Meal",
                detail: "Late DoorDash order elevated IGF-1, triggering sebum overproduction within 48h",
                source: "DoorDash"
            ),
            DocumentValues.CausalFindingRow(
                finding: "Zombie Scroll Session",
                detail: "45-min blue-light exposure suppressed melatonin by ~50%, increasing periorbital fluid retention",
                source: "Screen Time"
            ),
            DocumentValues.CausalFindingRow(
                finding: "HRV Suppression",
                detail: "HRV averaged below 40 ms over 3 days — impaired lymphatic drainage correlates with skin inflammation",
                source: "Apple Watch"
            ),
        ]
    }

    private static func defaultRecommendations() -> [DocumentValues.RecommendationRow] {
        [
            DocumentValues.RecommendationRow(rec: "Avoid DoorDash orders after 8 PM for 7 days"),
            DocumentValues.RecommendationRow(rec: "Set Screen Time limit: ≤30 min social media after 9 PM"),
            DocumentValues.RecommendationRow(rec: "Switch to Bajra/Jowar Rotis — lower GI reduces sebum by ~30%"),
            DocumentValues.RecommendationRow(rec: "Use Pressure Cook mode in Instant Pot — 95% lectin deactivation"),
        ]
    }
}
