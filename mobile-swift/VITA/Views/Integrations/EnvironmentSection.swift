import SwiftUI
import VITADesignSystem

struct EnvironmentSection: View {
    let viewModel: IntegrationsViewModel
    let isLoading: Bool

    private var latestReading: IntegrationsViewModel.EnvironmentReading? {
        viewModel.environmentReadings.max(by: { $0.timestamp < $1.timestamp })
    }

    private var previousReadings: [IntegrationsViewModel.EnvironmentReading] {
        guard let latest = latestReading else { return [] }
        return viewModel.environmentReadings
            .filter { $0.id != latest.id }
            .sorted { $0.timestamp > $1.timestamp }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: VITASpacing.md) {
            HStack {
                Image(systemName: "cloud.sun")
                    .font(.title2)
                    .foregroundStyle(VITAColors.teal)
                Text("Environment")
                    .font(VITATypography.title3)
                Spacer()
                if let latest = latestReading {
                    AQIBadge(aqi: latest.aqiUS)
                }
            }

            if isLoading {
                SkeletonCard(lines: [120, 220, 180], lineHeight: 12)
            } else if let current = latestReading {
                VStack(spacing: VITASpacing.md) {
                    HStack(spacing: VITASpacing.md) {
                        ConditionItem(
                            icon: "thermometer.medium",
                            label: "Temp",
                            value: "\(Int(current.temperatureCelsius))\u{00B0}C",
                            color: tempColor(current.temperatureCelsius)
                        )
                        ConditionItem(
                            icon: "aqi.medium",
                            label: "AQI",
                            value: "\(current.aqiUS)",
                            color: aqiColor(current.aqiUS)
                        )
                        ConditionItem(
                            icon: "humidity",
                            label: "Humidity",
                            value: "\(Int(current.humidity))%",
                            color: humidityColor(current.humidity)
                        )
                    }

                    HStack(spacing: VITASpacing.md) {
                        ConditionItem(
                            icon: "sun.max",
                            label: "UV",
                            value: String(format: "%.0f", current.uvIndex),
                            color: uvColor(current.uvIndex)
                        )
                        ConditionItem(
                            icon: "leaf",
                            label: "Pollen",
                            value: "\(current.pollenIndex)/12",
                            color: pollenColor(current.pollenIndex)
                        )
                        Spacer()
                    }

                    if current.healthImpact != "No significant health risks" {
                        HStack(spacing: VITASpacing.sm) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(VITAColors.amber)
                            Text(current.healthImpact)
                                .font(VITATypography.caption)
                                .foregroundStyle(VITAColors.amber)
                        }
                    }

                }
                .padding(VITASpacing.cardPadding)
                .background(VITAColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: VITASpacing.cardCornerRadius))

                ForEach(Array(previousReadings.prefix(5))) { reading in
                    HStack {
                        Text(reading.timestamp, style: .date)
                            .font(VITATypography.caption)
                            .foregroundStyle(VITAColors.textSecondary)
                        Spacer()
                        HStack(spacing: VITASpacing.md) {
                            Text("\(Int(reading.temperatureCelsius))\u{00B0}")
                                .font(VITATypography.caption)
                                .foregroundStyle(tempColor(reading.temperatureCelsius))
                            Text("AQI \(reading.aqiUS)")
                                .font(VITATypography.caption)
                                .foregroundStyle(aqiColor(reading.aqiUS))
                            Text("P\(reading.pollenIndex)")
                                .font(VITATypography.caption)
                                .foregroundStyle(pollenColor(reading.pollenIndex))
                        }
                    }
                    .padding(.horizontal, VITASpacing.cardPadding)
                    .padding(.vertical, VITASpacing.xs)
                }
            } else {
                EmptyDataStateView(
                    title: "No Environment Data Yet",
                    message: "Location and weather sync data will appear here."
                )
            }
        }
    }

    private func tempColor(_ temp: Double) -> Color {
        switch temp {
        case ..<5: return VITAColors.info
        case 5..<15: return VITAColors.teal
        case 15..<30: return VITAColors.success
        case 30..<35: return VITAColors.amber
        default: return VITAColors.coral
        }
    }

    private func aqiColor(_ aqi: Int) -> Color {
        switch aqi {
        case ..<50: return VITAColors.success
        case 50..<100: return VITAColors.amber
        case 100..<150: return VITAColors.glucoseHigh
        default: return VITAColors.coral
        }
    }

    private func humidityColor(_ humidity: Double) -> Color {
        switch humidity {
        case ..<30: return VITAColors.amber
        case 30..<60: return VITAColors.success
        case 60..<80: return VITAColors.amber
        default: return VITAColors.coral
        }
    }

    private func uvColor(_ uv: Double) -> Color {
        switch uv {
        case ..<3: return VITAColors.success
        case 3..<6: return VITAColors.amber
        case 6..<8: return VITAColors.glucoseHigh
        default: return VITAColors.coral
        }
    }

    private func pollenColor(_ pollen: Int) -> Color {
        switch pollen {
        case ..<4: return VITAColors.success
        case 4..<7: return VITAColors.amber
        case 7..<9: return VITAColors.glucoseHigh
        default: return VITAColors.coral
        }
    }
}

struct AQIBadge: View {
    let aqi: Int

    var body: some View {
        HStack(spacing: VITASpacing.xs) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("AQI \(aqi)")
                .font(VITATypography.caption)
                .foregroundStyle(color)
        }
        .padding(.horizontal, VITASpacing.sm)
        .padding(.vertical, VITASpacing.xs)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    private var color: Color {
        switch aqi {
        case ..<50: return VITAColors.success
        case 50..<100: return VITAColors.amber
        case 100..<150: return VITAColors.glucoseHigh
        default: return VITAColors.coral
        }
    }
}

struct ConditionItem: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: VITASpacing.xs) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(VITATypography.metricSmall)
                .foregroundStyle(color)
            Text(label)
                .font(VITATypography.caption2)
                .foregroundStyle(VITAColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}
