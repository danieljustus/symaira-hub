import Foundation
import SymairaCLIRunner

/// Adapter that calls `symmemory discover sources` and maps the output
/// to the Source Discovery Contract v1 format.
actor SymmemoryDiscoveryAdapter: SourceDiscoveryAdapter {
    private let binaryPath: String
    private let runner: CLIRunner

    init(binaryPath: String = "/opt/homebrew/bin/symmemory", runner: CLIRunner = CLIRunner()) {
        self.binaryPath = binaryPath
        self.runner = runner
    }

    func discover() async throws -> [DiscoveredSource] {
        let data = try await runSymmemoryDiscover()
        let response = try JSONDecoder().decode(DiscoveryResponse.self, from: data)
        guard response.schemaVersion == DiscoveryContract.expectedSchemaVersion else {
            throw DiscoveryError.schemaMismatch(
                tool: "symmemory",
                expected: DiscoveryContract.expectedSchemaVersion,
                actual: response.schemaVersion
            )
        }
        return response.sources
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
}
