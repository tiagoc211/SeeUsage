import SwiftUI
import Charts

public struct AnalyticsView: View {
    @Bindable var settings = SettingsStore.shared
    var analytics = AnalyticsManager.shared
    @State private var selectedDays: Int = 7
    @State private var showingClearConfirmation = false
    @State private var exportMessage = ""
    @State private var showExportAlert = false

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // MARK: Section Header
                headerSection

                // MARK: Top Metrics Cards
                metricsOverviewCards

                // If no snapshots, show empty seed banner
                if analytics.snapshots.count < 2 {
                    emptyStateBanner
                } else {
                    // MARK: Chart 1: 7-Day Consumption Trend
                    dailyTrendChartCard

                    // MARK: Chart 2: Hourly Consumption (Peak Hours)
                    hourlyDistributionChartCard

                    // MARK: Chart 3: Profile & Model Comparison
                    profileComparisonCard
                }

                // MARK: Data Management Card
                dataManagementCard
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .background(settings.currentTheme.background)
        .alert("Clear Analytics History?", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                analytics.clearHistory()
            }
        } message: {
            Text("This will delete ~/.config/seeusage/history.json and reset all collected consumption metrics.")
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("// QUOTA ANALYTICS & USAGE HISTORY")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.accent)

                Text("Local historical metrics tracking peak burn hours, profile comparison, and 7-day quota trends.")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.textSecondary)
            }

            Spacer()

            // Time Range Picker
            Picker("", selection: $selectedDays) {
                Text("24 Hours").tag(1)
                Text("7 Days").tag(7)
                Text("30 Days").tag(30)
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
        }
    }

    // MARK: - Top Metric Cards
    private var metricsOverviewCards: some View {
        let metrics = analytics.computeMetrics(days: selectedDays)

        return HStack(spacing: 12) {
            metricCard(
                title: "TOTAL BURN (\(selectedDays)D)",
                value: String(format: "%.0f%%", metrics.totalConsumption7Days),
                subtext: "cumulative dropped quota",
                icon: "flame.fill",
                color: settings.currentTheme.red
            )

            metricCard(
                title: "PEAK BURN WINDOW",
                value: metrics.peakHourRange,
                subtext: "highest consumption time",
                icon: "clock.badge.exclamationmark",
                color: settings.currentTheme.amber
            )

            metricCard(
                title: "PRIMARY PROFILE",
                value: metrics.primaryProfileName,
                subtext: "most active account",
                icon: "person.crop.circle.fill",
                color: settings.currentTheme.cyan
            )

            metricCard(
                title: "SAMPLES LOGGED",
                value: "\(metrics.totalSamplesCount)",
                subtext: "in ~/.config/seeusage",
                icon: "waveform.path.ecg",
                color: settings.currentTheme.green
            )
        }
    }

    private func metricCard(title: String, value: String, subtext: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.textMuted)
            }

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(settings.currentTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(subtext)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(settings.currentTheme.textMuted)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.025))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(settings.currentTheme.border, lineWidth: 1)
        )
    }

    // MARK: - Empty State Banner
    private var emptyStateBanner: some View {
        VStack(alignment: .center, spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 28))
                .foregroundStyle(settings.currentTheme.accent)

            VStack(spacing: 4) {
                Text("Collecting Initial Quota Samples...")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.textPrimary)
                Text("SeeUsage records a data point on every sync. Once at least two polling cycles occur, your charts will populate automatically.")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 480)
            }

            Button {
                withAnimation {
                    analytics.seedDemoDataIfEmpty()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                    Text("Populate Realistic Demo History")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .padding(.top, 4)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(settings.currentTheme.border, lineWidth: 1)
        )
    }

    // MARK: - Chart 1: 7-Day Trend
    private var dailyTrendChartCard: some View {
        let daily = analytics.computeDailyConsumption(days: selectedDays)

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 11))
                        .foregroundStyle(settings.currentTheme.accent)
                    Text("DAILY CONSUMPTION TRENDS")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.textMuted)
                }

                Spacer()

                Text("percentage points burned per day")
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.textMuted)
            }

            if daily.isEmpty {
                Text("No consumption recorded in this timeframe yet.")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.textMuted)
                    .frame(height: 150)
            } else {
                Chart {
                    ForEach(daily) { item in
                        BarMark(
                            x: .value("Date", item.shortDateLabel),
                            y: .value("Consumed %", item.consumptionPercent)
                        )
                        .foregroundStyle(by: .value("Profile", item.profileName))
                        .cornerRadius(3.5)
                    }
                }
                .chartForegroundStyleScale([
                    "Pessoal": settings.currentTheme.accent,
                    "Trabalho": settings.currentTheme.cyan,
                    "Antigravity": settings.currentTheme.purple
                ])
                .chartLegend(position: .top, alignment: .trailing)
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                        AxisTick().foregroundStyle(Color.white.opacity(0.2))
                        AxisValueLabel().foregroundStyle(settings.currentTheme.textMuted)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                        AxisValueLabel().foregroundStyle(settings.currentTheme.textMuted)
                    }
                }
                .frame(height: 180)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.025))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(settings.currentTheme.border, lineWidth: 1)
        )
    }

    // MARK: - Chart 2: Hourly Distribution
    private var hourlyDistributionChartCard: some View {
        let hourly = analytics.computeHourlyConsumption(days: selectedDays)
        let maxUsage = hourly.map(\.consumptionPercent).max() ?? 1.0

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(settings.currentTheme.amber)
                    Text("HOURLY CONSUMPTION DISTRIBUTION (00:00 – 23:00)")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.textMuted)
                }

                Spacer()

                Text("identifies peak hours of the day")
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.textMuted)
            }

            Chart {
                ForEach(hourly) { item in
                    let isPeak = maxUsage > 0 && item.consumptionPercent >= maxUsage * 0.75
                    BarMark(
                        x: .value("Hour", item.hour),
                        y: .value("Burn %", item.consumptionPercent)
                    )
                    .foregroundStyle(
                        isPeak ? settings.currentTheme.amber : settings.currentTheme.accent.opacity(0.6)
                    )
                    .cornerRadius(2.5)
                }
            }
            .chartXAxis {
                AxisMarks(values: stride(from: 0, through: 23, by: 3).map { $0 }) { value in
                    AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                    AxisTick().foregroundStyle(Color.white.opacity(0.2))
                    if let hour = value.as(Int.self) {
                        AxisValueLabel {
                            Text(String(format: "%02d:00", hour))
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(settings.currentTheme.textMuted)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                    AxisValueLabel().foregroundStyle(settings.currentTheme.textMuted)
                }
            }
            .frame(height: 150)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.025))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(settings.currentTheme.border, lineWidth: 1)
        )
    }

    // MARK: - Chart 3: Profile & Model Comparison
    private var profileComparisonCard: some View {
        let summaries = analytics.computeProfileSummaries(days: selectedDays)

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "circle.grid.2x1.left.filled")
                        .font(.system(size: 11))
                        .foregroundStyle(settings.currentTheme.cyan)
                    Text("PROFILE & MODEL USAGE SHARE")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.textMuted)
                }

                Spacer()

                Text("distribution of consumed quota")
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.textMuted)
            }

            if summaries.isEmpty {
                Text("No consumption data available yet.")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.textMuted)
            } else {
                VStack(spacing: 8) {
                    ForEach(summaries) { item in
                        HStack(spacing: 12) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(item.service == "Antigravity" ? settings.currentTheme.purple : settings.currentTheme.accent)
                                    .frame(width: 7, height: 7)

                                Text(item.name)
                                    .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(settings.currentTheme.textPrimary)
                            }
                            .frame(width: 140, alignment: .leading)

                            // Horizontal proportion bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.06))
                                        .frame(height: 7)
                                    Capsule()
                                        .fill(item.service == "Antigravity" ? settings.currentTheme.purple : settings.currentTheme.accent)
                                        .frame(width: max(4, geo.size.width * CGFloat(item.percentageOfTotal / 100.0)), height: 7)
                                }
                            }
                            .frame(height: 7)

                            Text(String(format: "%.1f%%", item.percentageOfTotal))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(settings.currentTheme.textPrimary)
                                .frame(width: 50, alignment: .trailing)

                            Text(String(format: "(%.0f pts)", item.totalConsumption))
                                .font(.system(size: 9.5, design: .monospaced))
                                .foregroundStyle(settings.currentTheme.textMuted)
                                .frame(width: 70, alignment: .trailing)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.025))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(settings.currentTheme.border, lineWidth: 1)
        )
    }

    // MARK: - Data Management Card
    private var dataManagementCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "externaldrive.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(settings.currentTheme.textMuted)
                    Text("DATA & STORAGE (~/.config/seeusage/history.json)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.textMuted)
                }

                Spacer()

                if let last = analytics.lastRecordedAt {
                    Text("Last recorded: \(Formatters.relativeUpdated(for: last))")
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.textMuted)
                }
            }

            HStack(spacing: 10) {
                Button {
                    let csv = analytics.exportCSV()
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(csv, forType: .string)
                    exportMessage = "CSV copied to clipboard"
                    showExportAlert = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "doc.text.fill")
                        Text("Copy CSV")
                            .font(.system(size: 10.5, design: .monospaced))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    let json = analytics.exportJSON()
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(json, forType: .string)
                    exportMessage = "JSON copied to clipboard"
                    showExportAlert = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "curlybraces")
                        Text("Copy JSON")
                            .font(.system(size: 10.5, design: .monospaced))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button(role: .destructive) {
                    showingClearConfirmation = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "trash")
                        Text("Clear History")
                            .font(.system(size: 10.5, design: .monospaced))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if showExportAlert {
                Text(exportMessage)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.green)
                    .transition(.opacity)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.025))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(settings.currentTheme.border, lineWidth: 1)
        )
    }
}
