import Foundation

/// Persists source-level decisions (Add/Ignore/Snooze) so repeated scans
/// are idempotent and ignored sources do not reappear.
@Observable
@MainActor
final class SourceDecisionStore {
    private let defaults = UserDefaults.standard
    private let key = "symaira.hub.sourceDecisions"

    private var storage: [String: SourceDecision] = [:]

    init() {
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
        save()
    }

    /// All source IDs currently marked as ignored.
    var ignoredSourceIDs: Set<String> {
        Set(storage.filter { $0.value == .ignored }.keys)
    }

    /// Reset all ignored sources back to pending.
    func resetIgnored() {
        storage = storage.filter { $0.value != .ignored }
        save()
    }

    /// Reset a single source back to pending.
    func resetDecision(for sourceID: String) {
        storage.removeValue(forKey: sourceID)
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: SourceDecision].self, from: data)
        else { return }
        storage = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(storage) else { return }
        defaults.set(data, forKey: key)
    }
}
