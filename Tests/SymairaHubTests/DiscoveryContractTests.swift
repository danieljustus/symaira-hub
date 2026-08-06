import XCTest
@testable import SymairaHub

final class DiscoveryContractTests: XCTestCase {
    private func source(
        id: String = "source:1",
        capabilities: [String] = ["import", "preview"]
    ) -> DiscoveredSource {
        DiscoveredSource(
            sourceID: id,
            tool: "test-tool",
            kind: "test-source",
            displayName: "Test Source",
            location: "/tmp/test-source",
            capabilities: capabilities,
            itemCount: 3,
            lastSeen: nil,
            privacyHint: "unknown"
        )
    }

    func testSourceIdentityAndCapabilitySummary() {
        let source = source()

        XCTAssertEqual(source.id, "source:1")
        XCTAssertEqual(source.capabilitySummary, "import, preview")
    }

    func testDiscoveryErrorsProvideActionableDescriptions() {
        let cases: [(DiscoveryError, String)] = [
            (.toolUnavailable("symmemory"), "symmemory is not available"),
            (.timeout("symskills (10s)"), "symskills (10s) did not respond in time"),
            (.invalidResponse("bad JSON"), "Invalid discovery response: bad JSON"),
            (
                .schemaMismatch(tool: "symskills", expected: 1, actual: 2),
                "symskills uses schema v2, Hub expects v1"
            )
        ]

        for (error, expected) in cases {
            XCTAssertEqual(error.errorDescription, expected)
        }
    }

    func testMockDiscoveryReturnsStableSampleMetadata() async throws {
        let adapter = MockDiscoveryAdapter(minDelay: 0, maxDelay: 0)

        let result = try await adapter.discover()
        let sources = result.sources

        XCTAssertEqual(sources.count, 4)
        XCTAssertEqual(
            sources.map(\.sourceID),
            [
                "mock:claude-code-sessions",
                "mock:hermes-agent-sessions",
                "mock:unmanaged-skills",
                "mock:profile-links-review"
            ]
        )
        XCTAssertEqual(sources.map(\.tool), ["symmemory", "symmemory", "symskills", "symskills"])
        XCTAssertTrue(sources.allSatisfy { $0.capabilities == ["import"] })
        XCTAssertTrue(result.failures.isEmpty)
    }

    func testMockThrowsToolUnavailableWhenSimulatingError() async {
        let adapter = MockDiscoveryAdapter(minDelay: 0, maxDelay: 0)
        await adapter.setSimulateError(true)

        do {
            _ = try await adapter.discover()
            XCTFail("expected toolUnavailable")
        } catch let error as DiscoveryError {
            guard case .toolUnavailable(let tool) = error else {
                return XCTFail("unexpected error: \(error)")
            }
            XCTAssertEqual(tool, "symmemory")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testDiscoveryResultAggregatesSourcesAndFailures() {
        let result = DiscoveryResult(
            sources: [source()],
            failures: [.toolUnavailable("symskills"), .timeout("symmemory")]
        )

        XCTAssertEqual(result.sources.count, 1)
        XCTAssertEqual(result.failures.count, 2)
        XCTAssertEqual(
            result,
            DiscoveryResult(
                sources: [source()],
                failures: [.toolUnavailable("symskills"), .timeout("symmemory")]
            )
        )
    }

    func testDiscoveryResultDefaultsToNoFailures() {
        let result = DiscoveryResult(sources: [source()])

        XCTAssertTrue(result.failures.isEmpty)
    }
}
