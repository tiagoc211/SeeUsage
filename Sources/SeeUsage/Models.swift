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

// MARK: - Banked Reset Credits (Codex On-Demand Refills)
public struct BankedResetCredit: Identifiable, Codable, Sendable {
    public let id: String
    public let resetType: String?
    public let status: String
    public let title: String?
    public let description: String?
    public let grantedAt: Date?
    public let expiresAt: Date?

    public init(
        id: String,
        resetType: String? = nil,
        status: String = "available",
        title: String? = nil,
        description: String? = nil,
        grantedAt: Date? = nil,
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.resetType = resetType
        self.status = status
        self.title = title
        self.description = description
        self.grantedAt = grantedAt
        self.expiresAt = expiresAt
    }
}

public struct UsageSnapshot: Identifiable, Codable, Sendable {
    public var id: UUID { profileID }
    public let profileID: UUID
    public let plan: String?
    public let windows: [UsageWindow]
    public let availableResetCredits: Int?
    public let bankedCredits: [BankedResetCredit]
    public let fetchedAt: Date
    public let error: String?

    public init(
        profileID: UUID,
        plan: String? = nil,
        windows: [UsageWindow] = [],
        availableResetCredits: Int? = nil,
        bankedCredits: [BankedResetCredit] = [],
        fetchedAt: Date = Date(),
        error: String? = nil
    ) {
        self.profileID = profileID
        self.plan = plan
        self.windows = windows
        self.availableResetCredits = availableResetCredits
        self.bankedCredits = bankedCredits
        self.fetchedAt = fetchedAt
        self.error = error
    }

    enum CodingKeys: String, CodingKey {
        case profileID, plan, windows, availableResetCredits, bankedCredits, fetchedAt, error
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profileID = try container.decode(UUID.self, forKey: .profileID)
        plan = try container.decodeIfPresent(String.self, forKey: .plan)
        windows = try container.decodeIfPresent([UsageWindow].self, forKey: .windows) ?? []
        availableResetCredits = try container.decodeIfPresent(Int.self, forKey: .availableResetCredits)
        bankedCredits = try container.decodeIfPresent([BankedResetCredit].self, forKey: .bankedCredits) ?? []
        fetchedAt = try container.decodeIfPresent(Date.self, forKey: .fetchedAt) ?? Date()
        error = try container.decodeIfPresent(String.self, forKey: .error)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(profileID, forKey: .profileID)
        try container.encodeIfPresent(plan, forKey: .plan)
        try container.encode(windows, forKey: .windows)
        try container.encodeIfPresent(availableResetCredits, forKey: .availableResetCredits)
        try container.encode(bankedCredits, forKey: .bankedCredits)
        try container.encode(fetchedAt, forKey: .fetchedAt)
        try container.encodeIfPresent(error, forKey: .error)
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

// MARK: - Reset Tracking & History Models

public struct ResetEvent: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let profileID: UUID
    public let profileName: String
    public let service: String          // "Codex" or "Antigravity"
    public let scope: String?            // e.g. "Gemini", "Claude", or nil
    public let windowLabel: String       // "5 h", "7 days", etc.
    public let durationMinutes: Int?     // 300, 10080, etc.
    public let quotaBefore: Double       // Quota % remaining before reset
    public let quotaAfter: Double        // Quota % remaining after reset
    public let quotaRestored: Double     // Restored percentage (+X%)
    public let nextResetAt: Date?        // Next scheduled reset

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        profileID: UUID,
        profileName: String,
        service: String,
        scope: String? = nil,
        windowLabel: String,
        durationMinutes: Int? = nil,
        quotaBefore: Double,
        quotaAfter: Double,
        quotaRestored: Double? = nil,
        nextResetAt: Date? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.profileID = profileID
        self.profileName = profileName
        self.service = service
        self.scope = scope
        self.windowLabel = windowLabel
        self.durationMinutes = durationMinutes
        self.quotaBefore = quotaBefore
        self.quotaAfter = quotaAfter
        self.quotaRestored = quotaRestored ?? max(0.0, quotaAfter - quotaBefore)
        self.nextResetAt = nextResetAt
    }
}

public struct UpcomingResetInfo: Identifiable, Codable, Hashable, Sendable {
    public var id: String { "\(profileID.uuidString)-\(scope ?? "")-\(windowLabel)" }
    public let profileID: UUID
    public let profileName: String
    public let service: String
    public let scope: String?
    public let windowLabel: String
    public let durationMinutes: Int?
    public let currentRemainingPercent: Double?
    public let resetsAt: Date

    public init(
        profileID: UUID,
        profileName: String,
        service: String,
        scope: String? = nil,
        windowLabel: String,
        durationMinutes: Int? = nil,
        currentRemainingPercent: Double? = nil,
        resetsAt: Date
    ) {
        self.profileID = profileID
        self.profileName = profileName
        self.service = service
        self.scope = scope
        self.windowLabel = windowLabel
        self.durationMinutes = durationMinutes
        self.currentRemainingPercent = currentRemainingPercent
        self.resetsAt = resetsAt
    }

    public var secondsUntilReset: TimeInterval {
        resetsAt.timeIntervalSince(Date())
    }

    public var isExpired: Bool {
        secondsUntilReset <= 0
    }
}
