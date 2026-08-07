import os
import SymairaCLIRunner

/// Shared mapping from `CLIRunnerError` to `DiscoveryError` for the source
/// discovery adapters, so error semantics stay identical across tools.
enum DiscoveryAdapterSupport {
    /// Debug logger for full-fidelity diagnostics. The raw stderr is only
    /// ever emitted here, never into the surfaced `DiscoveryError`.
    private static let logger = Logger(subsystem: "dev.symaira.SymairaHub", category: "discovery")

    /// Maps a runner error to the corresponding `DiscoveryError`.
    ///
    /// `executionFailed` stderr is redacted and length-bounded before it
    /// reaches the UI (`DiscoveryError.invalidResponse` is rendered verbatim
    /// by the source inspector); the full raw stderr stays available on the
    /// `CLIRunnerError` itself and is logged at debug level for diagnostics.
    static func mapRunnerError(_ error: CLIRunnerError, tool: String) -> DiscoveryError {
        switch error {
        case .executionFailed(let code, let fullStderr):
            logger.debug("\(tool, privacy: .public) failed (exit \(code)): \(fullStderr, privacy: .private)")
            return DiscoveryError.invalidResponse(
                CLIRunnerError.redactedForUser(fullStderr, maxBytes: 200)
            )
        case .timeout(let seconds):
            return DiscoveryError.timeout("\(tool) (\(Int(seconds))s)")
        default:
            return DiscoveryError.toolUnavailable(tool)
        }
    }
}
