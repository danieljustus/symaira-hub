import Foundation
import Observation
import SymairaToolKit

/// One sidebar entry: a registry tool plus its (optional) detection result.
struct ToolRow: Identifiable {
    let tool: SymairaTool
    let detected: DetectedTool?

    var id: String { tool.id }
    var isInstalled: Bool { detected != nil }
}

/// A source candidate paired with its persisted decision.
struct SourceCandidate: Identifiable {
    let source: DiscoveredSource
    let decision: SourceDecision

    var id: String { source.id }
    var isPending: Bool { decision == .pending }
}

@Observable
@MainActor
final class HubState {
    private(set) var rows: [ToolRow] = []
    private(set) var isRefreshing = false
    private(set) var lastRefresh: Date?

    var selectedToolID: String?

    private let detector: ToolDetector

    // Source inspector state
    private(set) var sourceCandidates: [SourceCandidate] = []
    private(set) var sourceScanError: String?
    let decisionStore: SourceDecisionStore

    /// Real CLI adapters. Missing tools are handled as empty discovery results
    /// by the composite, so installation remains optional.
    private let discoveryAdapter: SourceDiscoveryAdapter

    init(
        decisionStore: SourceDecisionStore = SourceDecisionStore(),
        discoveryAdapter: SourceDiscoveryAdapter = CompositeDiscoveryAdapter(
            adapters: [
                SymmemoryDiscoveryAdapter(),
                SymskillsDiscoveryAdapter()
            ]
        ),
        detector: ToolDetector = ToolDetector()
    ) {
        self.decisionStore = decisionStore
        self.discoveryAdapter = discoveryAdapter
        self.detector = detector
    }

    var selectedRow: ToolRow? {
        rows.first { $0.id == selectedToolID }
    }

    var installedCount: Int {
        rows.filter(\.isInstalled).count
    }

    /// Sources that have not been Add-ed, Ignore-ed, or Snooze-d.
    var pendingSourceCount: Int {
        sourceCandidates.filter(\.isPending).count
    }

    /// Re-run runtime detection over the whole registry. Modules only
    /// "light up" for installed CLIs — the hub never requires them.
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        // Tool detection (existing)
        var newRows: [ToolRow] = []
        for tool in SymairaToolRegistry.all {
            let detected = await detector.detect(tool)
            newRows.append(ToolRow(tool: tool, detected: detected))
        }
        rows = newRows.sorted {
            if $0.isInstalled != $1.isInstalled { return $0.isInstalled }
            return $0.tool.displayName < $1.tool.displayName
        }
        lastRefresh = Date()

        if selectedToolID == nil {
            selectedToolID = rows.first?.id
        }

        // Source discovery (new)
        await refreshSources()
    }

    /// Scan for pending sources. Runs as part of refresh() — never blocks
    /// tool detection or Hub startup on a slow/failing adapter.
    func refreshSources() async {
        sourceScanError = nil

        // Snooze is temporary: a snoozed source hides for this session and
        // reappears as pending on the next scan.
        decisionStore.expireSnoozed()

        do {
            rawSources = try await withTimeout(seconds: 10) {
                try await self.discoveryAdapter.discover()
            }
        } catch {
            sourceScanError = error.localizedDescription
            rawSources = []
        }

        applyDecisions()
    }

    /// Approve a source: mark it as approved for import.
    func approveSource(_ candidate: SourceCandidate) {
        decisionStore.setDecision(.approved, for: candidate.source.id)
        applyDecisions()
    }

    /// Ignore a source: suppress it on all future scans.
    func ignoreSource(_ candidate: SourceCandidate) {
        decisionStore.setDecision(.ignored, for: candidate.source.id)
        applyDecisions()
    }

    /// Snooze a source: hide it for now, but let it reappear on next scan.
    func snoozeSource(_ candidate: SourceCandidate) {
        decisionStore.setDecision(.snoozed, for: candidate.source.id)
        applyDecisions()
    }

    /// Reset all ignored sources back to pending.
    func resetIgnoredSources() {
        decisionStore.resetIgnored()
        // Rebuild candidates from the raw scan result — previously ignored
        // sources show up again immediately, no re-scan required.
        applyDecisions()
    }

    /// Reset a single decision back to pending.
    func resetDecision(for sourceID: String) {
        decisionStore.resetDecision(for: sourceID)
        applyDecisions()
    }

    // MARK: - Private

    /// Last raw discovery result. Kept so decision changes (reset, reset
    /// all) can rebuild the visible candidates without another scan.
    private var rawSources: [DiscoveredSource] = []

    /// Derive the visible candidates from the raw scan result and the
    /// persisted decisions.
    private func applyDecisions() {
        let ignoredIDs = decisionStore.ignoredSourceIDs
        let snoozedIDs = decisionStore.snoozedSourceIDs
        sourceCandidates = rawSources
            .map { SourceCandidate(source: $0, decision: decisionStore.decision(for: $0.sourceID)) }
            .filter { !ignoredIDs.contains($0.source.id) && !snoozedIDs.contains($0.source.id) }
    }
}

/// Run an async operation with a timeout. Throws DiscoveryError.timeout
/// if the operation does not complete within `seconds`.
private func withTimeout<T: Sendable>(
    seconds: Double,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw DiscoveryError.timeout("discovery")
        }
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}
