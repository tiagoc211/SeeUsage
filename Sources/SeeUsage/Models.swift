import Foundation

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

public struct UsageSnapshot: Identifiable, Sendable {
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
