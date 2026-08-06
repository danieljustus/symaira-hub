import Foundation
import Observation

/// Derives the source inspector's UI decisions from HubState so the view
/// body stays declarative and the decision logic stays unit-testable (#64).
/// The model holds no state of its own — every value is computed live from
/// the wrapped HubState, so it can be recreated cheaply and never goes
/// stale.
@Observable
@MainActor
final class SourceInspectorModel {
    private let state: HubState

    init(state: HubState) {
        self.state = state
    }

    /// All visible candidates (pending and already handled), in scan order.
    var candidates: [SourceCandidate] {
        state.sourceCandidates
    }

    /// Candidates awaiting a decision.
    var pendingCandidates: [SourceCandidate] {
        state.sourceCandidates.filter(\.isPending)
    }

    /// Badge count shown next to the sidebar entry.
    var pendingCount: Int {
        pendingCandidates.count
    }

    /// True when there is nothing to show: no pending candidates and no
    /// scan error. Unavailable-provider hints keep the inspector visible,
    /// so they are excluded from the empty-state decision.
    var isEmpty: Bool {
        pendingCandidates.isEmpty && state.sourceScanError == nil
    }

    /// Total-failure banner message, or nil when the scan is healthy or
    /// only partially failed (the per-provider hint covers that case).
    var errorBannerMessage: String? {
        state.sourceScanError
    }

    /// Per-provider failures from the last scan.
    var unavailableProviders: [DiscoveryError] {
        state.discoveryFailures
    }

    /// Compact hint headline, e.g. "2 source providers unavailable".
    var unavailableProviderSummary: String {
        let count = state.discoveryFailures.count
        return "\(count) source provider\(count == 1 ? "" : "s") unavailable"
    }

    /// Re-run the source scan.
    func refresh() async {
        await state.refreshSources()
    }
}
