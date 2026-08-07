import XCTest
@testable import SymairaHub

/// Deterministic TTL + detection-seam tests for `HubState.refresh()`.
///
/// Never touches the real `ToolDetector` (subprocess spawning is
/// environment-dependent and flaky in CI): the injected `detect:` closure
/// replaces it. `DetectedTool` has no public initializer in the pinned
/// SymairaToolKit, so the closure returns nil and the row-list assertions
/// cover the all-available case. `state.rows.count` after a refresh equals
/// the registry size (every registry tool yields exactly one row), which
/// serves as the deterministic detection-count oracle without importing
/// SymairaToolKit into the test bundle.
final class HubStateRefreshTests: XCTestCase {
    /// Mutable counter shared with the `@Sendable` detection closure.
    private actor DetectionCounter {
        private(set) var count = 0

        func bump() {
            count += 1
        }
    }

    /// Create an isolated decision store backed by a fresh UserDefaults suite.
    @MainActor
    private func freshStore() -> SourceDecisionStore {
        let defaults = UserDefaults(suiteName: "test.hubstate.refresh.\\(UUID().uuidString)")!
        return SourceDecisionStore(defaults: defaults)
    }

    // MARK: - shouldRefresh

    func testShouldRefreshNilLastRefreshAlwaysRefreshes() {
        XCTAssertTrue(HubState.shouldRefresh(lastRefresh: nil, ttl: 5, force: false))
    }

    func testShouldRefreshFreshLastRefreshSkips() {
        let now = Date()
        XCTAssertFalse(HubState.shouldRefresh(
            lastRefresh: now.addingTimeInterval(-1),
            now: now,
            ttl: 5,
            force: false
        ))
    }

    func testShouldRefreshStaleLastRefreshRefreshes() {
        let now = Date()
        XCTAssertTrue(HubState.shouldRefresh(
            lastRefresh: now.addingTimeInterval(-10),
            now: now,
            ttl: 5,
            force: false
        ))
    }

    func testShouldRefreshForceBypassesTTL() {
        let now = Date()
        XCTAssertTrue(HubState.shouldRefresh(
            lastRefresh: now.addingTimeInterval(-1),
            now: now,
            ttl: 5,
            force: true
        ))
    }

    // MARK: - refresh TTL

    @MainActor
    func testRefreshSkipsDetectionWithinTTLAndForceRescans() async {
        let counter = DetectionCounter()
        let state = HubState(
            decisionStore: freshStore(),
            discoveryAdapter: FixedDiscoveryAdapter(sources: []),
            // Long TTL: the whole test runs inside the skip window, so the
            // second refresh() is guaranteed to be skipped.
            refreshTTL: 3_600,
            detect: { _ in
                await counter.bump()
                return nil
            }
        )

        // First refresh: every registry tool is detected once.
        await state.refresh()
        let registrySize = state.rows.count
        var count = await counter.count
        XCTAssertEqual(count, registrySize)
        XCTAssertEqual(state.availableRows.count, registrySize)
        XCTAssertTrue(state.installedRows.isEmpty)

        // Immediate second refresh: within the TTL, so nothing re-detects.
        await state.refresh()
        count = await counter.count
        XCTAssertEqual(count, registrySize)

        // Forced refresh: bypasses the TTL and re-detects every tool.
        await state.refresh(force: true)
        count = await counter.count
        XCTAssertEqual(count, registrySize * 2)
        XCTAssertEqual(state.availableRows.count, registrySize)
        XCTAssertTrue(state.installedRows.isEmpty)
    }
}
