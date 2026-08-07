import Foundation

/// Protocol for source discovery adapters — mock or real.
protocol SourceDiscoveryAdapter: Sendable {
    /// Discover sources. Returns metadata only, never raw content or credentials.
    /// Per-adapter failures are returned inside the result, not thrown.
    func discover() async throws -> DiscoveryResult
}

/// Mock adapter returning sample data for development and testing.
/// Swappable for real adapters (#26, #27) without Hub-side changes.
actor MockDiscoveryAdapter: SourceDiscoveryAdapter {
    /// Simulated network delay range, in seconds.
    let minDelay: Double
    let maxDelay: Double

    /// If true, the next call throws to simulate a tool error.
    var simulateError = false

    /// Make the next discover() call throw to simulate a tool error.
    func setSimulateError(_ value: Bool) {
        simulateError = value
    }

    /// Sample sources returned on success.
    private let sampleSources: [DiscoveredSource] = [
        DiscoveredSource(
            sourceID: "mock:claude-code-sessions",
            tool: "symmemory",
            kind: "session-data",
            displayName: "Claude Code Sessions",
            location: "~/Library/Application Support/Claude/",
            capabilities: ["import"],
            itemCount: 142,
            lastSeen: ISO8601DateFormatter().string(from: Date()),
            privacyHint: "may_contain_personal_data"
        ),
        DiscoveredSource(
            sourceID: "mock:hermes-agent-sessions",
            tool: "symmemory",
            kind: "session-data",
            displayName: "Hermes Agent Sessions",
            location: "~/.hermes/sessions/",
            capabilities: ["import"],
            itemCount: 38,
            lastSeen: ISO8601DateFormatter().string(from: Date()),
            privacyHint: "may_contain_personal_data"
        ),
        DiscoveredSource(
            sourceID: "mock:unmanaged-skills",
            tool: "symskills",
            kind: "skill-bundle",
            displayName: "Unmanaged Skill Bundles",
            location: "~/.config/opencode/skills/",
            capabilities: ["import"],
            itemCount: 7,
            lastSeen: ISO8601DateFormatter().string(from: Date()),
            privacyHint: "none"
        ),
        DiscoveredSource(
            sourceID: "mock:profile-links-review",
            tool: "symskills",
            kind: "profile-context",
            displayName: "Profile Links (review needed)",
            location: "~/.config/symskills/profiles/",
            capabilities: ["import"],
            itemCount: 3,
            lastSeen: ISO8601DateFormatter().string(from: Date()),
            privacyHint: "none"
        )
    ]

    init(minDelay: Double = 0.3, maxDelay: Double = 1.2) {
        self.minDelay = minDelay
        self.maxDelay = maxDelay
    }

    func discover() async throws -> DiscoveryResult {
        // Simulate discovery latency
        let delay = Double.random(in: minDelay...maxDelay)
        try await Task.sleep(for: .seconds(delay))

        if simulateError {
            throw DiscoveryError.toolUnavailable("symmemory")
        }

        return DiscoveryResult(sources: sampleSources)
    }
}

/// A discovery adapter that always returns an empty list.
actor EmptyDiscoveryAdapter: SourceDiscoveryAdapter {
    func discover() async throws -> DiscoveryResult { DiscoveryResult(sources: []) }
}

enum DiscoveryError: Error, LocalizedError, Sendable, Equatable, Hashable {
    case toolUnavailable(String)
    case timeout(String)
    case invalidResponse(String)
    case schemaMismatch(tool: String, expected: Int, actual: Int)

    var errorDescription: String? {
        switch self {
        case .toolUnavailable(let tool):
            return "\(tool) is not available"
        case .timeout(let tool):
            return "\(tool) did not respond in time"
        case .invalidResponse(let detail):
            return "Invalid discovery response: \(detail)"
        case .schemaMismatch(let tool, let expected, let actual):
            return "\(tool) uses schema v\(actual), Hub expects v\(expected)"
        }
    }
}
