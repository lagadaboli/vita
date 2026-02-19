import SwiftUI
import Charts
import VITADesignSystem
import VITACore

struct DashboardView: View {
    var appState: AppState
    @State private var viewModel = DashboardViewModel()
    @State private var isRefreshing = false
    @State private var hasPerformedInitialLoad = false

    private var isComponentLoading: Bool {
        !appState.isLoaded
            || ((appState.isHealthSyncing || isRefreshing) && !viewModel.hasAnyData && !viewModel.hasLoaded)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: VITASpacing.xl) {
                    Group {
                        if isComponentLoading {
                            HealthScoreSkeleton()
                                .padding(.horizontal, VITASpacing.lg)
                        } else {
                            HealthScoreGauge(score: viewModel.healthScore)
                                .padding(.top, VITASpacing.md)
                        }
                    }

                    MiniGlucoseChart(dataPoints: viewModel.glucoseReadings, isLoading: isComponentLoading)

                    MetricCardRow(viewModel: viewModel, isLoading: isComponentLoading)

                    if !viewModel.hasAnyData && !isComponentLoading {
                        EmptyDataStateView(
                            title: "No Health Data Yet",
                            message: "Open Apple Health permissions for VITA, then pull to refresh."
                        )
                        .padding(.horizontal, VITASpacing.lg)
                    }

                    VStack(alignment: .leading, spacing: VITASpacing.md) {
                        Text("Insights")
                            .font(VITATypography.title3)
                            .padding(.horizontal, VITASpacing.lg)

                        if isComponentLoading {
                            ForEach(0..<2, id: \.self) { _ in
                                SkeletonCard(lines: [110, 220, 150], lineHeight: 12)
                                    .padding(.horizontal, VITASpacing.lg)
                            }
                        } else {
                            ForEach(viewModel.insights) { insight in
                                InsightAlertCard(insight: insight)
                                    .padding(.horizontal, VITASpacing.lg)
                            }
                        }
                    }

                    IntegrationStatusRow()
                        .padding(.horizontal, VITASpacing.lg)
                }
                .padding(.bottom, VITASpacing.xxl)
            }
            .background(VITAColors.background)
            .navigationTitle("VITA")
            .task(id: appState.isLoaded) {
                guard appState.isLoaded, !hasPerformedInitialLoad else { return }
                hasPerformedInitialLoad = true
                await refreshDashboard(force: false)
            }
            .refreshable {
                await refreshDashboard(force: true)
            }
            .navigationDestination(for: DashboardMetric.self) { metric in
                MetricHistoryDetailView(
                    metric: metric,
                    viewModel: viewModel,
                    isLoading: appState.isHealthSyncing
                )
            }
        }
    }

    @MainActor
    private func refreshDashboard(force: Bool) async {
        guard appState.isLoaded else { return }
        viewModel.load(from: appState)
        if force {
            isRefreshing = true
        }
        await appState.refreshHealthDataIfNeeded(maxAge: 120, force: force)
        viewModel.load(from: appState)
        if force {
            isRefreshing = false
        }
    }
}

private struct HealthScoreSkeleton: View {
    var body: some View {
        VStack(spacing: VITASpacing.md) {
            HStack(spacing: VITASpacing.md) {
                ShimmerSkeleton(width: 84, height: 84, cornerRadius: 42)
                VStack(alignment: .leading, spacing: VITASpacing.sm) {
                    ShimmerSkeleton(width: 90, height: 12, cornerRadius: 6)
                    ShimmerSkeleton(width: 150, height: 18, cornerRadius: 8)
                    ShimmerSkeleton(width: 130, height: 12, cornerRadius: 6)
                }
                Spacer()
            }
            ShimmerSkeleton(height: 10, cornerRadius: 5)
            ShimmerSkeleton(width: 220, height: 10, cornerRadius: 5)
        }
        .padding(VITASpacing.cardPadding)
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
        .background(VITAColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
    }
}

private enum MetricHistoryRange: String, CaseIterable, Identifiable, Sendable {
    case hour = "H"
    case day = "D"
    case week = "W"
    case month = "M"
    case sixMonths = "6M"
    case year = "Y"

    var id: String { rawValue }

    func domain(endingAt date: Date, calendar: Calendar = .current) -> ClosedRange<Date> {
        let upper = date
        let lower: Date

        switch self {
        case .hour:
            lower = calendar.date(byAdding: .hour, value: -1, to: upper) ?? upper
        case .day:
            lower = calendar.startOfDay(for: upper)
        case .week:
            lower = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: upper)) ?? upper
        case .month:
            lower = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: upper)) ?? upper
        case .sixMonths:
            lower = calendar.date(byAdding: .month, value: -6, to: calendar.startOfDay(for: upper)) ?? upper
        case .year:
            lower = calendar.date(byAdding: .year, value: -1, to: calendar.startOfDay(for: upper)) ?? upper
        }

        return lower...upper
    }
}

struct MetricHistoryDetailView: View {
    let metric: DashboardMetric
    let viewModel: DashboardViewModel
    let isLoading: Bool

    @State private var selectedRange: MetricHistoryRange = .day
    @State private var focusDate = Date()
    @State private var selectedDate: Date?
    @State private var historyPoints: [DashboardViewModel.MetricHistoryPoint] = []
    @State private var isPreparingHistory = true
    @State private var historyTask: Task<Void, Never>?

    private var latestDataDate: Date {
        viewModel.history(for: metric).map(\.timestamp).max() ?? Date()
    }

    private var selectedPoint: DashboardViewModel.MetricHistoryPoint? {
        guard !historyPoints.isEmpty else { return nil }
        guard let selectedDate else { return historyPoints.last }

        return historyPoints.min {
            abs($0.timestamp.timeIntervalSince(selectedDate)) < abs($1.timestamp.timeIntervalSince(selectedDate))
        }
    }

    private var xDomain: ClosedRange<Date> {
        selectedRange.domain(endingAt: focusDate)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VITASpacing.lg) {
                summaryCard
                chartCard
            }
            .padding(.horizontal, VITASpacing.lg)
            .padding(.top, VITASpacing.md)
            .padding(.bottom, VITASpacing.xxl)
        }
        .background(VITAColors.background)
        .navigationTitle(metric.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            focusDate = min(latestDataDate, Date())
            refreshHistoryPoints()
        }
        .onDisappear {
            historyTask?.cancel()
        }
        .onChange(of: selectedRange) {
            focusDate = min(latestDataDate, Date())
            selectedDate = nil
            refreshHistoryPoints()
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: VITASpacing.sm) {
            Text("Current")
                .font(VITATypography.caption)
                .foregroundStyle(VITAColors.textSecondary)

            HStack(alignment: .firstTextBaseline, spacing: VITASpacing.xs) {
                Text(viewModel.formattedCurrentValue(for: metric))
                    .font(VITATypography.metric)
                    .foregroundStyle(chartColor)

                if !metric.unit.isEmpty {
                    Text(metric.unit)
                        .font(VITATypography.caption)
                        .foregroundStyle(VITAColors.textTertiary)
                }
            }

            Text(viewModel.sourceLabel(for: metric))
                .font(VITATypography.caption2)
                .foregroundStyle(VITAColors.textTertiary)
        }
        .padding(VITASpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VITAColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: VITASpacing.md) {
            rangePicker
            periodNavigator
            rangeValueSummary

            if (isLoading || isPreparingHistory) && historyPoints.isEmpty {
                VStack(spacing: VITASpacing.sm) {
                    ShimmerSkeleton(width: 130, height: 12, cornerRadius: 6)
                    ShimmerSkeleton(width: 180, height: 12, cornerRadius: 6)
                    ShimmerSkeleton(height: 240, cornerRadius: 14)
                }
            } else if historyPoints.isEmpty {
                Text("No historical data available for this range.")
                    .font(VITATypography.body)
                    .foregroundStyle(VITAColors.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 220, alignment: .center)
            } else {
                Chart(historyPoints) { point in
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value(metric.title, point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .foregroundStyle(chartColor)

                    AreaMark(
                        x: .value("Time", point.timestamp),
                        y: .value(metric.title, point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(chartColor.opacity(0.12))

                    if selectedPoint?.id == point.id {
                        RuleMark(x: .value("Selected", point.timestamp))
                            .foregroundStyle(VITAColors.textTertiary.opacity(0.4))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))

                        PointMark(
                            x: .value("Time", point.timestamp),
                            y: .value(metric.title, point.value)
                        )
                        .symbolSize(48)
                        .foregroundStyle(chartColor)
                    }
                }
                .chartXScale(domain: xDomain)
                .chartYScale(domain: yDomain)
                .chartYAxis {
                    AxisMarks(position: .trailing)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { value in
                        AxisValueLabel(format: xAxisFormat)
                    }
                }
                .chartXSelection(value: $selectedDate)
                .frame(height: 260)
            }
        }
        .padding(VITASpacing.cardPadding)
        .background(VITAColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))
    }

    private var rangePicker: some View {
        HStack(spacing: VITASpacing.xs) {
            ForEach(MetricHistoryRange.allCases) { range in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedRange = range
                    }
                } label: {
                    Text(range.rawValue)
                        .font(VITATypography.headline)
                        .foregroundStyle(selectedRange == range ? VITAColors.textPrimary : VITAColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(selectedRange == range ? VITAColors.tertiaryBackground : .clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(VITAColors.background.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var periodNavigator: some View {
        HStack {
            Button {
                shiftFocusDate(direction: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VITAColors.textSecondary)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(periodTitle)
                .font(VITATypography.caption)
                .foregroundStyle(VITAColors.textSecondary)

            Spacer()

            Button {
                shiftFocusDate(direction: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(canMoveForward ? VITAColors.textSecondary : VITAColors.textTertiary.opacity(0.4))
            }
            .buttonStyle(.plain)
            .disabled(!canMoveForward)
        }
    }

    @ViewBuilder
    private var rangeValueSummary: some View {
        if let point = selectedPoint {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: VITASpacing.xs) {
                    Text(formattedPointValue(point.value))
                        .font(.system(size: 44, weight: .semibold, design: .rounded))
                        .foregroundStyle(chartColor)
                    if !metric.unit.isEmpty {
                        Text(metric.unit.uppercased())
                            .font(VITATypography.caption)
                            .foregroundStyle(VITAColors.textTertiary)
                    }
                }
                Text(point.timestamp.formatted(summaryDateFormat))
                    .font(VITATypography.headline)
                    .foregroundStyle(VITAColors.textSecondary)
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text("No Data")
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .foregroundStyle(VITAColors.textPrimary)
                Text(focusDate.formatted(summaryDateFormat))
                    .font(VITATypography.headline)
                    .foregroundStyle(VITAColors.textSecondary)
            }
        }
    }

    private var summaryDateFormat: Date.FormatStyle {
        switch selectedRange {
        case .hour:
            return .dateTime.hour(.defaultDigits(amPM: .abbreviated)).minute()
        case .day:
            return .dateTime.weekday(.abbreviated).month(.abbreviated).day().year()
        case .week:
            return .dateTime.weekday(.abbreviated).month(.abbreviated).day()
        case .month:
            return .dateTime.month(.abbreviated).day().year()
        case .sixMonths, .year:
            return .dateTime.month(.abbreviated).day().year()
        }
    }

    private var periodTitle: String {
        switch selectedRange {
        case .hour:
            return focusDate.formatted(.dateTime.month(.abbreviated).day().hour().minute())
        case .day:
            return focusDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().year())
        case .week:
            let range = selectedRange.domain(endingAt: focusDate)
            return "\(range.lowerBound.formatted(.dateTime.month(.abbreviated).day())) - \(range.upperBound.formatted(.dateTime.month(.abbreviated).day()))"
        case .month:
            return focusDate.formatted(.dateTime.month(.wide).year())
        case .sixMonths:
            return "6 months ending \(focusDate.formatted(.dateTime.month(.abbreviated).year()))"
        case .year:
            return focusDate.formatted(.dateTime.year())
        }
    }

    private var canMoveForward: Bool {
        selectedRange.domain(endingAt: focusDate).upperBound < Date()
    }

    private var chartColor: Color {
        switch metric {
        case .hrv:
            return viewModel.currentHRV < 40 ? VITAColors.coral : VITAColors.teal
        case .heartRate:
            return viewModel.currentHR > 72 ? VITAColors.amber : VITAColors.teal
        case .sleep:
            return viewModel.sleepHours < 7 ? VITAColors.amber : VITAColors.success
        case .glucose:
            return VITAColors.glucoseColor(mgDL: viewModel.currentGlucose)
        case .weight:
            return viewModel.weightTrend == .up ? VITAColors.amber : VITAColors.teal
        case .steps:
            return viewModel.steps > 8000 ? VITAColors.success : VITAColors.teal
        case .dopamineDebt:
            return viewModel.dopamineDebt > 60 ? VITAColors.coral : VITAColors.amber
        }
    }

    private var yDomain: ClosedRange<Double> {
        let values = historyPoints.map(\.value)
        let maxValue = values.max() ?? 1
        let minValue = values.min() ?? 0

        switch metric {
        case .glucose:
            let lower = max(50, floor((minValue - 15) / 10) * 10)
            let upper = max(140, ceil((maxValue + 15) / 10) * 10)
            return lower...upper
        case .dopamineDebt:
            return 0...100
        default:
            let lower = min(0, minValue)
            let upper = max(1, maxValue * 1.15)
            return lower...upper
        }
    }

    private var xAxisFormat: Date.FormatStyle {
        switch selectedRange {
        case .hour:
            return .dateTime.minute()
        case .day:
            return .dateTime.hour(.defaultDigits(amPM: .omitted))
        case .week:
            return .dateTime.weekday(.abbreviated)
        case .month:
            return .dateTime.month(.abbreviated).day()
        case .sixMonths, .year:
            return .dateTime.month(.abbreviated)
        }
    }

    private func formattedPointValue(_ value: Double) -> String {
        switch metric {
        case .weight, .sleep:
            return String(format: "%.1f", value)
        case .steps:
            return "\(Int(value.rounded()))"
        default:
            return "\(Int(value.rounded()))"
        }
    }

    private func shiftFocusDate(direction: Int) {
        guard direction != 0 else { return }
        let calendar = Calendar.current

        let shifted: Date?
        switch selectedRange {
        case .hour:
            shifted = calendar.date(byAdding: .hour, value: direction, to: focusDate)
        case .day:
            shifted = calendar.date(byAdding: .day, value: direction, to: focusDate)
        case .week:
            shifted = calendar.date(byAdding: .day, value: 7 * direction, to: focusDate)
        case .month:
            shifted = calendar.date(byAdding: .month, value: direction, to: focusDate)
        case .sixMonths:
            shifted = calendar.date(byAdding: .month, value: 6 * direction, to: focusDate)
        case .year:
            shifted = calendar.date(byAdding: .year, value: direction, to: focusDate)
        }

        let now = Date()
        focusDate = min(shifted ?? focusDate, now)
        selectedDate = nil
        refreshHistoryPoints()
    }

    @MainActor
    private func refreshHistoryPoints() {
        historyTask?.cancel()

        let sourcePoints = viewModel.history(for: metric)
        let range = selectedRange
        let domain = range.domain(endingAt: focusDate)
        let strategy = aggregationStrategy

        isPreparingHistory = true
        historyTask = Task.detached(priority: .userInitiated) {
            let clipped = sourcePoints
                .filter { $0.timestamp >= domain.lowerBound && $0.timestamp <= domain.upperBound }
                .sorted(by: { $0.timestamp < $1.timestamp })
            let aggregated = Self.aggregate(clipped, for: range, strategy: strategy)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                historyPoints = aggregated
                isPreparingHistory = false
            }
        }
    }

    nonisolated private static func aggregate(
        _ points: [DashboardViewModel.MetricHistoryPoint],
        for range: MetricHistoryRange,
        strategy: Aggregation
    ) -> [DashboardViewModel.MetricHistoryPoint] {
        guard !points.isEmpty else { return [] }
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: points) { point in
            bucketStart(for: point.timestamp, in: range, calendar: calendar)
        }

        return grouped.keys.sorted().compactMap { bucket in
            guard let values = grouped[bucket] else { return nil }
            let aggregatedValue: Double

            switch strategy {
            case .sum:
                aggregatedValue = values.reduce(0.0) { $0 + $1.value }
            case .latest:
                aggregatedValue = values.max(by: { $0.timestamp < $1.timestamp })?.value ?? 0
            case .average:
                let sum = values.reduce(0.0) { $0 + $1.value }
                aggregatedValue = sum / Double(values.count)
            }

            return DashboardViewModel.MetricHistoryPoint(timestamp: bucket, value: aggregatedValue)
        }
    }

    nonisolated private static func bucketStart(for date: Date, in range: MetricHistoryRange, calendar: Calendar) -> Date {
        switch range {
        case .hour:
            let minute = calendar.component(.minute, from: date)
            let roundedMinute = (minute / 5) * 5
            var components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
            components.minute = roundedMinute
            components.second = 0
            return calendar.date(from: components) ?? date
        case .day:
            var components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
            components.minute = 0
            components.second = 0
            return calendar.date(from: components) ?? date
        case .week, .month:
            return calendar.startOfDay(for: date)
        case .sixMonths:
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            return calendar.date(from: components) ?? calendar.startOfDay(for: date)
        case .year:
            let components = calendar.dateComponents([.year, .month], from: date)
            return calendar.date(from: components) ?? calendar.startOfDay(for: date)
        }
    }

    private var aggregationStrategy: Aggregation {
        switch metric {
        case .steps, .sleep:
            return .sum
        case .weight:
            return .latest
        default:
            return .average
        }
    }

    private enum Aggregation: Sendable {
        case sum
        case average
        case latest
    }
}
