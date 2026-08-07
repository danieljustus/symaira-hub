import Foundation

/// Aggregates results from multiple discovery adapters.
/// Each adapter runs independently; failures from one do not affect others.
actor CompositeDiscoveryAdapter: SourceDiscoveryAdapter {
    private let adapters: [SourceDiscoveryAdapter]

    init(adapters: [SourceDiscoveryAdapter]) {
        self.adapters = adapters
    }

    func discover() async throws -> DiscoveryResult {
        var allSources: [DiscoveredSource] = []
        var seenIDs = Set<String>()
        var failures: [DiscoveryError] = []

        for adapter in adapters {
            do {
                let result = try await adapter.discover()
                for source in result.sources
                    where seenIDs.insert(source.sourceID).inserted {
                        allSources.append(source)
                }
                // A conformer may report failures without throwing
                // (e.g. a wrapped aggregate); carry them through.
                failures.append(contentsOf: result.failures)
            } catch let error as DiscoveryError {
                // One adapter failing doesn't block the others. The failure
                // is returned alongside the results so the UI can surface a
                // per-provider hint instead of a silent gap.
                failures.append(error)
            } catch {
                // Defensive: any non-DiscoveryError is still surfaced.
                failures.append(.invalidResponse(error.localizedDescription))
            }
        }

        return DiscoveryResult(sources: allSources, failures: failures)
    }
}
