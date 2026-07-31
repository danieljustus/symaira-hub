import Foundation

/// Aggregates results from multiple discovery adapters.
/// Each adapter runs independently; failures from one do not affect others.
actor CompositeDiscoveryAdapter: SourceDiscoveryAdapter {
    private let adapters: [SourceDiscoveryAdapter]

    init(adapters: [SourceDiscoveryAdapter]) {
        self.adapters = adapters
    }

    func discover() async throws -> [DiscoveredSource] {
        var allSources: [DiscoveredSource] = []
        var seenIDs = Set<String>()

        for adapter in adapters {
            do {
                let sources = try await adapter.discover()
                for source in sources
                    where seenIDs.insert(source.sourceID).inserted {
                        allSources.append(source)
                }
            } catch {
                // One adapter failing doesn't block others.
                // Errors are surfaced through HubState.sourceScanError
                // when ALL adapters fail — handled in refreshSources().
                continue
            }
        }

        return allSources
    }
}
