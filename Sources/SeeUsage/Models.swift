import Foundation
import CryptoKit

public enum UUIDHelper {
    public static func deterministic(for string: String) -> UUID {
        let digest = Insecure.MD5.hash(data: Data(string.utf8))
        var bytes = Array(digest)
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}

public enum ProviderKind: String, Codable, Sendable {
    case codex
    case antigravity
}

public struct UsageProfile: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var provider: ProviderKind
    public var name: String
    public var homePath: String?

    public init(id: UUID = UUID(), provider: ProviderKind, name: String, homePath: String? = nil) {
        self.id = id
        self.provider = provider
        self.name = name
        self.homePath = homePath
    }
}

public struct UsageWindow: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let label: String
    public let remainingPercent: Double?
    public let durationMinutes: Int?
    public let resetsAt: Date?
    public let scope: String?

    public init(
        id: String,
        label: String,
        remainingPercent: Double?,
        durationMinutes: Int? = nil,
        resetsAt: Date? = nil,
        scope: String? = nil
    ) {
        self.id = id
        self.label = label
        self.remainingPercent = remainingPercent
        self.durationMinutes = durationMinutes
        self.resetsAt = resetsAt
        self.scope = scope
    }
}

public struct UsageSnapshot: Identifiable, Codable, Sendable {
    public var id: UUID { profileID }
    public let profileID: UUID
    public let plan: String?
    public let windows: [UsageWindow]
    public let fetchedAt: Date
    public let error: String?

    public init(
        profileID: UUID,
        plan: String? = nil,
        windows: [UsageWindow] = [],
        fetchedAt: Date = Date(),
        error: String? = nil
    ) {
        self.profileID = profileID
        self.plan = plan
        self.windows = windows
        self.fetchedAt = fetchedAt
        self.error = error
    }

    public var isStale: Bool {
        Date().timeIntervalSince(fetchedAt) > 600
    }
}

// MARK: - Menu Bar Display Modes
public enum MenuBarDisplayMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case percent = "percent"      // Lowest Quota (e.g. 47%)
    case dual = "dual"            // Dual Quotas (e.g. cx: 92% · ag: 81%)
    case gauge = "gauge"          // Mini Graphic Gauge (e.g. ■■■□ 47%)
    case iconOnly = "iconOnly"    // Status Dot / Icon Only

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .percent: return "Lowest Quota"
        case .dual: return "Dual Quotas"
        case .gauge: return "Mini Gauge"
        case .iconOnly: return "Icon Only"
        }
    }

    public var subtitle: String {
        switch self {
        case .percent: return "Shows icon and lowest remaining percentage across all services"
        case .dual: return "Shows primary Codex and Antigravity quotas side by side"
        case .gauge: return "Renders a high-resolution micro progress bar and percentage"
        case .iconOnly: return "Ultra-clean status indicator with health color dot"
        }
    }

    public var badgeLabel: String {
        switch self {
        case .percent: return "icon + %"
        case .dual: return "cx + ag"
        case .gauge: return "bar + %"
        case .iconOnly: return "icon"
        }
    }
}
