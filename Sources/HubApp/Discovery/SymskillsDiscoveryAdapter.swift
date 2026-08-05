import Foundation
import SymairaCLIRunner
import SymairaToolKit

/// Adapter that calls `symskills discover --json` and maps the output
/// to the Source Discovery Contract v1 format.
actor SymskillsDiscoveryAdapter: SourceDiscoveryAdapter {
    private let binaryPath: String
    private let runner: CLIRunner

    /// Resolve the binary through appkit's `BinaryLocator` (bundle → PATH →
    /// Homebrew), keeping the legacy Homebrew path as a last-resort fallback.
    /// `binaryPath` stays injectable for stub-binary tests.
    init(binaryPath: String? = nil, runner: CLIRunner = CLIRunner()) {
        self.binaryPath = binaryPath ?? Self.locateBinary("symskills")
        self.runner = runner
    }

    func discover() async throws -> [DiscoveredSource] {
        let data = try await runSymskillsDiscover()
        let response = try JSONDecoder().decode(SymskillsDiscoverResponse.self, from: data)

        // Schema handshake: validate when the CLI reports a version
        // (symskills ≥ the schema_version envelope change). Older installs
        // without the field are treated as v1 best-effort, mirroring the
        // version --json convention, so nothing breaks mid-migration.
        if let actual = response.schemaVersion,
           actual != DiscoveryContract.expectedSchemaVersion {
            throw DiscoveryError.schemaMismatch(
                tool: "symskills",
                expected: DiscoveryContract.expectedSchemaVersion,
                actual: actual
            )
        }

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

    private static func locateBinary(_ name: String) -> String {
        BinaryLocator().locate(name)?.url.path ?? "/opt/homebrew/bin/\(name)"
    }
}

// MARK: - symskills JSON types

private struct SymskillsDiscoverResponse: Codable {
    let schemaVersion: Int?
    let candidates: [SymskillsCandidate]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case candidates
    }
}

private struct SymskillsCandidate: Codable {
    let sourceID: String
    let target: String
    let kind: String
    let displayName: String
    let location: String
    let managed: Bool
    let valid: Bool
    let status: String

    enum CodingKeys: String, CodingKey {
        case sourceID = "source_id"
        case target, kind
        case displayName = "display_name"
        case location, managed, valid, status
    }

    func toDiscoveredSource() -> DiscoveredSource {
        // Surface the real managed/valid/status fields instead of the
        // fabricated capability list; `source` is dropped as dead.
        var capabilities = ["import"]
        capabilities.append(managed ? "managed" : "unmanaged")
        if !valid {
            capabilities.append("needs-review")
        }

        return DiscoveredSource(
            sourceID: "symskills:\(sourceID)",
            tool: "symskills",
            kind: kind.replacingOccurrences(of: "_", with: "-"),
            displayName: displayName,
            location: location,
            capabilities: capabilities,
            itemCount: nil,
            // No fabricated "last seen now": the discovery output does not
            // report when a source was last seen.
            lastSeen: nil,
            // No fabricated "none": the discovery output does not report a
            // privacy hint, so "unknown" is the honest label.
            privacyHint: "unknown"
        )
    }
}
