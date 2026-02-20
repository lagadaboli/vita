import SwiftUI
import VITADesignSystem
#if canImport(PDFKit)
import PDFKit
#endif

struct HealthReportView: View {
    var appState: AppState
    @State private var viewModel = HealthReportViewModel()
    @State private var dashVM = DashboardViewModel()
    @State private var skinVM = SkinHealthViewModel()
    @State private var isShowingPDFPreview = false

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .idle:
                    questionsView
                case .generatingDocument:
                    generatingView(label: "Generating document\u{2026}")
                case .optimizingPDF:
                    generatingView(label: "Optimising PDF\u{2026}")
                case .complete:
                    completeView
                case .error(let message):
                    errorView(message: message)
                }
            }
            .navigationTitle("Health Report")
            .sheet(isPresented: $viewModel.isShowingShareSheet) {
                if let data = viewModel.pdfData {
                    ShareSheet(items: [data])
                }
            }
            .sheet(isPresented: $isShowingPDFPreview) {
                if let data = viewModel.pdfData {
                    PDFPreviewSheet(
                        data: data,
                        title: "Health Report",
                        suggestedFileName: "VITA-Health-Report.pdf"
                    )
                }
            }
        }
        .onAppear {
            if !dashVM.hasLoaded {
                dashVM.load(from: appState)
            }
        }
    }

    // MARK: - Questions state

    private var questionsView: some View {
        ScrollView {
            VStack(spacing: VITASpacing.xl) {
                if !FoxitConfig.current.isConfigured {
                    configurationBanner
                }

                questionSection
                reportSummaryCard
                generateButton
            }
            .padding(.horizontal, VITASpacing.lg)
            .padding(.bottom, VITASpacing.xxl)
        }
        .background(VITAColors.background)
    }

    private var configurationBanner: some View {
        HStack(spacing: VITASpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(VITAColors.amber)
            VStack(alignment: .leading, spacing: 2) {
                Text("Foxit API Not Configured")
                    .font(VITATypography.caption)
                    .foregroundStyle(VITAColors.textPrimary)
                    .fontWeight(.semibold)
                Text("Add credentials in Settings to generate reports.")
                    .font(VITATypography.caption2)
                    .foregroundStyle(VITAColors.textSecondary)
            }
            Spacer()
        }
        .padding(VITASpacing.md)
        .background(VITAColors.amber.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius)
                .strokeBorder(VITAColors.amber.opacity(0.4), lineWidth: 1)
        )
    }

    private var questionSection: some View {
        VStack(alignment: .leading, spacing: VITASpacing.md) {
            Text("Clinical Questions")
                .font(VITATypography.headline)
                .foregroundStyle(VITAColors.textPrimary)

            VStack(spacing: 0) {
                pickerRow(
                    label: "Primary concern",
                    selection: $viewModel.answers.primaryConcern,
                    options: HealthReportViewModel.questions[0].options
                )
                Divider().padding(.horizontal, VITASpacing.md)
                pickerRow(
                    label: "Sleep quality",
                    selection: $viewModel.answers.sleepQuality,
                    options: HealthReportViewModel.questions[1].options
                )
                Divider().padding(.horizontal, VITASpacing.md)
                pickerRow(
                    label: "Digestive symptoms",
                    selection: $viewModel.answers.digestiveIssues,
                    options: HealthReportViewModel.questions[2].options
                )
                Divider().padding(.horizontal, VITASpacing.md)
                pickerRow(
                    label: "Exercise this week",
                    selection: $viewModel.answers.exerciseFrequency,
                    options: HealthReportViewModel.questions[3].options
                )
                Divider().padding(.horizontal, VITASpacing.md)
                pickerRow(
                    label: "Goal for visit",
                    selection: $viewModel.answers.providerGoal,
                    options: HealthReportViewModel.questions[4].options
                )
            }
            .background(VITAColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
        }
    }

    private func pickerRow(
        label: String,
        selection: Binding<String>,
        options: [String]
    ) -> some View {
        Picker(label, selection: selection) {
            ForEach(options, id: \.self) { option in
                Text(option).tag(option)
            }
        }
        .pickerStyle(.menu)
        .padding(.horizontal, VITASpacing.md)
        .padding(.vertical, VITASpacing.sm)
    }

    private var reportSummaryCard: some View {
        VStack(alignment: .leading, spacing: VITASpacing.md) {
            Text("Report will include")
                .font(VITATypography.headline)
                .foregroundStyle(VITAColors.textPrimary)

            VStack(spacing: VITASpacing.sm) {
                summaryRow(icon: "heart.text.clipboard", label: "Apple Watch metrics (HRV, glucose, sleep, steps)")
                summaryRow(icon: "fork.knife", label: "Recent meal data with glycemic load")
                summaryRow(icon: "face.smiling", label: "AI skin health analysis & scores")
                summaryRow(icon: "arrow.triangle.branch", label: "Full causal chain findings")
                summaryRow(icon: "list.bullet.clipboard", label: "Personalised recommendations")
            }
        }
        .padding(VITASpacing.cardPadding)
        .background(VITAColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
    }

    private func summaryRow(icon: String, label: String) -> some View {
        HStack(spacing: VITASpacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(VITAColors.teal)
                .frame(width: 20)
            Text(label)
                .font(VITATypography.body)
                .foregroundStyle(VITAColors.textSecondary)
            Spacer()
        }
    }

    private var generateButton: some View {
        Button {
            viewModel.generate(appState: appState, dashVM: dashVM, skinVM: skinVM)
        } label: {
            Label("Generate Report", systemImage: "doc.richtext")
                .font(VITATypography.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(VITASpacing.md)
                .background(
                    FoxitConfig.current.isConfigured ? VITAColors.teal : VITAColors.textTertiary
                )
                .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
        }
        .disabled(!FoxitConfig.current.isConfigured)
    }

    // MARK: - Generating state

    private func generatingView(label: String) -> some View {
        VStack(spacing: VITASpacing.xl) {
            Spacer()

            VStack(spacing: VITASpacing.lg) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(VITAColors.teal)
                    .scaleEffect(1.4)

                VStack(spacing: VITASpacing.xs) {
                    Text(label)
                        .font(VITATypography.headline)
                        .foregroundStyle(VITAColors.textPrimary)

                    Text("This may take up to a minute.")
                        .font(VITATypography.callout)
                        .foregroundStyle(VITAColors.textSecondary)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(VITAColors.background)
    }

    // MARK: - Complete state

    private var completeView: some View {
        ScrollView {
            VStack(spacing: VITASpacing.xl) {
                successCard
                actionButtons
            }
            .padding(.horizontal, VITASpacing.lg)
            .padding(.top, VITASpacing.xl)
            .padding(.bottom, VITASpacing.xxl)
        }
        .background(VITAColors.background)
    }

    private var successCard: some View {
        VStack(spacing: VITASpacing.lg) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(VITAColors.teal)

            VStack(spacing: VITASpacing.xs) {
                Text("Report Ready")
                    .font(VITATypography.title2)
                    .foregroundStyle(VITAColors.textPrimary)

                Text("Your personalised health report has been generated and optimised for sharing.")
                    .font(VITATypography.callout)
                    .foregroundStyle(VITAColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: VITASpacing.sm) {
                Image(systemName: "doc.richtext")
                    .foregroundStyle(VITAColors.textSecondary)
                Text("VITA Health Report \u{00B7} \(viewModel.formattedFileSize)")
                    .font(VITATypography.caption)
                    .foregroundStyle(VITAColors.textSecondary)
            }
            .padding(.horizontal, VITASpacing.md)
            .padding(.vertical, VITASpacing.xs)
            .background(VITAColors.tertiaryBackground)
            .clipShape(Capsule())
        }
        .padding(VITASpacing.cardPadding)
        .frame(maxWidth: .infinity)
        .background(VITAColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
    }

    private var actionButtons: some View {
        VStack(spacing: VITASpacing.md) {
            Button {
                isShowingPDFPreview = true
            } label: {
                Label("Preview Report", systemImage: "doc.viewfinder")
                    .font(VITATypography.headline)
                    .foregroundStyle(VITAColors.teal)
                    .frame(maxWidth: .infinity)
                    .padding(VITASpacing.md)
                    .background(VITAColors.teal.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
            }

            Button {
                viewModel.isShowingShareSheet = true
            } label: {
                Label("Share with Provider", systemImage: "square.and.arrow.up")
                    .font(VITATypography.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(VITASpacing.md)
                    .background(VITAColors.teal)
                    .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
            }

            Button {
                viewModel.reset()
            } label: {
                Text("Generate New Report")
                    .font(VITATypography.body)
                    .foregroundStyle(VITAColors.teal)
                    .frame(maxWidth: .infinity)
                    .padding(VITASpacing.md)
                    .background(VITAColors.teal.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
            }
        }
    }

    // MARK: - Error state

    private func errorView(message: String) -> some View {
        VStack(spacing: VITASpacing.xl) {
            Spacer()

            VStack(spacing: VITASpacing.lg) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(VITAColors.error)

                VStack(spacing: VITASpacing.xs) {
                    Text("Generation Failed")
                        .font(VITATypography.headline)
                        .foregroundStyle(VITAColors.textPrimary)

                    Text(message)
                        .font(VITATypography.callout)
                        .foregroundStyle(VITAColors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    viewModel.reset()
                } label: {
                    Text("Try Again")
                        .font(VITATypography.body)
                        .foregroundStyle(VITAColors.teal)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, VITASpacing.lg)
        .background(VITAColors.background)
    }
}

// MARK: - ShareSheet

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct PDFPreviewSheet: View {
    let data: Data
    let title: String
    let suggestedFileName: String

    @Environment(\.dismiss) private var dismiss
    @State private var isShowingDownloadSheet = false
    @State private var downloadURL: URL?

    var body: some View {
        NavigationStack {
            Group {
                #if canImport(PDFKit)
                PDFDocumentView(data: data)
                #else
                Text("PDF preview is unavailable on this device.")
                    .font(VITATypography.callout)
                    .foregroundStyle(VITAColors.textSecondary)
                #endif
            }
            .background(VITAColors.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(VITAColors.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Download") {
                        if let url = writeTemporaryPDF() {
                            downloadURL = url
                            isShowingDownloadSheet = true
                        }
                    }
                    .foregroundStyle(VITAColors.teal)
                }
            }
        }
        .sheet(isPresented: $isShowingDownloadSheet, onDismiss: {
            if let url = downloadURL {
                try? FileManager.default.removeItem(at: url)
                downloadURL = nil
            }
        }) {
            if let url = downloadURL {
                ShareSheet(items: [url])
            } else {
                ShareSheet(items: [data])
            }
        }
    }

    private func writeTemporaryPDF() -> URL? {
        let baseName = suggestedFileName.hasSuffix(".pdf") ? String(suggestedFileName.dropLast(4)) : suggestedFileName
        let fileName = "\(baseName)-\(UUID().uuidString.prefix(8)).pdf"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            return nil
        }
    }
}

#if canImport(PDFKit)
private struct PDFDocumentView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.document = PDFDocument(data: data)
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document == nil {
            uiView.document = PDFDocument(data: data)
        }
    }
}
#endif
