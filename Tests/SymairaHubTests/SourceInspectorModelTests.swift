import XCTest
@testable import SymairaHub

/// Deterministic adapter for SourceInspectorModel tests: returns a fixed
/// DiscoveryResult instantly.
private actor StubAdapter: SourceDiscoveryAdapter {
    let result: DiscoveryResult

    init(result: DiscoveryResult) {
        self.result = result
    }

    func discover() async throws -> DiscoveryResult { result }
}

/// SourceInspectorModel: the view's decision logic — pending filtering,
/// empty-state flag, banner and unavailable-provider hint state — derived
/// from a live HubState.
@MainActor
final class SourceInspectorModelTests: XCTestCase {
    private func source(_ id: String) -> DiscoveredSource {
        DiscoveredSource(
            sourceID: id,
            tool: "symmemory",
            kind: "session-data",
            displayName: id,
            location: "/tmp/\(id)",
            capabilities: ["import"],
            itemCount: nil,
            lastSeen: nil,
            privacyHint: "unknown"
        )
    }

    /// Create an isolated decision store backed by a fresh UserDefaults suite.
    private func freshStore() -> SourceDecisionStore {
        let defaults = UserDefaults(suiteName: "test.sim.\(UUID().uuidString)")!
        return SourceDecisionStore(defaults: defaults)
    }

    private func makeModel(result: DiscoveryResult) async -> SourceInspectorModel {
        let state = HubState(
            decisionStore: freshStore(),
            discoveryAdapter: StubAdapter(result: result)
        )
        await state.refreshSources()
        return SourceInspectorModel(state: state)
    }

    func testPendingFilteringAndBadgeCount() async {
        let model = await makeModel(result: DiscoveryResult(sources: [source("a:1"), source("b:2")]))

        XCTAssertEqual(model.candidates.count, 2)
        XCTAssertEqual(model.pendingCandidates.count, 2)
        XCTAssertEqual(model.pendingCount, 2)
        XCTAssertFalse(model.isEmpty)
        XCTAssertNil(model.errorBannerMessage)
    }

    func testHandledCandidatesDropOutOfPending() async {
        let state = HubState(
            decisionStore: freshStore(),
            discoveryAdapter: StubAdapter(result: DiscoveryResult(sources: [source("a:1"), source("b:2")]))
        )
        await state.refreshSources()
        let model = SourceInspectorModel(state: state)

        state.approveSource(state.sourceCandidates[0])

        XCTAssertEqual(model.candidates.count, 2)
        XCTAssertEqual(model.pendingCandidates.map(\.id), ["b:2"])
        XCTAssertEqual(model.pendingCount, 1)
    }

    func testEmptyStateFlagWhenNothingPendingAndNoError() async {
        let model = await makeModel(result: DiscoveryResult(sources: []))

        XCTAssertTrue(model.isEmpty)
        XCTAssertEqual(model.pendingCount, 0)
        XCTAssertNil(model.errorBannerMessage)
        XCTAssertTrue(model.unavailableProviders.isEmpty)
    }

    func testTotalFailureSetsBannerAndHint() async {
        let model = await makeModel(result: DiscoveryResult(
            sources: [],
            failures: [.toolUnavailable("symmemory"), .toolUnavailable("symskills")]
        ))

        // Total failure: the banner is set, so the empty state must not
        // swallow the error.
        XCTAssertFalse(model.isEmpty)
        XCTAssertNotNil(model.errorBannerMessage)
        XCTAssertEqual(
            model.unavailableProviders,
            [.toolUnavailable("symmemory"), .toolUnavailable("symskills")]
        )
        XCTAssertEqual(model.unavailableProviderSummary, "2 source providers unavailable")
    }

    func testPartialFailureShowsHintWithoutBanner() async {
        let model = await makeModel(result: DiscoveryResult(
            sources: [source("a:1")],
            failures: [.toolUnavailable("symskills")]
        ))

        XCTAssertFalse(model.isEmpty)
        XCTAssertNil(model.errorBannerMessage)
        XCTAssertEqual(model.unavailableProviders, [.toolUnavailable("symskills")])
        XCTAssertEqual(model.unavailableProviderSummary, "1 source provider unavailable")
    }

    func testHealthyScanClearsBannerAndHint() async {
        let model = await makeModel(result: DiscoveryResult(sources: [source("a:1")]))

        XCTAssertNil(model.errorBannerMessage)
        XCTAssertTrue(model.unavailableProviders.isEmpty)
        XCTAssertEqual(model.unavailableProviderSummary, "0 source providers unavailable")
    }
}
