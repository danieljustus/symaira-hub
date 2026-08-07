import XCTest
@testable import SymairaHub

/// Adapter that returns fixed sources or throws on demand.
private actor StubAdapter: SourceDiscoveryAdapter {
    let sources: [DiscoveredSource]
    private var error: DiscoveryError?

    init(sources: [DiscoveredSource], error: DiscoveryError? = nil) {
        self.sources = sources
        self.error = error
    }

    func discover() async throws -> DiscoveryResult {
        if let error {
            throw error
        }
        return DiscoveryResult(sources: sources)
    }
}

/// CompositeDiscoveryAdapter: dedup across adapters and per-adapter error
/// isolation.
final class CompositeDiscoveryAdapterTests: XCTestCase {
    private func source(_ id: String, tool: String = "symmemory") -> DiscoveredSource {
        DiscoveredSource(
            sourceID: id,
            tool: tool,
            kind: "session-data",
            displayName: id,
            location: "/tmp/\(id)",
            capabilities: ["import"],
            itemCount: nil,
            lastSeen: nil,
            privacyHint: "unknown"
        )
    }

    func testDeduplicatesAcrossAdapters() async throws {
        let adapter = CompositeDiscoveryAdapter(adapters: [
            StubAdapter(sources: [source("a:1"), source("shared:x")]),
            StubAdapter(sources: [source("b:2"), source("shared:x")])
        ])

        let result = try await adapter.discover()

        XCTAssertEqual(result.sources.count, 3)
        XCTAssertEqual(Set(result.sources.map(\.sourceID)), ["a:1", "b:2", "shared:x"])
        XCTAssertTrue(result.failures.isEmpty)
    }

    func testErrorIsolationKeepsOtherAdaptersResults() async throws {
        let adapter = CompositeDiscoveryAdapter(adapters: [
            StubAdapter(sources: [source("a:1")], error: .toolUnavailable("broken")),
            StubAdapter(sources: [source("b:2")])
        ])

        let result = try await adapter.discover()

        XCTAssertEqual(result.sources.map(\.sourceID), ["b:2"])
        XCTAssertEqual(result.failures, [.toolUnavailable("broken")])
    }

    func testMixedFailuresAndSuccessesAreSurfaced() async throws {
        let adapter = CompositeDiscoveryAdapter(adapters: [
            StubAdapter(sources: [source("a:1")], error: .toolUnavailable("symmemory")),
            StubAdapter(sources: [source("b:2")], error: .toolUnavailable("symskills")),
            StubAdapter(sources: [source("c:3")])
        ])

        let result = try await adapter.discover()

        XCTAssertEqual(result.sources.map(\.sourceID), ["c:3"])
        XCTAssertEqual(
            result.failures,
            [.toolUnavailable("symmemory"), .toolUnavailable("symskills")]
        )
    }

    func testAllAdaptersEmptyReturnsEmpty() async throws {
        let adapter = CompositeDiscoveryAdapter(adapters: [
            StubAdapter(sources: []),
            StubAdapter(sources: [])
        ])

        let result = try await adapter.discover()

        XCTAssertTrue(result.sources.isEmpty)
        XCTAssertTrue(result.failures.isEmpty)
    }

    func testEmptyAdapterListReturnsEmpty() async throws {
        let adapter = CompositeDiscoveryAdapter(adapters: [])

        let result = try await adapter.discover()

        XCTAssertTrue(result.sources.isEmpty)
        XCTAssertTrue(result.failures.isEmpty)
    }
}
