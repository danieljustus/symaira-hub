import XCTest
@testable import SymairaHub

/// SourceDecisionStore persistence and decision-semantics tests, isolated
/// from the real UserDefaults via a dedicated suite per test.
final class SourceDecisionStoreTests: XCTestCase {
    /// Create an isolated store backed by a fresh UserDefaults suite.
    @MainActor
    private func freshStore() -> (UserDefaults, SourceDecisionStore) {
        let defaults = UserDefaults(suiteName: "test.sourceDecisions.\(UUID().uuidString)")!
        return (defaults, SourceDecisionStore(defaults: defaults))
    }

    @MainActor
    func testUnknownDecisionIsPending() {
        let (_, store) = freshStore()
        XCTAssertEqual(store.decision(for: "unknown:id"), .pending)
    }

    @MainActor
    func testSetGetRoundTrip() {
        let (_, store) = freshStore()
        store.setDecision(.approved, for: "a:1")
        XCTAssertEqual(store.decision(for: "a:1"), .approved)

        store.setDecision(.ignored, for: "a:1")
        XCTAssertEqual(store.decision(for: "a:1"), .ignored)
    }

    @MainActor
    func testPendingRemovesStoredDecision() {
        let (_, store) = freshStore()
        store.setDecision(.ignored, for: "a:1")
        store.setDecision(.pending, for: "a:1")
        XCTAssertEqual(store.decision(for: "a:1"), .pending)
        XCTAssertTrue(store.ignoredSourceIDs.isEmpty)
    }

    @MainActor
    func testPersistenceAcrossInstances() {
        let (defaults, store) = freshStore()
        store.setDecision(.ignored, for: "persist:1")
        store.flush()

        let reloaded = SourceDecisionStore(defaults: defaults)
        XCTAssertEqual(reloaded.decision(for: "persist:1"), .ignored)
    }

    @MainActor
    func testResetIgnoredOnlyClearsIgnored() {
        let (_, store) = freshStore()
        store.setDecision(.ignored, for: "i:1")
        store.setDecision(.approved, for: "a:1")
        store.setDecision(.snoozed, for: "s:1")

        store.resetIgnored()

        XCTAssertTrue(store.ignoredSourceIDs.isEmpty)
        XCTAssertEqual(store.decision(for: "a:1"), .approved)
        XCTAssertEqual(store.decision(for: "s:1"), .snoozed)
    }

    @MainActor
    func testResetSingleDecision() {
        let (_, store) = freshStore()
        store.setDecision(.ignored, for: "i:1")
        store.resetDecision(for: "i:1")
        XCTAssertEqual(store.decision(for: "i:1"), .pending)
    }

    @MainActor
    func testExpireSnoozedReturnsToPending() {
        let (_, store) = freshStore()
        store.setDecision(.snoozed, for: "s:1")
        store.setDecision(.approved, for: "a:1")

        store.expireSnoozed()

        XCTAssertEqual(store.decision(for: "s:1"), .pending)
        XCTAssertTrue(store.snoozedSourceIDs.isEmpty)
        XCTAssertEqual(store.decision(for: "a:1"), .approved)
    }

    @MainActor
    func testExpireSnoozedWithoutSnoozedEntriesDoesNotRewrite() {
        let (_, store) = freshStore()
        store.setDecision(.approved, for: "a:1")
        store.expireSnoozed()
        XCTAssertEqual(store.decision(for: "a:1"), .approved)
    }

    @MainActor
    func testMutationBurstCoalescesIntoOneDeferredSave() async throws {
        let (defaults, store) = freshStore()

        // A rapid click-through burst with no awaits between mutations, so
        // the deferred save cannot fire mid-burst.
        for index in 0..<20 {
            store.setDecision(.approved, for: "burst:\(index)")
        }
        // The final decision for one source flips twice: the last wins.
        store.setDecision(.ignored, for: "burst:19")
        store.setDecision(.approved, for: "burst:19")

        // While the deferred save is still pending, nothing has been written
        // (the burst ran synchronously, so no intermediate save fired).
        XCTAssertNil(defaults.data(forKey: "symaira.hub.sourceDecisions"))

        // Let the trailing save fire, then prove the latest state persisted.
        try await Task.sleep(for: .milliseconds(800))

        let reloaded = SourceDecisionStore(defaults: defaults)
        for index in 0..<20 {
            XCTAssertEqual(reloaded.decision(for: "burst:\(index)"), .approved)
        }
    }
}
