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

    func discover() async throws -> [DiscoveredSource] {
        if let error {
            throw error
        }
        return sources
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

        let sources = try await adapter.discover()

        XCTAssertEqual(sources.count, 3)
        XCTAssertEqual(Set(sources.map(\.sourceID)), ["a:1", "b:2", "shared:x"])
    }

    func testErrorIsolationKeepsOtherAdaptersResults() async throws {
        let adapter = CompositeDiscoveryAdapter(adapters: [
            StubAdapter(sources: [source("a:1")], error: .toolUnavailable("broken")),
            StubAdapter(sources: [source("b:2")])
        ])

        let sources = try await adapter.discover()

        XCTAssertEqual(sources.map(\.sourceID), ["b:2"])
    }

    func testAllAdaptersEmptyReturnsEmpty() async throws {
        let adapter = CompositeDiscoveryAdapter(adapters: [
            StubAdapter(sources: []),
            StubAdapter(sources: [])
        ])

        let sources = try await adapter.discover()

        XCTAssertTrue(sources.isEmpty)
    }

    func testEmptyAdapterListReturnsEmpty() async throws {
        let adapter = CompositeDiscoveryAdapter(adapters: [])

        let sources = try await adapter.discover()

        XCTAssertTrue(sources.isEmpty)
    }
}
