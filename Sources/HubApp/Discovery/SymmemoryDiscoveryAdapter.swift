import Foundation
import SymairaCLIRunner
import SymairaToolKit

/// Adapter that calls `symmemory discover sources` and maps the output
/// to the Source Discovery Contract v1 format.
actor SymmemoryDiscoveryAdapter: SourceDiscoveryAdapter {
    private let binaryPath: String
    private let runner: CLIRunner

    /// Resolve the binary through appkit's `BinaryLocator` (bundle → PATH →
    /// Homebrew), keeping the legacy Homebrew path as a last-resort fallback
    /// so Intel/arm machines and non-Homebrew installs are not misreported
    /// as unavailable. `binaryPath` stays injectable for stub-binary tests.
    init(binaryPath: String? = nil, runner: CLIRunner = CLIRunner()) {
        self.binaryPath = binaryPath ?? Self.locateBinary("symmemory")
        self.runner = runner
    }

    func discover() async throws -> DiscoveryResult {
        let data = try await runSymmemoryDiscover()
        let response = try JSONDecoder().decode(DiscoveryResponse.self, from: data)
        guard response.schemaVersion == DiscoveryContract.expectedSchemaVersion else {
            throw DiscoveryError.schemaMismatch(
                tool: "symmemory",
                expected: DiscoveryContract.expectedSchemaVersion,
                actual: response.schemaVersion
            )
        }
        return DiscoveryResult(sources: response.sources)
    }

    /// Run `symmemory discover sources` and return stdout data.
    /// Uses the shared `CLIRunner`, which terminates the subprocess on task
    /// cancellation, so a hung binary cannot leak across refreshes.
    private func runSymmemoryDiscover() async throws -> Data {
        do {
            return try await runner.runChecked(
                URL(fileURLWithPath: binaryPath),
                arguments: ["discover", "sources"]
            )
        } catch let error as CLIRunnerError {
            switch error {
            case .executionFailed(_, let stderr):
                throw DiscoveryError.invalidResponse(stderr)
            case .timeout(let seconds):
                throw DiscoveryError.timeout("symmemory (\(Int(seconds))s)")
            default:
                throw DiscoveryError.toolUnavailable("symmemory")
            }
        } catch {
            // Binary missing or not executable.
            throw DiscoveryError.toolUnavailable("symmemory")
        }
    }

    private static func locateBinary(_ name: String) -> String {
        BinaryLocator().locate(name)?.url.path ?? "/opt/homebrew/bin/\(name)"
    }
}
