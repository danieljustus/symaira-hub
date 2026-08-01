import Foundation

/// Adapter that calls `symmemory discover sources` and maps the output
/// to the Source Discovery Contract v1 format.
actor SymmemoryDiscoveryAdapter: SourceDiscoveryAdapter {
    private let binaryPath: String

    init(binaryPath: String = "/opt/homebrew/bin/symmemory") {
        self.binaryPath = binaryPath
    }

    func discover() async throws -> [DiscoveredSource] {
        let data = try await runSymmemoryDiscover()
        let response = try JSONDecoder().decode(DiscoveryResponse.self, from: data)
        guard response.schemaVersion == DiscoveryContract.expectedSchemaVersion else {
            throw DiscoveryError.schemaMismatch(
                tool: "symmemory",
                expected: DiscoveryContract.expectedSchemaVersion,
                actual: response.schemaVersion
            )
        }
        return response.sources
    }

    /// Run `symmemory discover sources` and return stdout data.
    private func runSymmemoryDiscover() async throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = ["discover", "sources"]
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
                continuation.resume(throwing: DiscoveryError.toolUnavailable("symmemory"))
            }
        }
    }
}
