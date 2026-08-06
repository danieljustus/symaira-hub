import SymairaCLIRunner

/// Shared mapping from `CLIRunnerError` to `DiscoveryError` for the source
/// discovery adapters, so error semantics stay identical across tools.
enum DiscoveryAdapterSupport {
    /// Maps a runner error to the corresponding `DiscoveryError`.
    static func mapRunnerError(_ error: CLIRunnerError, tool: String) -> DiscoveryError {
        switch error {
        case .executionFailed(_, let fullStderr):
            return DiscoveryError.invalidResponse(fullStderr)
        case .timeout(let seconds):
            return DiscoveryError.timeout("\(tool) (\(Int(seconds))s)")
        default:
            return DiscoveryError.toolUnavailable(tool)
        }
    }
}
