import SwiftUI
import AppKit

// MARK: - Floating Mini-HUD View
public struct FloatingHUDView: View {
    @Bindable var settings = SettingsStore.shared
    var store = UsageStore.shared
    @State private var isHovered: Bool = false

    public init() {}

    public var body: some View {
        Group {
            if settings.hudCompactMode {
                compactHUDContent
            } else {
                expandedHUDContent
            }
        }
        .padding(10)
        .background(
            ZStack {
                // Frosted Glass Material Base
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)

                // Theme Tint with Configurable Opacity
                settings.currentTheme.background
                    .opacity(settings.hudOpacity)

                // Glowing/Accent Border
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isHovered ? settings.currentTheme.borderActive : settings.currentTheme.border,
                        lineWidth: 1
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 4)
        )
        .onHover { hovering in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                isHovered = hovering
            }
        }
    }

    // MARK: - Compact Mode (Sleek Horizontal Pill)
    private var compactHUDContent: some View {
        HStack(spacing: 8) {
            // Drag handle / Status dot
            Circle()
                .fill(healthColor(percent: store.minRemainingPercent ?? 100))
                .frame(width: 8, height: 8)
                .shadow(color: healthColor(percent: store.minRemainingPercent ?? 100).opacity(0.6), radius: 3)

            // Codex Mini
            if let cx = store.codexLowestPercent {
                HStack(spacing: 3) {
                    Text("cx:")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.textMuted)
                    Text("\(cx)%")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.accent)
                }
            }

            // Divider
            if store.codexLowestPercent != nil && store.antigravityLowestPercent != nil {
                Text("·")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(settings.currentTheme.textMuted.opacity(0.6))
            }

            // Antigravity Mini
            if let ag = store.antigravityLowestPercent {
                HStack(spacing: 3) {
                    Text("ag:")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.textMuted)
                    Text("\(ag)%")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(settings.currentTheme.cyan)
                }
            }

            // Micro Gauge
            if let lowest = store.minRemainingPercent {
                miniHorizontalGauge(percent: Double(lowest), width: 34, height: 6)
            }

            // Controls (Visible on hover or discreetly dimmed)
            HStack(spacing: 4) {
                // Expand button
                hudIconButton(icon: "arrow.up.left.and.arrow.down.right", help: "Expand HUD") {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        settings.hudCompactMode = false
                    }
                }

                // Pin toggle button
                hudIconButton(
                    icon: settings.hudAlwaysOnTop ? "pin.fill" : "pin",
                    help: settings.hudAlwaysOnTop ? "Always on top (active)" : "Desktop level",
                    active: settings.hudAlwaysOnTop
                ) {
                    settings.hudAlwaysOnTop.toggle()
                }

                // Close button
                hudIconButton(icon: "xmark", help: "Hide HUD") {
                    FloatingHUDManager.shared.hide()
                }
            }
            .opacity(isHovered ? 1.0 : 0.35)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }

    // MARK: - Expanded Mode (Card Dashboard)
    private var expandedHUDContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(alignment: .center, spacing: 6) {
                // Pulsing/Health Dot
                Circle()
                    .fill(healthColor(percent: store.minRemainingPercent ?? 100))
                    .frame(width: 7, height: 7)

                Text("SEEUSAGE")
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.accent)

                Text("HUD")
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.textMuted)

                Spacer()

                if let lowest = store.minRemainingPercent {
                    Text("\(lowest)%")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(healthColor(percent: lowest))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(
                            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                                .fill(healthColor(percent: lowest).opacity(0.15))
                        )
                }

                // Quick Header Actions
                HStack(spacing: 3) {
                    hudIconButton(
                        icon: "arrow.clockwise",
                        help: "Refresh Quotas",
                        isSpinning: store.isRefreshing
                    ) {
                        Task { await store.refresh() }
                    }

                    hudIconButton(
                        icon: "arrow.down.right.and.arrow.up.left",
                        help: "Compact Pill Mode"
                    ) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            settings.hudCompactMode = true
                        }
                    }

                    hudIconButton(
                        icon: settings.hudAlwaysOnTop ? "pin.fill" : "pin",
                        help: settings.hudAlwaysOnTop ? "Always on top (active)" : "Desktop level",
                        active: settings.hudAlwaysOnTop
                    ) {
                        settings.hudAlwaysOnTop.toggle()
                    }

                    hudIconButton(icon: "xmark", help: "Hide HUD") {
                        FloatingHUDManager.shared.hide()
                    }
                }
                .opacity(isHovered ? 1.0 : 0.6)
            }

            Rectangle()
                .fill(settings.currentTheme.border)
                .frame(height: 1)

            // Codex Section
            if !settings.codexProfiles.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("CODEX")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(settings.currentTheme.textMuted)
                        Spacer()
                    }

                    ForEach(settings.codexProfiles) { profile in
                        if let snapshot = store.snapshots[profile.id], !snapshot.windows.isEmpty {
                            profileHUDCard(name: profile.name, windows: snapshot.windows)
                        } else {
                            HStack {
                                Text(profile.name)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(settings.currentTheme.textPrimary)
                                Spacer()
                                Text("syncing...")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(settings.currentTheme.textMuted)
                            }
                            .padding(6)
                            .background(Color.white.opacity(0.03))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                    }
                }
            }

            // Antigravity Section
            if let agySnap = store.snapshots[SettingsStore.antigravityProfileID], !agySnap.windows.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("ANTIGRAVITY")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(settings.currentTheme.cyan)
                        Spacer()
                    }

                    profileHUDCard(name: "agy", windows: agySnap.windows)
                }
            }

            // Subtle Footer
            HStack {
                Text(timeAgoString(from: store.lastUpdated))
                    .font(.system(size: 8.5, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.textMuted.opacity(0.7))

                Spacer()

                Text("drag to move")
                    .font(.system(size: 8.5, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.textMuted.opacity(0.5))
            }
        }
        .frame(width: 250)
    }

    // MARK: - Subcomponents
    private func profileHUDCard(name: String, windows: [UsageWindow]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(name)
                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(settings.currentTheme.textPrimary)
                Spacer()
            }

            ForEach(windows.prefix(2)) { window in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(window.label)
                            .font(.system(size: 9.5, design: .monospaced))
                            .foregroundStyle(settings.currentTheme.textSecondary)

                        Spacer()

                        if let resets = window.resetsAt {
                            Text(WatchDashboard.countdownString(until: resets))
                                .font(.system(size: 8.5, design: .monospaced))
                                .foregroundStyle(settings.currentTheme.textMuted)
                        }

                        if let pct = window.remainingPercent {
                            Text("\(Int(round(pct)))%")
                                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(healthColor(percent: Int(round(pct))))
                        }
                    }

                    if let pct = window.remainingPercent {
                        miniHorizontalGauge(percent: pct, width: nil, height: 3.5)
                    }
                }
            }
        }
        .padding(7)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(settings.currentTheme.border.opacity(0.5), lineWidth: 1)
                )
        )
    }

    private func miniHorizontalGauge(percent: Double, width: CGFloat?, height: CGFloat) -> some View {
        GeometryReader { geo in
            let w = width ?? geo.size.width
            let fillWidth = max(2, w * CGFloat(max(0, min(100, percent))) / 100.0)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: w, height: height)

                Capsule()
                    .fill(healthColor(percent: Int(round(percent))))
                    .frame(width: fillWidth, height: height)
            }
        }
        .frame(width: width, height: height)
    }

    private func hudIconButton(
        icon: String,
        help: String,
        active: Bool = false,
        isSpinning: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(
                    active ? settings.currentTheme.accent : settings.currentTheme.textMuted
                )
                .rotationEffect(.degrees(isSpinning ? 360 : 0))
                .animation(
                    isSpinning ? .linear(duration: 1.0).repeatForever(autoreverses: false) : .default,
                    value: isSpinning
                )
                .frame(width: 16, height: 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func healthColor(percent: Int) -> Color {
        if percent <= 15 {
            return settings.currentTheme.red
        } else if percent <= 40 {
            return settings.currentTheme.amber
        } else {
            return settings.currentTheme.green
        }
    }

    private func timeAgoString(from date: Date?) -> String {
        guard let date = date else { return "never synced" }
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 {
            return "\(seconds)s ago"
        }
        let mins = seconds / 60
        return "\(mins)m ago"
    }
}

// MARK: - NSVisualEffectView Wrapper
struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
