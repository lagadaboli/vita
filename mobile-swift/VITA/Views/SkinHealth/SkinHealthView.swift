import SwiftUI
import VITADesignSystem

struct SkinHealthView: View {
    var appState: AppState
    @State private var viewModel = SkinHealthViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: VITASpacing.xl) {
                    switch viewModel.state {
                    case .idle:
                        idleState
                    case .analyzing:
                        analyzingState
                    case .complete:
                        if let result = viewModel.analysisResult {
                            resultsView(result: result)
                        }
                    }
                }
                .padding(.horizontal, VITASpacing.lg)
                .padding(.vertical, VITASpacing.md)
                .padding(.bottom, VITASpacing.xxl)
            }
            .background(VITAColors.background)
            .navigationTitle("Skin Audit")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if viewModel.state == .complete {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Re-Analyse") { viewModel.analyze() }
                            .font(VITATypography.caption)
                            .tint(VITAColors.teal)
                    }
                }
            }
        }
    }

    // MARK: - Idle state

    private var idleState: some View {
        VStack(spacing: VITASpacing.xl) {
            VStack(spacing: VITASpacing.md) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 56))
                    .foregroundStyle(VITAColors.teal)
                    .padding(.top, VITASpacing.xxl)

                Text("AI Skin Health Audit")
                    .font(VITATypography.title2)
                    .foregroundStyle(VITAColors.textPrimary)

                Text("VITA analyses your skin to detect pimples, dark circles, redness and oiliness — then traces each finding back to your meals, sleep, and screen habits.")
                    .font(VITATypography.body)
                    .foregroundStyle(VITAColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: VITASpacing.sm) {
                featureBullet("viewfinder.circle.fill", "PerfectCorp AI face heatmap overlay")
                featureBullet("heart.text.clipboard",  "Causal link to meals, HRV & screen time")
                featureBullet("chart.line.uptrend.xyaxis", "7-day skin improvement forecast")
                featureBullet("lock.shield",           "All processing on-device — no data leaves iPhone")
            }
            .padding(VITASpacing.cardPadding)
            .background(VITAColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))

            Button { viewModel.analyze() } label: {
                HStack(spacing: VITASpacing.sm) {
                    Image(systemName: "camera.fill")
                    Text("Start Skin Audit  (Demo Mode)")
                        .font(VITATypography.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, VITASpacing.md)
                .background(VITAColors.teal)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Analysing state

    private var analyzingState: some View {
        VStack(spacing: VITASpacing.lg) {
            Spacer().frame(height: VITASpacing.xxl)

            ProgressView()
                .progressViewStyle(.circular)
                .tint(VITAColors.teal)
                .scaleEffect(1.4)

            VStack(spacing: VITASpacing.xs) {
                Text("Analysing skin zones…")
                    .font(VITATypography.headline)
                    .foregroundStyle(VITAColors.textPrimary)
                Text("PerfectCorp AI processing 6 facial regions")
                    .font(VITATypography.caption)
                    .foregroundStyle(VITAColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Results

    @ViewBuilder
    private func resultsView(result: PerfectCorpService.AnalysisResult) -> some View {
        // Skin score header
        skinScoreCard(score: result.overallScore)

        // Heatmap + HRV chart — side by side
        HStack(alignment: .top, spacing: VITASpacing.md) {
            FaceHeatmapView(conditions: result.conditions)
                .frame(maxWidth: .infinity)
            HRVStressChartView(readings: viewModel.hrvReadings)
                .frame(maxWidth: .infinity)
        }
        .frame(height: 220)

        // Detected conditions
        if !result.conditions.isEmpty {
            VStack(alignment: .leading, spacing: VITASpacing.sm) {
                Text("Detected Conditions")
                    .font(VITATypography.title3)

                ForEach(result.conditions) { condition in
                    SkinConditionCard(
                        condition: condition,
                        findings: viewModel.causalFindings.filter { $0.conditionType == condition.type }
                    )
                }
            }
        } else {
            noConditionsCard
        }

        // 7-day forecast
        SevenDayForecastView(forecastPoints: viewModel.forecastPoints, score: result.overallScore)

        // Recommendations
        if !viewModel.recommendations.isEmpty {
            recommendationsCard
        }
    }

    // MARK: - Sub-cards

    private func skinScoreCard(score: Int) -> some View {
        HStack(spacing: VITASpacing.lg) {
            ZStack {
                Circle()
                    .stroke(scoreColor(score).opacity(0.18), lineWidth: 6)
                    .frame(width: 72, height: 72)
                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100)
                    .stroke(scoreColor(score), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 72, height: 72)
                VStack(spacing: 0) {
                    Text("\(score)")
                        .font(VITATypography.metricSmall)
                        .foregroundStyle(scoreColor(score))
                    Text("/100")
                        .font(.system(size: 10))
                        .foregroundStyle(VITAColors.textTertiary)
                }
            }

            VStack(alignment: .leading, spacing: VITASpacing.xs) {
                Text(scoreLabel(score))
                    .font(VITATypography.headline)
                    .foregroundStyle(VITAColors.textPrimary)
                Text("Overall Skin Health Score")
                    .font(VITATypography.caption)
                    .foregroundStyle(VITAColors.textSecondary)
                Text("Powered by PerfectCorp YouCam AI")
                    .font(VITATypography.caption2)
                    .foregroundStyle(VITAColors.textTertiary)
            }

            Spacer()
        }
        .padding(VITASpacing.cardPadding)
        .background(VITAColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
    }

    private var noConditionsCard: some View {
        HStack(spacing: VITASpacing.md) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title2)
                .foregroundStyle(VITAColors.success)
            VStack(alignment: .leading, spacing: VITASpacing.xs) {
                Text("No significant conditions detected")
                    .font(VITATypography.headline)
                    .foregroundStyle(VITAColors.textPrimary)
                Text("Your skin looks great today — keep up your current routine.")
                    .font(VITATypography.caption)
                    .foregroundStyle(VITAColors.textSecondary)
            }
        }
        .padding(VITASpacing.cardPadding)
        .background(VITAColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
    }

    private var recommendationsCard: some View {
        VStack(alignment: .leading, spacing: VITASpacing.md) {
            HStack(spacing: VITASpacing.xs) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(VITAColors.amber)
                Text("Recommendations")
                    .font(VITATypography.title3)
            }

            ForEach(Array(viewModel.recommendations.enumerated()), id: \.offset) { _, rec in
                HStack(alignment: .top, spacing: VITASpacing.sm) {
                    Circle()
                        .fill(VITAColors.teal)
                        .frame(width: 6, height: 6)
                        .padding(.top, 5)
                    Text(rec)
                        .font(VITATypography.caption)
                        .foregroundStyle(VITAColors.textSecondary)
                }
            }
        }
        .padding(VITASpacing.cardPadding)
        .background(VITAColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
    }

    // MARK: - Helpers

    private func featureBullet(_ icon: String, _ text: String) -> some View {
        HStack(spacing: VITASpacing.sm) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(VITAColors.teal)
                .frame(width: 24)
            Text(text)
                .font(VITATypography.callout)
                .foregroundStyle(VITAColors.textSecondary)
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 75 { return VITAColors.success }
        if score >= 55 { return VITAColors.amber }
        return VITAColors.coral
    }

    private func scoreLabel(_ score: Int) -> String {
        if score >= 80 { return "Excellent" }
        if score >= 65 { return "Good" }
        if score >= 50 { return "Fair" }
        return "Needs Attention"
    }
}
