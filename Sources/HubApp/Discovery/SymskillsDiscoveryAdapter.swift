import Foundation
import SymairaCLIRunner

/// Adapter that calls `symskills discover --json` and maps the output
/// to the Source Discovery Contract v1 format.
actor SymskillsDiscoveryAdapter: SourceDiscoveryAdapter {
    private let binaryPath: String
    private let runner: CLIRunner

    init(binaryPath: String = "/opt/homebrew/bin/symskills", runner: CLIRunner = CLIRunner()) {
        self.binaryPath = binaryPath
        self.runner = runner
    }

    func discover() async throws -> [DiscoveredSource] {
        let data = try await runSymskillsDiscover()
        let response = try JSONDecoder().decode(SymskillsDiscoverResponse.self, from: data)
        return response.candidates.map { $0.toDiscoveredSource() }
    }

    /// Run `symskills discover --json` and return stdout data.
    /// Uses the shared `CLIRunner`, which terminates the subprocess on task
    /// cancellation, so a hung binary cannot leak across refreshes.
    private func runSymskillsDiscover() async throws -> Data {
        do {
            return try await runner.runChecked(
                URL(fileURLWithPath: binaryPath),
                arguments: ["discover", "--json"]
            )
        } catch let error as CLIRunnerError {
            switch error {
            case .executionFailed(_, let stderr):
                throw DiscoveryError.invalidResponse(stderr)
            case .timeout(let seconds):
                throw DiscoveryError.timeout("symskills (\(Int(seconds))s)")
            default:
                throw DiscoveryError.toolUnavailable("symskills")
            }
        } catch {
            // Binary missing or not executable.
            throw DiscoveryError.toolUnavailable("symskills")
        }
    }
}

// MARK: - symskills JSON types

private struct SymskillsDiscoverResponse: Codable {
    let candidates: [SymskillsCandidate]
}

private struct SymskillsCandidate: Codable {
    let sourceID: String
    let target: String
    let kind: String
    let displayName: String
    let location: String
    let managed: Bool
    let valid: Bool
    let source: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case sourceID = "source_id"
        case target, kind
        case displayName = "display_name"
        case location, managed, valid, source, status
    }

    func toDiscoveredSource() -> DiscoveredSource {
        DiscoveredSource(
            sourceID: "symskills:\(sourceID)",
            tool: "symskills",
            kind: kind.replacingOccurrences(of: "_", with: "-"),
            displayName: displayName,
            location: location,
            capabilities: ["import"],
            itemCount: nil,
            lastSeen: ISO8601DateFormatter().string(from: Date()),
            privacyHint: "none"
        )
    }
}
