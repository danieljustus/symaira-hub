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

        let sources = try await adapter.discover()

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
    }

}
