import Foundation

/// Persists source-level decisions (Add/Ignore/Snooze) so repeated scans
/// are idempotent and ignored sources do not reappear.
@Observable
@MainActor
final class SourceDecisionStore {
    /// How long to wait after the last mutation before persisting, so bursts
    /// of approve/ignore click-throughs coalesce into a single write.
    private static let saveDebounce: Duration = .milliseconds(300)

    private let defaults: UserDefaults
    private let key = "symaira.hub.sourceDecisions"

    private var storage: [String: SourceDecision] = [:]

    /// The deferred save scheduled by the most recent mutation, if any.
    private var saveTask: Task<Void, Never>?
    /// Whether the in-memory state differs from what is currently persisted.
    private var isDirty = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    /// Current decision for a source ID, or `.pending` if unknown.
    func decision(for sourceID: String) -> SourceDecision {
        storage[sourceID] ?? .pending
    }

    /// Record a decision. `.pending` removes any stored decision.
    func setDecision(_ decision: SourceDecision, for sourceID: String) {
        if decision == .pending {
            storage.removeValue(forKey: sourceID)
        } else {
            storage[sourceID] = decision
        }
        scheduleSave()
    }

    /// All source IDs currently marked as ignored.
    var ignoredSourceIDs: Set<String> {
        Set(storage.filter { $0.value == .ignored }.keys)
    }

    /// All source IDs currently marked as snoozed.
    var snoozedSourceIDs: Set<String> {
        Set(storage.filter { $0.value == .snoozed }.keys)
    }

    /// Expire every snoozed decision back to `.pending`. Snooze is
    /// temporary ("hide it for now, but let it reappear on next scan"),
    /// so this runs at the start of each scan.
    func expireSnoozed() {
        let hadSnoozed = storage.values.contains(.snoozed)
        storage = storage.filter { $0.value != .snoozed }
        if hadSnoozed {
            scheduleSave()
        }
    }

    /// Reset all ignored sources back to pending.
    func resetIgnored() {
        storage = storage.filter { $0.value != .ignored }
        scheduleSave()
    }

    /// Reset a single source back to pending.
    func resetDecision(for sourceID: String) {
        setDecision(.pending, for: sourceID)
    }

    // MARK: - Persistence

    private func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: SourceDecision].self, from: data)
        else { return }
        storage = decoded
    }

    /// Persist any pending changes immediately, cancelling the deferred save.
    func flush() {
        saveTask?.cancel()
        saveTask = nil
        persistIfDirty()
    }

    /// Mark the store dirty and (re)schedule the deferred save. Cancelling
    /// the previous task guarantees writes stay ordered: only the task
    /// scheduled by the newest mutation may persist, and it always writes
    /// the latest state, so a burst of mutations produces one trailing write.
    private func scheduleSave() {
        isDirty = true
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: Self.saveDebounce)
            guard !Task.isCancelled else { return }
            persistIfDirty()
        }
    }

    private func persistIfDirty() {
        guard isDirty else { return }
        guard let data = try? JSONEncoder().encode(storage) else { return }
        defaults.set(data, forKey: key)
        isDirty = false
    }
}
