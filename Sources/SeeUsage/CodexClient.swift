import Foundation

public enum CodexClient {
    public static func fetch(
        profile: UsageProfile,
        executable: String,
        timeout: TimeInterval = 15
    ) async -> UsageSnapshot {
        guard let homePath = profile.homePath, !homePath.isEmpty else {
            return UsageSnapshot(
                profileID: profile.id,
                error: "CODEX_HOME path not configured."
            )
        }

        let requests = makeInputLines(method: "account/rateLimits/read", requestID: 2, params: [:])

        do {
            let result = try await ProcessRunner.run(
                executable: executable,
                arguments: ["app-server", "--stdio"],
                environment: ["CODEX_HOME": (homePath as NSString).expandingTildeInPath],
                input: requests,
                timeout: timeout,
                completionResponseID: 2
            )

            guard result.terminationStatus == 0 || !result.standardOutput.isEmpty else {
                return UsageSnapshot(
                    profileID: profile.id,
                    error: "Codex profile not authenticated."
                )
            }

            return parse(output: result.standardOutput, profileID: profile.id)
        } catch {
            return UsageSnapshot(
                profileID: profile.id,
                error: error.localizedDescription
            )
        }
    }

    public static func parse(output: Data, profileID: UUID) -> UsageSnapshot {
        let text = String(decoding: output, as: UTF8.self)
        let lines = text.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("{"),
                  let lineData = trimmed.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  (json["id"] as? Int) == 2
            else { continue }

            if let errorObj = json["error"] as? [String: Any] {
                let msg = errorObj["message"] as? String ?? "Error querying Codex limits."
                return UsageSnapshot(profileID: profileID, error: msg)
            }

            guard let result = json["result"] as? [String: Any] else {
                return UsageSnapshot(profileID: profileID, error: "Unexpected response from Codex.")
            }

            let limitBuckets: [(String, [String: Any])]
            if let byID = result["rateLimitsByLimitId"] as? [String: Any], !byID.isEmpty {
                limitBuckets = byID.keys.sorted().compactMap { key in
                    (byID[key] as? [String: Any]).map { (key, $0) }
                }
            } else if let limits = result["rateLimits"] as? [String: Any] {
                limitBuckets = [("codex", limits)]
            } else {
                return UsageSnapshot(profileID: profileID, error: "Codex profile not authenticated.")
            }

            let rawPlan = limitBuckets.compactMap { $0.1["planType"] as? String }.first
            let plan = rawPlan.map { $0.capitalized }

            var windows: [UsageWindow] = []
            for (bucketID, limits) in limitBuckets {
                for windowKey in ["primary", "secondary"] {
                    guard let obj = limits[windowKey] as? [String: Any],
                          let usedNum = (obj["usedPercent"] as? NSNumber)?.doubleValue,
                          let duration = (obj["windowDurationMins"] as? NSNumber)?.intValue
                    else { continue }

                    let remaining = max(0.0, min(100.0, 100.0 - usedNum))
                    let resetDate = (obj["resetsAt"] as? NSNumber).flatMap { value in
                        value.doubleValue > 0 ? Date(timeIntervalSince1970: value.doubleValue) : nil
                    }
                    let hasMultipleBuckets = limitBuckets.count > 1 || bucketID != "codex"
                    windows.append(UsageWindow(
                        id: "codex-\(bucketID)-\(windowKey)-\(duration)",
                        label: formatDuration(minutes: duration),
                        remainingPercent: remaining,
                        durationMinutes: duration,
                        resetsAt: resetDate,
                        scope: hasMultipleBuckets ? bucketID : nil
                    ))
                }
            }

            // Sort windows by duration (e.g. 5h before 7 dias)
            windows.sort { ($0.durationMinutes ?? 0) < ($1.durationMinutes ?? 0) }

            // Extract rateLimitResetCredits (Banked Resets)
            var availableCreditsCount = 0
            var bankedCredits: [BankedResetCredit] = []

            let resetCreditsObj = (result["rateLimitResetCredits"] as? [String: Any])
                ?? limitBuckets.compactMap { $0.1["rateLimitResetCredits"] as? [String: Any] }.first

            if let rco = resetCreditsObj {
                if let countNum = (rco["availableCount"] as? NSNumber)?.intValue {
                    availableCreditsCount = countNum
                } else if let countInt = rco["availableCount"] as? Int {
                    availableCreditsCount = countInt
                }

                if let rawList = rco["credits"] as? [[String: Any]] {
                    for (index, item) in rawList.enumerated() {
                        let creditId = item["id"] as? String
                        let resetType = item["resetType"] as? String
                        let status = item["status"] as? String ?? "available"
                        let title = item["title"] as? String
                        let desc = item["description"] as? String

                        var grantedDate: Date?
                        if let gSec = (item["grantedAt"] as? NSNumber)?.doubleValue, gSec > 0 {
                            grantedDate = Date(timeIntervalSince1970: gSec)
                        }

                        var expiresDate: Date?
                        if let eSec = (item["expiresAt"] as? NSNumber)?.doubleValue, eSec > 0 {
                            expiresDate = Date(timeIntervalSince1970: eSec)
                        }

                        bankedCredits.append(BankedResetCredit(
                            id: creditId ?? "count-only-\(profileID.uuidString)-\(index)",
                            serverCreditID: creditId,
                            resetType: resetType,
                            status: status,
                            title: title,
                            description: desc,
                            grantedAt: grantedDate,
                            expiresAt: expiresDate
                        ))
                    }
                }
            }

            // The server can redact or cap the detailed list while still returning the
            // account's full available count. Add actionable count-only entries; the
            // protocol permits consuming without a creditId.
            let availableDetails = bankedCredits.filter { $0.status.lowercased() == "available" }.count
            availableCreditsCount = max(availableCreditsCount, availableDetails)
            if availableCreditsCount > availableDetails {
                for index in availableDetails..<availableCreditsCount {
                    bankedCredits.append(BankedResetCredit(
                        id: "count-only-\(profileID.uuidString)-\(bankedCredits.count)-\(index)",
                        serverCreditID: nil,
                        title: "Available reset credit"
                    ))
                }
            }

            return UsageSnapshot(
                profileID: profileID,
                plan: plan,
                windows: windows,
                availableResetCredits: availableCreditsCount,
                bankedCredits: bankedCredits,
                fetchedAt: Date(),
                error: nil
            )
        }

        return UsageSnapshot(
            profileID: profileID,
            error: "Failed to parse Codex usage response."
        )
    }

    public static func formatDuration(minutes: Int) -> String {
        switch minutes {
        case 60:
            return "1 h"
        case 300:
            return "5 h"
        case 1440:
            return "24 h"
        case 10080:
            return "7 days"
        default:
            if minutes % 10080 == 0 {
                return "\(minutes / 10080) days"
            } else if minutes % 1440 == 0 {
                return "\(minutes / 1440) days"
            } else if minutes % 60 == 0 {
                return "\(minutes / 60) h"
            } else {
                return "\(minutes) min"
            }
        }
    }

    // MARK: - Consume Banked Reset Credit
    public static func consumeResetCredit(
        profile: UsageProfile,
        creditId: String?,
        executable: String,
        timeout: TimeInterval = 15
    ) async -> (success: Bool, message: String) {
        guard let homePath = profile.homePath, !homePath.isEmpty else {
            return (false, "CODEX_HOME path not configured.")
        }

        var params: [String: Any] = ["idempotencyKey": UUID().uuidString]
        if let creditId { params["creditId"] = creditId }
        let requests = makeInputLines(method: "account/rateLimitResetCredit/consume", requestID: 3, params: params)

        do {
            let result = try await ProcessRunner.run(
                executable: executable,
                arguments: ["app-server", "--stdio"],
                environment: ["CODEX_HOME": (homePath as NSString).expandingTildeInPath],
                input: requests,
                timeout: timeout,
                completionResponseID: 3
            )

            let text = String(decoding: result.standardOutput, as: UTF8.self)
            let lines = text.components(separatedBy: .newlines)

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.hasPrefix("{"),
                      let lineData = trimmed.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                      (json["id"] as? Int) == 3
                else { continue }

                if let errorObj = json["error"] as? [String: Any] {
                    let msg = errorObj["message"] as? String ?? "Failed to consume banked reset."
                    return (false, msg)
                }

                if let res = json["result"] as? [String: Any] {
                    guard let outcome = res["outcome"] as? String else {
                        return (false, "Codex returned a consume response without an outcome.")
                    }
                    if outcome == "reset" {
                        return (true, "Banked reset successfully activated! Your quotas are fully restored.")
                    } else if outcome == "nothingToReset" {
                        return (false, "Your quotas are already at 100%. Nothing to reset.")
                    } else if outcome == "alreadyRedeemed" {
                        return (true, "This reset credit was already redeemed. Refreshing account usage.")
                    } else if outcome == "noCredit" {
                        return (false, "No available reset credit found on this account.")
                    } else {
                        return (false, "Codex did not confirm a reset (outcome: \(outcome)).")
                    }
                }
            }

            return (false, "No confirmation received from Codex server.")
        } catch {
            return (false, error.localizedDescription)
        }
    }

    private static func makeInputLines(method: String, requestID: Int, params: [String: Any]) -> Data {
        let messages: [[String: Any]] = [
            ["jsonrpc": "2.0", "id": 1, "method": "initialize", "params": [
                "clientInfo": ["name": "SeeUsage", "version": "1.1.0"]
            ]],
            ["jsonrpc": "2.0", "method": "initialized", "params": [:]],
            ["jsonrpc": "2.0", "id": requestID, "method": method, "params": params]
        ]
        let lines = messages.compactMap { message -> String? in
            guard let data = try? JSONSerialization.data(withJSONObject: message, options: [.sortedKeys]) else {
                return nil
            }
            return String(decoding: data, as: UTF8.self)
        }
        return Data((lines.joined(separator: "\n") + "\n").utf8)
    }
}
