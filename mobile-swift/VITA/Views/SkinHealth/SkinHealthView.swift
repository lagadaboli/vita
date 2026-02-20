import SwiftUI
import VITADesignSystem

struct SkinHealthView: View {
    var appState: AppState
    @State private var viewModel: SkinHealthViewModel

    init(appState: AppState) {
        self.appState = appState
        self._viewModel = State(initialValue: SkinHealthViewModel(appState: appState))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: VITASpacing.xl) {
                    switch viewModel.state {
                    case .idle:
                        idleState
                    case .capturingImage:
                        // Camera sheet is presented as fullScreenCover — nothing to show inline
                        analyzingState(message: "Opening camera…")
                    case .analyzing:
                        analyzingState(message: "Analysing skin zones…")
                    case .complete:
                        if let result = viewModel.analysisResult {
                            resultsView(result: result)
                        }
                    case .error(let msg):
                        errorState(message: msg)
                    }
                }
                .padding(.horizontal, VITASpacing.lg)
                .padding(.vertical, VITASpacing.md)
                .padding(.bottom, VITASpacing.xxl)
            }
            .background(VITAColors.background)
            .navigationTitle("Skin Audit")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbarItems }
        }
        // Camera (front camera)
        .fullScreenCover(isPresented: $viewModel.showCameraSheet) {
            CameraPickerView(source: .camera) { image in
                viewModel.showCameraSheet = false
                viewModel.analyze(image: image)
            } onCancel: {
                viewModel.showCameraSheet = false
                viewModel.state = .idle
            }
            .ignoresSafeArea()
        }
        // Photo library picker
        .sheet(isPresented: $viewModel.showPhotoLibrarySheet) {
            CameraPickerView(source: .photoLibrary) { image in
                viewModel.showPhotoLibrarySheet = false
                viewModel.analyze(image: image)
            } onCancel: {
                viewModel.showPhotoLibrarySheet = false
                viewModel.state = .idle
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        if viewModel.state == .complete {
            ToolbarItem(placement: .primaryAction) {
                Button("Re-Scan") { viewModel.reset() }
                    .font(VITATypography.caption)
                    .tint(VITAColors.teal)
            }
        }
    }

    // MARK: - Idle State

    private var idleState: some View {
        VStack(spacing: VITASpacing.xl) {

            // API key banner (shown only when not configured)
            if !viewModel.isApiConfigured {
                apiKeyBanner
            }

            // Hero area
            VStack(spacing: VITASpacing.md) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 56))
                    .foregroundStyle(VITAColors.teal)
                    .padding(.top, viewModel.isApiConfigured ? VITASpacing.xxl : VITASpacing.md)

                Text("AI Skin Health Audit")
                    .font(VITATypography.title2)
                    .foregroundStyle(VITAColors.textPrimary)

                Text("Scan your face to detect acne, dark circles, redness, and oiliness — VITA then traces each finding to your meals, sleep, and screen habits.")
                    .font(VITATypography.body)
                    .foregroundStyle(VITAColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Feature bullets
            VStack(alignment: .leading, spacing: VITASpacing.sm) {
                featureBullet("viewfinder.circle.fill", "PerfectCorp AI — 9 skin concern analysis")
                featureBullet("heart.text.clipboard",  "Causal link to meals, HRV & screen time")
                featureBullet("chart.line.uptrend.xyaxis", "7-day skin improvement forecast")
                featureBullet("lock.shield",           "Image processed server-side by PerfectCorp — not stored")
            }
            .padding(VITASpacing.cardPadding)
            .background(VITAColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))

            // Captured image preview (if user retried after seeing a result)
            if let img = viewModel.capturedImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
            }

            // Action buttons
            captureButtons
        }
    }

    // MARK: - API Key Banner

    private var apiKeyBanner: some View {
        HStack(spacing: VITASpacing.sm) {
            Image(systemName: "key.fill")
                .font(.callout)
                .foregroundStyle(VITAColors.amber)
            VStack(alignment: .leading, spacing: 2) {
                Text("PerfectCorp API Key Not Set")
                    .font(VITATypography.callout.weight(.semibold))
                    .foregroundStyle(VITAColors.textPrimary)
                Text("Tap \"Start Scan\" to try demo mode, or add your key in Settings → Skin Audit.")
                    .font(VITATypography.caption2)
                    .foregroundStyle(VITAColors.textSecondary)
            }
            Spacer()
        }
        .padding(VITASpacing.cardPadding)
        .background(VITAColors.amber.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
    }

    // MARK: - Capture Buttons

    private var captureButtons: some View {
        VStack(spacing: VITASpacing.sm) {
            // Primary: front camera
            if CameraPickerView.isCameraAvailable {
                Button {
                    viewModel.state = .capturingImage
                    viewModel.showCameraSheet = true
                } label: {
                    HStack(spacing: VITASpacing.sm) {
                        Image(systemName: "camera.fill")
                        Text(viewModel.isApiConfigured ? "Scan My Face" : "Scan Face (Demo)")
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

            // Secondary: photo library
            Button {
                viewModel.state = .capturingImage
                viewModel.showPhotoLibrarySheet = true
            } label: {
                HStack(spacing: VITASpacing.sm) {
                    Image(systemName: "photo.on.rectangle")
                    Text("Choose from Library")
                        .font(VITATypography.callout)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, VITASpacing.sm)
                .background(VITAColors.cardBackground)
                .foregroundStyle(VITAColors.teal)
                .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius)
                        .stroke(VITAColors.teal.opacity(0.4), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Analysing State

    private func analyzingState(message: String) -> some View {
        VStack(spacing: VITASpacing.lg) {
            Spacer().frame(height: VITASpacing.xxl)

            ProgressView()
                .progressViewStyle(.circular)
                .tint(VITAColors.teal)
                .scaleEffect(1.4)

            VStack(spacing: VITASpacing.xs) {
                Text(message)
                    .font(VITATypography.headline)
                    .foregroundStyle(VITAColors.textPrimary)
                Text("PerfectCorp AI processing 9 skin concerns")
                    .font(VITATypography.caption)
                    .foregroundStyle(VITAColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Error State

    private func errorState(message: String) -> some View {
        VStack(spacing: VITASpacing.lg) {
            Spacer().frame(height: VITASpacing.xxl)
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(VITAColors.coral)
            Text("Analysis Failed")
                .font(VITATypography.title3)
                .foregroundStyle(VITAColors.textPrimary)
            Text(message)
                .font(VITATypography.caption)
                .foregroundStyle(VITAColors.textSecondary)
                .multilineTextAlignment(.center)
            Button("Try Again") { viewModel.reset() }
                .tint(VITAColors.teal)
        }
        .padding(.horizontal, VITASpacing.xl)
    }

    // MARK: - Results

    @ViewBuilder
    private func resultsView(result: PerfectCorpService.AnalysisResult) -> some View {
        // Captured image thumbnail + score header
        if let img = viewModel.capturedImage {
            HStack(spacing: VITASpacing.lg) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 72, height: 72)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(VITAColors.teal.opacity(0.4), lineWidth: 2))

                skinScoreCard(score: result.overallScore, source: result.source)
            }
            .padding(VITASpacing.cardPadding)
            .background(VITAColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
        } else {
            skinScoreCard(score: result.overallScore, source: result.source)
        }

        // Problem overlay + HRV chart — side by side
        HStack(alignment: .top, spacing: VITASpacing.md) {
            FaceHeatmapView(
                conditions: result.conditions,
                capturedImage: viewModel.capturedImage,
                apiBaseImageURL: result.overlayBaseImageURL
            )
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

        // Last analysis timestamp
        if let date = viewModel.lastAnalysisDate {
            Text("Analysed \(date, style: .relative) ago · \(result.source == "demo" ? "Demo mode" : "PerfectCorp AI")")
                .font(VITATypography.caption2)
                .foregroundStyle(VITAColors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    // MARK: - Sub-cards

    private func skinScoreCard(score: Int, source: String) -> some View {
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
                Text(source == "demo" ? "Demo Mode · Add API key for real scans" : "Powered by PerfectCorp YouCam AI")
                    .font(VITATypography.caption2)
                    .foregroundStyle(source == "demo" ? VITAColors.amber : VITAColors.textTertiary)
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
