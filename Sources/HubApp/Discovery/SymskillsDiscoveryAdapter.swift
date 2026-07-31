import Foundation

/// Adapter that calls `symskills discover --json` and maps the output
/// to the Source Discovery Contract v1 format.
actor SymskillsDiscoveryAdapter: SourceDiscoveryAdapter {
    private let binaryPath: String

    init(binaryPath: String = "/opt/homebrew/bin/symskills") {
        self.binaryPath = binaryPath
    }

    func discover() async throws -> [DiscoveredSource] {
        let data = try await runSymskillsDiscover()
        let response = try JSONDecoder().decode(SymskillsDiscoverResponse.self, from: data)
        return response.candidates.map { $0.toDiscoveredSource() }
    }

    /// Run `symskills discover --json` and return stdout data.
    private func runSymskillsDiscover() async throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = ["discover", "--json"]
        process.qualityOfService = .userInitiated

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { proc in
                guard proc.terminationStatus == 0 else {
                    let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    let message = String(data: errData, encoding: .utf8) ?? "unknown error"
                    continuation.resume(throwing: DiscoveryError.invalidResponse(message))
                    return
                }
                let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: data)
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: DiscoveryError.toolUnavailable("symskills"))
            }
        }
    }
}

// MARK: - symskills JSON types

private struct SymskillsDiscoverResponse: Codable {
    let candidates: [SymskillsCandidate]
}

private struct SymskillsCandidate: Codable {
    let sourceID: String
    let target: String
    let kind: String
    let displayName: String
    let location: String
    let managed: Bool
    let valid: Bool
    let source: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case sourceID = "source_id"
        case target, kind
        case displayName = "display_name"
        case location, managed, valid, source, status
    }

    func toDiscoveredSource() -> DiscoveredSource {
        DiscoveredSource(
            sourceID: "symskills:\(sourceID)",
            tool: "symskills",
            kind: kind.replacingOccurrences(of: "_", with: "-"),
            displayName: displayName,
            location: location,
            capabilities: ["import"],
            itemCount: nil,
            lastSeen: ISO8601DateFormatter().string(from: Date()),
            privacyHint: "none"
        )
    }
}
