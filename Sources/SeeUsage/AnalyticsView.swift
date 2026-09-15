import SwiftUI
import Charts

public enum AnalyticsTab: String, CaseIterable, Identifiable {
    case trends = "Trends & Charts"
    case resets = "Resets & Cycles"
    public var id: String { rawValue }
}

public struct AnalyticsView: View {
    @Bindable var settings = SettingsStore.shared
    var analytics = AnalyticsManager.shared
    var store = UsageStore.shared

    @State private var activeTab: AnalyticsTab = .resets
    @State private var selectedDays: Int = 7
    @State private var resetFilterService: String = "All"
    @State private var showingClearConfirmation = false
    @State private var showingClearResetsConfirmation = false
    @State private var exportMessage = ""
    @State private var showExportAlert = false

    public init(initialTab: AnalyticsTab = .resets) {
        _activeTab = State(initialValue: initialTab)
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 20) {
                // MARK: Section Header & Mode Picker
                headerSection

                if activeTab == .trends {
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
                } else {
                    // MARK: Resets & Cycles Tab
                    resetMetricsOverviewCards

                    // Banked Resets Section (Manual Refills)
                    bankedResetsSection

                    // MARK: Scheduled Upcoming Cycles Section
                    upcomingCyclesSection

                    // MARK: Logged Reset Events Section
                    resetAuditLogSection

                    // MARK: Resets Data Management
                    resetsDataManagementCard
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(settings.currentTheme.background)
        .alert("Clear Analytics History?", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                analytics.clearHistory()
            }
        } message: {
            Text("This will delete ~/.config/seeusage/history.json and reset all collected consumption metrics.")
        }
        .alert("Clear Reset History?", isPresented: $showingClearResetsConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear Resets", role: .destructive) {
                analytics.clearResets()
            }
        } message: {
            Text("This will delete ~/.config/seeusage/resets.json and clear all logged reset events.")
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(activeTab == .trends ? "// QUOTA ANALYTICS & USAGE HISTORY" : "// QUOTA RESETS & CYCLE SCHEDULES")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.accent)

                    Text(activeTab == .trends
                        ? "Local historical metrics tracking peak burn hours, profile comparison, and 7-day quota trends."
                        : "Active renewal schedules, countdown timers, and detected quota reset history for Codex & Antigravity.")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                // Mode Picker (Trends vs Resets)
                Picker("", selection: $activeTab) {
                    Label("Trends", systemImage: "chart.xyaxis.line").tag(AnalyticsTab.trends)
                    Label("Resets & Cycles", systemImage: "arrow.counterclockwise.circle").tag(AnalyticsTab.resets)
                }
                .pickerStyle(.segmented)
                .frame(width: 210)
            }

            if activeTab == .trends {
                HStack {
                    Spacer()
                    Picker("", selection: $selectedDays) {
                        Text("24 Hours").tag(1)
                        Text("7 Days").tag(7)
                        Text("30 Days").tag(30)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                }
            }
        }
    }

    // MARK: - Top Metric Cards (Trends)
    private var metricsOverviewCards: some View {
        let metrics = analytics.computeMetrics(days: selectedDays)

        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
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

    // MARK: - Top Metric Cards (Resets)
    private var resetMetricsOverviewCards: some View {
        let upcoming = analytics.computeUpcomingResets(from: store.snapshots)
        let activeNearest = upcoming.first(where: { $0.resetsAt > Date() })
        let resets = analytics.resetEvents

        let nearestStr: String
        let nearestSub: String
        if let nearest = activeNearest {
            nearestStr = Formatters.resetDescription(for: nearest.resetsAt)
            nearestSub = "\(nearest.profileName) (\(nearest.windowLabel))"
        } else {
            nearestStr = "None"
            nearestSub = "sync via seeusage -r"
        }

        let avgRestoredStr: String
        if !resets.isEmpty {
            let avg = resets.reduce(0.0) { $0 + $1.quotaRestored } / Double(resets.count)
            avgRestoredStr = String(format: "+%.0f%%", avg)
        } else {
            avgRestoredStr = "--%"
        }

        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
            metricCard(
                title: "NEXT RENEWAL",
                value: nearestStr,
                subtext: nearestSub,
                icon: "clock.arrow.circlepath",
                color: settings.currentTheme.cyan
            )

            metricCard(
                title: "ACTIVE CYCLES",
                value: "\(upcoming.count)",
                subtext: "tracked rate limits",
                icon: "timer",
                color: settings.currentTheme.green
            )

            metricCard(
                title: "RESETS LOGGED",
                value: "\(resets.count)",
                subtext: "in resets.json",
                icon: "arrow.counterclockwise.circle.fill",
                color: settings.currentTheme.purple
            )

            metricCard(
                title: "AVG RESTORED",
                value: avgRestoredStr,
                subtext: "quota recovered per reset",
                icon: "bolt.fill",
                color: settings.currentTheme.amber
            )

            metricCard(
                title: "BANKED RESETS",
                value: "\(analytics.getAvailableBankedCredits(from: store.snapshots, profiles: settings.codexProfiles).count)",
                subtext: "ready to redeem",
                icon: "bolt.circle.fill",
                color: settings.currentTheme.amber
            )
        }
    }

    private func metricCard(title: String, value: String, subtext: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(color)

                Text(title)
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.textMuted)
                    .tracking(0.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(settings.currentTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(subtext)
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundStyle(settings.currentTheme.textMuted)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(settings.currentTheme.border, lineWidth: 1)
        )
    }


    // MARK: - Banked Resets Section
    @ViewBuilder
    private var bankedResetsSection: some View {
        let banked = analytics.getAvailableBankedCredits(
            from: store.snapshots,
            profiles: settings.codexProfiles
        )

        if !banked.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(settings.currentTheme.amber)
                        Text("BANKED RESETS RESERVE (CRÉDITOS MANUAIS)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(settings.currentTheme.textPrimary)
                    }

                    Spacer()

                    Text("\(banked.count) disponível")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.amber)
                }

                VStack(spacing: 8) {
                    ForEach(banked, id: \.credit.id) { item in
                        BankedResetBannerView(profile: item.profile, credit: item.credit)
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(settings.currentTheme.amber.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(settings.currentTheme.amber.opacity(0.3), lineWidth: 1)
            )
        }
    }

        // MARK: - Scheduled Upcoming Cycles Section
    private var upcomingCyclesSection: some View {
        let upcoming = analytics.computeUpcomingResets(from: store.snapshots)
            .filter { $0.resetsAt > Date().addingTimeInterval(-300) }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(settings.currentTheme.cyan)
                        .frame(width: 6, height: 6)
                    Text("ACTIVE RENEWAL SCHEDULES (UPCOMING)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.textPrimary)
                }

                Spacer()

                Text("\(upcoming.count) active windows")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.textMuted)
            }

            if upcoming.isEmpty {
                VStack(spacing: 8) {
                    Text("No scheduled renewal cycles found.")
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.textSecondary)
                    Text("Run `seeusage -r` in terminal or click refresh in menu bar to fetch active rate limits.")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.textMuted)
                }
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.02))
                .cornerRadius(6)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 10)], spacing: 10) {
                    ForEach(upcoming) { u in
                        upcomingCard(for: u)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.025))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(settings.currentTheme.border, lineWidth: 1)
        )
    }

    private func upcomingCard(for u: UpcomingResetInfo) -> some View {
        let isAgy = u.service == "Antigravity"
        let serviceColor = isAgy ? settings.currentTheme.purple : settings.currentTheme.green
        let df = DateFormatter()
        df.dateFormat = "EEE, MMM d, HH:mm"

        let pct = u.currentRemainingPercent ?? 100.0
        let quotaColor: Color = pct <= 15 ? settings.currentTheme.red : (pct <= 35 ? settings.currentTheme.amber : settings.currentTheme.green)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                // Service & Profile Badge
                HStack(spacing: 4) {
                    Text(isAgy ? "[agy]" : "[codex]")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(serviceColor)

                    Text(u.profileName)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.textPrimary)
                        .lineLimit(1)

                    if let scope = u.scope {
                        Text("(\(scope.lowercased()))")
                            .font(.system(size: 9.5, design: .monospaced))
                            .foregroundStyle(settings.currentTheme.textMuted)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }

                Spacer()

                // Window duration pill
                Text(u.windowLabel)
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(settings.currentTheme.accent.opacity(0.12))
                    .cornerRadius(4)
            }

            // Quota Bar
            HStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 6)
                        Capsule()
                            .fill(quotaColor)
                            .frame(width: max(3, geo.size.width * CGFloat(pct / 100.0)), height: 6)
                    }
                }
                .frame(height: 6)

                Text(String(format: "%.0f%%", pct))
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(quotaColor)
                    .frame(width: 34, alignment: .trailing)
            }

            // Scheduled time & Countdown
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("RESETS AT")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.textMuted)
                    Text(df.string(from: u.resetsAt))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.textSecondary)
                }

                Spacer()

                // Countdown Badge
                HStack(spacing: 3) {
                    Image(systemName: "stopwatch")
                        .font(.system(size: 9))
                    Text(Formatters.resetDescription(for: u.resetsAt).lowercased())
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                }
                .foregroundStyle(settings.currentTheme.cyan)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(settings.currentTheme.cyan.opacity(0.12))
                .cornerRadius(4)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(settings.currentTheme.border.opacity(0.7), lineWidth: 1)
        )
    }

    // MARK: - Reset Audit Log Section
    private var resetAuditLogSection: some View {
        let events = analytics.getResetEvents(limit: 50, service: resetFilterService == "All" ? nil : resetFilterService)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "list.bullet.rectangle.portrait.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(settings.currentTheme.purple)
                    Text("RESET AUDIT LOG (HISTÓRICO DE RESETS)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.textPrimary)
                }

                Spacer()

                // Filter by Service
                Picker("", selection: $resetFilterService) {
                    Text("All").tag("All")
                    Text("Codex").tag("Codex")
                    Text("Antigravity").tag("Antigravity")
                }
                .pickerStyle(.segmented)
                .frame(width: 190)
            }

            if events.isEmpty {
                VStack(spacing: 10) {
                    Text("No past reset events recorded yet.")
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.textSecondary)

                    Text("SeeUsage records a reset automatically whenever quota renews or scheduled windows elapse.")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.textMuted)

                    Button {
                        analytics.seedDemoResetDataIfEmpty()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "sparkles")
                            Text("Seed Sample Reset History")
                                .font(.system(size: 10.5, design: .monospaced))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(settings.currentTheme.accent)
                    .padding(.top, 4)
                }
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.02))
                .cornerRadius(6)
            } else {
                VStack(spacing: 6) {
                    ForEach(events) { event in
                        resetEventRow(for: event)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.025))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(settings.currentTheme.border, lineWidth: 1)
        )
    }

    private func resetEventRow(for event: ResetEvent) -> some View {
        let isAgy = event.service == "Antigravity"
        let serviceColor = isAgy ? settings.currentTheme.purple : settings.currentTheme.green
        let df = DateFormatter()
        df.dateFormat = "MMM d, HH:mm"

        return HStack(spacing: 8) {
            // Timestamp
            Text(df.string(from: event.timestamp))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(settings.currentTheme.textMuted)
                .lineLimit(1)

            // Service & Profile
            HStack(spacing: 4) {
                Text(isAgy ? "[agy]" : "[cx]")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(serviceColor)

                Text(event.profileName)
                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.textPrimary)
                    .lineLimit(1)

                if let scope = event.scope {
                    Text("(\(scope.lowercased()))")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.textMuted)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .lineLimit(1)

            // Window tag
            Text(event.windowLabel)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(settings.currentTheme.textSecondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.04))
                .cornerRadius(3)
                .lineLimit(1)

            Spacer()

            // Quota Jump
            HStack(spacing: 3) {
                Text(String(format: "%.0f%%", event.quotaBefore))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.amber)

                Image(systemName: "arrow.right")
                    .font(.system(size: 7.5))
                    .foregroundStyle(settings.currentTheme.textMuted)

                Text(String(format: "%.0f%%", event.quotaAfter))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.green)
            }
            .lineLimit(1)

            // Restored tag
            Text(String(format: "+%.0f%%", event.quotaRestored))
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .foregroundStyle(settings.currentTheme.green)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(settings.currentTheme.green.opacity(0.12))
                .cornerRadius(3)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.02))
        .cornerRadius(4)
    }

    // MARK: - Resets Data Management Card
    private var resetsDataManagementCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "externaldrive.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(settings.currentTheme.textMuted)
                    Text("STORAGE & EXPORT (~/.config/seeusage/resets.json)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.textMuted)
                }

                Spacer()

                Text("\(analytics.resetEvents.count) reset events recorded")
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.textMuted)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                Button {
                    let csv = analytics.exportResetsCSV()
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(csv, forType: .string)
                    exportMessage = "Resets CSV copied to clipboard"
                    showExportAlert = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "doc.text.fill")
                        Text("Copy Resets CSV")
                            .font(.system(size: 10.5, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    let json = analytics.exportResetsJSON()
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(json, forType: .string)
                    exportMessage = "Resets JSON copied to clipboard"
                    showExportAlert = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "curlybraces")
                        Text("Copy Resets JSON")
                            .font(.system(size: 10.5, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    analytics.seedDemoResetDataIfEmpty()
                    exportMessage = "Seeded sample reset history"
                    showExportAlert = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                        Text("Seed Demo Resets")
                            .font(.system(size: 10.5, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(role: .destructive) {
                    showingClearResetsConfirmation = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "trash")
                        Text("Clear Resets")
                            .font(.system(size: 10.5, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity)
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

    // MARK: - Empty State Banner
    private var emptyStateBanner: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 28))
                .foregroundStyle(settings.currentTheme.accent)

            Text("Collecting Quota History...")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(settings.currentTheme.textPrimary)

            Text("SeeUsage continuously samples rate limits every time a background refresh occurs. You need at least 2 snapshot intervals to plot consumption curves.")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(settings.currentTheme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 480)

            Button {
                analytics.seedDemoDataIfEmpty()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                    Text("Populate Realistic Demo History")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(settings.currentTheme.accent)
            .padding(.top, 4)
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 20)
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

    // MARK: - Chart 1: Daily Trend
    private var dailyTrendChartCard: some View {
        let daily = analytics.computeDailyConsumption(days: selectedDays)

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("// DAILY QUOTA BURN TREND")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.textPrimary)

                    Text("Total percentage points dropped each day across profiles.")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.textMuted)
                }

                Spacer()
            }

            if daily.isEmpty {
                Text("No daily consumption data recorded.")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.textMuted)
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(daily) { item in
                    BarMark(
                        x: .value("Day", item.weekdayLabel),
                        y: .value("Burn %", item.consumptionPercent)
                    )
                    .foregroundStyle(by: .value("Profile", item.profileName))
                    .cornerRadius(3)
                }
                .chartForegroundStyleScale([
                    "Pessoal": settings.currentTheme.cyan,
                    "Trabalho": settings.currentTheme.green,
                    "Antigravity": settings.currentTheme.purple,
                    "Codex": settings.currentTheme.accent
                ])
                .chartLegend(position: .top, alignment: .trailing)
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine().foregroundStyle(settings.currentTheme.border.opacity(0.5))
                        AxisValueLabel().foregroundStyle(settings.currentTheme.textMuted)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine().foregroundStyle(settings.currentTheme.border.opacity(0.5))
                        AxisValueLabel().foregroundStyle(settings.currentTheme.textMuted)
                    }
                }
                .frame(height: 190)
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

    // MARK: - Chart 2: Hourly Distribution (Peak Hours)
    private var hourlyDistributionChartCard: some View {
        let hourly = analytics.computeHourlyConsumption(days: selectedDays)

        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("// PEAK CONSUMPTION HOURS (00:00 - 23:00)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.textPrimary)

                Text("Distribution of quota usage across the hours of the day.")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.textMuted)
            }

            Chart(hourly) { item in
                AreaMark(
                    x: .value("Hour", item.hour),
                    y: .value("Quota Consumed", item.consumptionPercent)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [settings.currentTheme.accent.opacity(0.5), settings.currentTheme.accent.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.monotone)

                LineMark(
                    x: .value("Hour", item.hour),
                    y: .value("Quota Consumed", item.consumptionPercent)
                )
                .foregroundStyle(settings.currentTheme.accent)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.monotone)
            }
            .chartXScale(domain: 0...23)
            .chartXAxis {
                AxisMarks(values: [0, 4, 8, 12, 16, 20, 23]) { val in
                    AxisGridLine().foregroundStyle(settings.currentTheme.border.opacity(0.5))
                    if let h = val.as(Int.self) {
                        AxisValueLabel(String(format: "%02d:00", h))
                            .foregroundStyle(settings.currentTheme.textMuted)
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(settings.currentTheme.border.opacity(0.5))
                    AxisValueLabel().foregroundStyle(settings.currentTheme.textMuted)
                }
            }
            .frame(height: 160)
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

    // MARK: - Chart 3: Profile Comparison
    private var profileComparisonCard: some View {
        let summaries = analytics.computeProfileSummaries(days: selectedDays)

        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("// USAGE BREAKDOWN BY ACCOUNT & MODEL")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.textPrimary)

                Text("Relative quota share consumed across Codex accounts and Antigravity models.")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.textMuted)
            }

            if summaries.isEmpty {
                Text("No breakdown data available.")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.textMuted)
                    .frame(height: 80)
            } else {
                VStack(spacing: 8) {
                    ForEach(summaries) { item in
                        HStack(spacing: 12) {
                            Text(item.name)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(settings.currentTheme.textPrimary)
                                .frame(width: 140, alignment: .leading)

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

    // MARK: - Data Management Card (Trends)
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

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
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
                    .frame(maxWidth: .infinity)
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
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(role: .destructive) {
                    showingClearConfirmation = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "trash")
                        Text("Clear History")
                            .font(.system(size: 10.5, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity)
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
