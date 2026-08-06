import Foundation

/// Codable types matching the Source Discovery Contract v1.
enum DiscoveryContract {
    static let expectedSchemaVersion = 1
}

/// Top-level discovery response envelope.
struct DiscoveryResponse: Codable, Sendable {
    let schemaVersion: Int
    let sources: [DiscoveredSource]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case sources
    }
}

/// Result of a discovery run: the sources found plus any per-adapter
/// failures. Adapters keep working even when a sibling provider is down,
/// so failures travel alongside the results instead of aborting the scan.
struct DiscoveryResult: Sendable, Equatable {
    var sources: [DiscoveredSource]
    var failures: [DiscoveryError] = []
}

/// A single discovered source candidate.
struct DiscoveredSource: Codable, Identifiable, Sendable, Equatable {
    let sourceID: String
    let tool: String
    let kind: String
    let displayName: String
    let location: String
    let capabilities: [String]
    let itemCount: Int?
    let lastSeen: String?
    let privacyHint: String?

    enum CodingKeys: String, CodingKey {
        case sourceID = "source_id"
        case tool, kind
        case displayName = "display_name"
        case location, capabilities
        case itemCount = "item_count"
        case lastSeen = "last_seen"
        case privacyHint = "privacy_hint"
    }

    var id: String { sourceID }

    /// Human-readable capability summary for the UI.
    var capabilitySummary: String {
        capabilities.joined(separator: ", ")
    }
}

// MARK: - Decision State

enum SourceDecision: String, Codable, Sendable, CaseIterable {
    case pending
    case approved
    case ignored
    case snoozed
}
