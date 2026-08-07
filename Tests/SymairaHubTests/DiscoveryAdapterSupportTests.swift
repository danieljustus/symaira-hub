import XCTest
import SymairaCLIRunner
@testable import SymairaHub

/// Unit tests for the shared `DiscoveryAdapterSupport` error mapping used by
/// the symmemory/symskills discovery adapters (#60, #63).
final class DiscoveryAdapterSupportTests: XCTestCase {
    /// A long opaque token that `CLIRunnerError.redactedForUser` must scrub.
    private let secret = String(repeating: "a", count: 64)

    func testExecutionFailedMapsToRedactedInvalidResponse() {
        let stderr = "error: failed to open vault at /Users/daniel/Vaults/\(secret)/sources.json\n"
            + "api_key=\(secret)\nstack trace at line 42"

        let error = DiscoveryAdapterSupport.mapRunnerError(
            .executionFailed(code: 1, fullStderr: stderr),
            tool: "symmemory"
        )

        guard case .invalidResponse(let detail) = error else {
            return XCTFail("expected invalidResponse, got \(error)")
        }
        // The secret is scrubbed from the payload and the errorDescription
        // that HubState renders verbatim in the source inspector. The
        // opaque span (path + token) collapses to the [REDACTED] marker.
        XCTAssertFalse(detail.contains(secret))
        XCTAssertFalse(detail.contains("api_key="))
        XCTAssertTrue(detail.hasPrefix("error: failed to open vault at "))
        XCTAssertTrue(detail.contains("[REDACTED]"))
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.contains(secret))
        XCTAssertTrue(error.errorDescription!.contains("[REDACTED]"))
    }

    func testExecutionFailedStderrIsRedactedAndLengthBounded() {
        // Dashes are not a secret shape, so they survive redaction and
        // exercise the byte-bounded truncation (200 bytes + ellipsis).
        let longLine = String(repeating: "-", count: 500)
        let stderr = longLine + "\n" + String(repeating: "y", count: 300)

        let error = DiscoveryAdapterSupport.mapRunnerError(
            .executionFailed(code: 7, fullStderr: stderr),
            tool: "symskills"
        )

        guard case .invalidResponse(let detail) = error else {
            return XCTFail("expected invalidResponse, got \(error)")
        }
        XCTAssertEqual(detail, String(repeating: "-", count: 200) + "…")
        XCTAssertLessThanOrEqual(detail.utf8.count, 203)
        XCTAssertFalse(detail.contains(String(repeating: "y", count: 300)))
    }

    func testTimeoutMapsToTimeout() {
        let error = DiscoveryAdapterSupport.mapRunnerError(
            .timeout(seconds: 2.5),
            tool: "symmemory"
        )

        guard case .timeout(let message) = error else {
            return XCTFail("expected timeout, got \(error)")
        }
        XCTAssertEqual(message, "symmemory (2s)")
    }

    func testOtherRunnerErrorsMapToToolUnavailable() {
        let runnerErrors: [CLIRunnerError] = [
            .binaryNotFound(tool: "symmemory"),
            .invalidJSON(description: "not json"),
            .schemaMismatch(expected: 1, actual: 2),
            .outputTruncated(size: 1024)
        ]

        for runnerError in runnerErrors {
            let error = DiscoveryAdapterSupport.mapRunnerError(runnerError, tool: "symskills")
            guard case .toolUnavailable(let tool) = error else {
                return XCTFail("expected toolUnavailable for \(runnerError), got \(error)")
            }
            XCTAssertEqual(tool, "symskills")
        }
    }

    func testRawStderrStaysAvailableOnRunnerErrorForLogging() {
        let stderr = "api_token=\(secret)\nfailed"
        let runnerError = CLIRunnerError.executionFailed(code: 1, fullStderr: stderr)

        let mapped = DiscoveryAdapterSupport.mapRunnerError(runnerError, tool: "symmemory")

        guard case .invalidResponse(let detail) = mapped else {
            return XCTFail("expected invalidResponse, got \(mapped)")
        }
        // The CLIRunnerError retains full fidelity for the logging path...
        XCTAssertEqual(runnerError.fullStderr, stderr)
        // ...while the surfaced error only carries the redacted form.
        XCTAssertFalse(detail.contains(secret))
    }
}
