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
                error: "Caminho CODEX_HOME não configurado."
            )
        }

        let requests = [
            #"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"clientInfo":{"name":"SeeUsage","version":"1.0.0"}}}"#,
            #"{"jsonrpc":"2.0","method":"initialized","params":{}}"#,
            #"{"jsonrpc":"2.0","id":2,"method":"account/rateLimits/read","params":{}}"#
        ].joined(separator: "\n") + "\n"

        do {
            let result = try await ProcessRunner.run(
                executable: executable,
                arguments: ["app-server", "--stdio"],
                environment: ["CODEX_HOME": (homePath as NSString).expandingTildeInPath],
                input: Data(requests.utf8),
                timeout: timeout,
                completionMarker: #""id":2"#
            )

            guard result.terminationStatus == 0 || !result.standardOutput.isEmpty else {
                return UsageSnapshot(
                    profileID: profile.id,
                    error: "Perfil Codex não autenticado."
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
                let msg = errorObj["message"] as? String ?? "Erro ao consultar limites do Codex."
                return UsageSnapshot(profileID: profileID, error: msg)
            }

            guard let result = json["result"] as? [String: Any] else {
                return UsageSnapshot(profileID: profileID, error: "Resposta inesperada do Codex.")
            }

            var limitDict: [String: Any]? = result["rateLimits"] as? [String: Any]
            if limitDict == nil, let byID = result["rateLimitsByLimitId"] as? [String: Any] {
                limitDict = (byID["codex"] as? [String: Any]) ?? byID.values.compactMap { $0 as? [String: Any] }.first
            }

            guard let limits = limitDict else {
                return UsageSnapshot(profileID: profileID, error: "Perfil Codex não autenticado.")
            }

            let rawPlan = limits["planType"] as? String
            let plan = rawPlan.map { $0.capitalized }

            var windows: [UsageWindow] = []
            var seenDurations = Set<Int>()

            func addWindow(key: String, object: [String: Any]?) {
                guard let obj = object,
                      let usedNum = (obj["usedPercent"] as? NSNumber)?.doubleValue,
                      let duration = (obj["windowDurationMins"] as? NSNumber)?.intValue,
                      seenDurations.insert(duration).inserted
                else { return }

                let clampedRemaining = max(0.0, min(100.0, 100.0 - usedNum))
                let label = formatDuration(minutes: duration)

                var resetsAt: Date?
                if let resetSeconds = (obj["resetsAt"] as? NSNumber)?.doubleValue, resetSeconds > 0 {
                    resetsAt = Date(timeIntervalSince1970: resetSeconds)
                }

                windows.append(UsageWindow(
                    id: "codex-\(key)-\(duration)",
                    label: label,
                    remainingPercent: clampedRemaining,
                    durationMinutes: duration,
                    resetsAt: resetsAt
                ))
            }

            addWindow(key: "primary", object: limits["primary"] as? [String: Any])
            addWindow(key: "secondary", object: limits["secondary"] as? [String: Any])

            // Sort windows by duration (e.g. 5h before 7 dias)
            windows.sort { ($0.durationMinutes ?? 0) < ($1.durationMinutes ?? 0) }

            return UsageSnapshot(
                profileID: profileID,
                plan: plan,
                windows: windows,
                fetchedAt: Date(),
                error: nil
            )
        }

        return UsageSnapshot(
            profileID: profileID,
            error: "Não foi possível interpretar a usage do Codex."
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
            return "7 dias"
        default:
            if minutes % 10080 == 0 {
                return "\(minutes / 10080) dias"
            } else if minutes % 1440 == 0 {
                return "\(minutes / 1440) dias"
            } else if minutes % 60 == 0 {
                return "\(minutes / 60) h"
            } else {
                return "\(minutes) min"
            }
        }
    }
}
