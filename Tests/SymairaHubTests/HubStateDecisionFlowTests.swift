import XCTest
@testable import SymairaHub

/// Deterministic discovery adapter for HubState flow tests: returns a fixed
/// set of sources (plus optional failures) instantly, or throws when asked.
actor FixedDiscoveryAdapter: SourceDiscoveryAdapter {
    let sources: [DiscoveredSource]
    private var failures: [DiscoveryError]
    private var shouldThrow = false

    init(sources: [DiscoveredSource], failures: [DiscoveryError] = []) {
        self.sources = sources
        self.failures = failures
    }

    /// Make the next discover() call throw.
    func failNext() {
        shouldThrow = true
    }

    func discover() async throws -> DiscoveryResult {
        if shouldThrow {
            throw DiscoveryError.toolUnavailable("test")
        }
        return DiscoveryResult(sources: sources, failures: failures)
    }
}

/// HubState decision-flow tests: approve/ignore/snooze/reset must update
/// the candidate list and the pending count.
final class HubStateDecisionFlowTests: XCTestCase {
    private let sampleSources: [DiscoveredSource] = [
        DiscoveredSource(
            sourceID: "t:one",
            tool: "symmemory",
            kind: "session-data",
            displayName: "One",
            location: "/tmp/one",
            capabilities: ["import"],
            itemCount: 1,
            lastSeen: "2026-08-01T00:00:00Z",
            privacyHint: "unknown"
        ),
        DiscoveredSource(
            sourceID: "t:two",
            tool: "symskills",
            kind: "skill-bundle",
            displayName: "Two",
            location: "/tmp/two",
            capabilities: ["import"],
            itemCount: 2,
            lastSeen: nil,
            privacyHint: "unknown"
        )
    ]

    /// Create an isolated decision store backed by a fresh UserDefaults suite.
    @MainActor
    private func freshStore() -> SourceDecisionStore {
        let defaults = UserDefaults(suiteName: "test.hubstate.\(UUID().uuidString)")!
        return SourceDecisionStore(defaults: defaults)
    }

    @MainActor
    private func makeState(adapter: FixedDiscoveryAdapter) async -> HubState {
        let state = HubState(
            decisionStore: freshStore(),
            discoveryAdapter: adapter
        )
        await state.refreshSources()
        return state
    }

    @MainActor
    func testInitialCandidatesAreAllPending() async {
        let state = await makeState(adapter: FixedDiscoveryAdapter(sources: sampleSources))
        XCTAssertEqual(state.sourceCandidates.count, 2)
        XCTAssertEqual(state.sourceCandidates.first?.id, "t:one")
        XCTAssertEqual(state.pendingSourceCount, 2)
        XCTAssertEqual(state.sourceScanError, nil)
    }

    @MainActor
    func testApproveRemovesPendingAndKeepsCandidate() async throws {
        let state = await makeState(adapter: FixedDiscoveryAdapter(sources: sampleSources))
        let first = try XCTUnwrap(state.sourceCandidates.first)

        state.approveSource(first)

        XCTAssertEqual(state.decisionStore.decision(for: first.source.id), .approved)
        XCTAssertEqual(state.pendingSourceCount, 1)
        XCTAssertTrue(state.sourceCandidates.contains { $0.source.id == first.source.id })
    }

    @MainActor
    func testIgnoreHidesCandidate() async throws {
        let state = await makeState(adapter: FixedDiscoveryAdapter(sources: sampleSources))
        let first = try XCTUnwrap(state.sourceCandidates.first)

        state.ignoreSource(first)

        XCTAssertEqual(state.decisionStore.decision(for: first.source.id), .ignored)
        XCTAssertEqual(state.pendingSourceCount, 1)
        XCTAssertFalse(state.sourceCandidates.contains { $0.source.id == first.source.id })
    }

    @MainActor
    func testSnoozeHidesCandidateImmediately() async throws {
        let state = await makeState(adapter: FixedDiscoveryAdapter(sources: sampleSources))
        let first = try XCTUnwrap(state.sourceCandidates.first)

        state.snoozeSource(first)

        XCTAssertEqual(state.decisionStore.decision(for: first.source.id), .snoozed)
        XCTAssertEqual(state.pendingSourceCount, 1)
        XCTAssertFalse(state.sourceCandidates.contains { $0.source.id == first.source.id })
    }

    @MainActor
    func testSnoozedCandidateReappearsOnNextScan() async throws {
        let state = await makeState(adapter: FixedDiscoveryAdapter(sources: sampleSources))
        let first = try XCTUnwrap(state.sourceCandidates.first)
        state.snoozeSource(first)
        XCTAssertEqual(state.pendingSourceCount, 1)

        await state.refreshSources()

        XCTAssertEqual(state.decisionStore.decision(for: first.source.id), .pending)
        XCTAssertEqual(state.pendingSourceCount, 2)
        XCTAssertTrue(state.sourceCandidates.contains { $0.source.id == first.source.id })
    }

    @MainActor
    func testResetIgnoredRestoresCandidates() async {
        let state = await makeState(adapter: FixedDiscoveryAdapter(sources: sampleSources))
        for candidate in state.sourceCandidates {
            state.ignoreSource(candidate)
        }
        XCTAssertEqual(state.pendingSourceCount, 0)
        XCTAssertTrue(state.sourceCandidates.isEmpty)

        state.resetIgnoredSources()

        XCTAssertEqual(state.pendingSourceCount, 2)
        XCTAssertEqual(state.sourceCandidates.count, 2)
    }

    @MainActor
    func testResetSingleDecisionRestoresCandidate() async throws {
        let state = await makeState(adapter: FixedDiscoveryAdapter(sources: sampleSources))
        let first = try XCTUnwrap(state.sourceCandidates.first)
        state.ignoreSource(first)
        XCTAssertFalse(state.sourceCandidates.contains { $0.source.id == first.source.id })

        state.resetDecision(for: first.source.id)

        XCTAssertEqual(state.decisionStore.decision(for: first.source.id), .pending)
        XCTAssertTrue(state.sourceCandidates.contains { $0.source.id == first.source.id })
    }

    @MainActor
    func testScanErrorSurfacesWithoutCandidates() async {
        let adapter = FixedDiscoveryAdapter(sources: sampleSources)
        await adapter.failNext()
        let state = HubState(
            decisionStore: freshStore(),
            discoveryAdapter: adapter
        )

        await state.refreshSources()

        XCTAssertNotNil(state.sourceScanError)
        XCTAssertTrue(state.sourceCandidates.isEmpty)
        XCTAssertEqual(state.pendingSourceCount, 0)
        XCTAssertEqual(state.discoveryFailures, [.toolUnavailable("test")])
        XCTAssertEqual(state.unavailableProviderCount, 1)
    }

    @MainActor
    func testPartialFailureKeepsCandidatesWithoutBanner() async {
        let state = await makeState(adapter: FixedDiscoveryAdapter(
            sources: sampleSources,
            failures: [.toolUnavailable("symskills")]
        ))

        XCTAssertEqual(state.sourceCandidates.count, 2)
        XCTAssertNil(state.sourceScanError)
        XCTAssertEqual(state.discoveryFailures, [.toolUnavailable("symskills")])
        XCTAssertEqual(state.unavailableProviderCount, 1)
    }

    @MainActor
    func testAllProvidersDownSetsCombinedScanError() async {
        let state = await makeState(adapter: FixedDiscoveryAdapter(
            sources: [],
            failures: [.toolUnavailable("symmemory"), .toolUnavailable("symskills")]
        ))

        XCTAssertTrue(state.sourceCandidates.isEmpty)
        XCTAssertEqual(
            state.sourceScanError,
            "symmemory is not available (2 providers unavailable)"
        )
        XCTAssertEqual(state.discoveryFailures.count, 2)
        XCTAssertEqual(state.unavailableProviderCount, 2)
    }
}
