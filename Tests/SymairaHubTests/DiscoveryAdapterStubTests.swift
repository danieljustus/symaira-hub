import XCTest
import SymairaCLIRunner
@testable import SymairaHub

/// Adapter JSON decoding tests using stub binaries on disk, so no real
/// symmemory/symskills CLI is required. The adapters accept binaryPath:,
/// which is exactly the seam #45/#46 created.
final class DiscoveryAdapterStubTests: XCTestCase {
    private var stubDir: URL!

    override func setUp() {
        super.setUp()
        stubDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("hub-stubs-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: stubDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: stubDir)
        stubDir = nil
        super.tearDown()
    }

    /// Write an executable stub script whose body is `script` (sh syntax).
    private func makeStub(_ name: String, script: String) throws -> String {
        let path = stubDir.appendingPathComponent(name)
        try "#!/bin/sh\n\(script)\n".write(to: path, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path.path)
        return path.path
    }

    private let symmemoryOK = """
    {"schema_version": 1, "sources": [
      {"source_id": "m:1", "tool": "symmemory", "kind": "session-data",
       "display_name": "Memo One", "location": "/tmp/m1",
       "capabilities": ["import"], "item_count": 42,
       "last_seen": "2026-08-01T00:00:00Z", "privacy_hint": "none"}
    ]}
    """

    private let symskillsOK = """
    {"schema_version": 1, "candidates": [
      {"source_id": "s:1", "target": "opencode", "kind": "skill_bundle",
       "display_name": "Skill One", "location": "/tmp/s1",
       "managed": true, "valid": true, "source": "scanned", "status": "managed"}
    ]}
    """

    private let symskillsLegacy = """
    {"candidates": [
      {"source_id": "s:1", "target": "opencode", "kind": "skill_bundle",
       "display_name": "Skill One", "location": "/tmp/s1",
       "managed": false, "valid": true, "source": "scanned", "status": "candidate"}
    ]}
    """

    /// Wrap a JSON payload in a shell heredoc that prints it on stdout.
    private func jsonScript(_ json: String) -> String {
        "cat <<'EOF'\n\(json)\nEOF"
    }

    func testSymmemoryDecodesSources() async throws {
        let stub = try makeStub("symmemory", script: jsonScript(symmemoryOK))
        let adapter = SymmemoryDiscoveryAdapter(binaryPath: stub)

        let sources = try await adapter.discover()

        XCTAssertEqual(sources.count, 1)
        XCTAssertEqual(sources.first?.sourceID, "m:1")
        XCTAssertEqual(sources.first?.displayName, "Memo One")
        XCTAssertEqual(sources.first?.itemCount, 42)
    }

    func testSymmemorySchemaMismatchThrows() async throws {
        let stub = try makeStub("symmemory-v2", script: jsonScript("{\"schema_version\": 2, \"sources\": []}"))
        let adapter = SymmemoryDiscoveryAdapter(binaryPath: stub)

        do {
            _ = try await adapter.discover()
            XCTFail("expected schemaMismatch")
        } catch let error as DiscoveryError {
            guard case .schemaMismatch(let tool, let expected, let actual) = error else {
                return XCTFail("unexpected error: \(error)")
            }
            XCTAssertEqual(tool, "symmemory")
            XCTAssertEqual(expected, DiscoveryContract.expectedSchemaVersion)
            XCTAssertEqual(actual, 2)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testSymskillsDecodesCandidatesWithSchemaVersion() async throws {
        let stub = try makeStub("symskills", script: jsonScript(symskillsOK))
        let adapter = SymskillsDiscoveryAdapter(binaryPath: stub)

        let sources = try await adapter.discover()

        XCTAssertEqual(sources.count, 1)
        let candidate = try XCTUnwrap(sources.first)
        XCTAssertEqual(candidate.sourceID, "symskills:s:1")
        XCTAssertEqual(candidate.kind, "skill-bundle")
        XCTAssertEqual(candidate.capabilities, ["import", "managed"])
        XCTAssertNil(candidate.lastSeen)
        XCTAssertEqual(candidate.privacyHint, "unknown")
    }

    func testSymskillsAcceptsMissingSchemaVersionAsBestEffort() async throws {
        let stub = try makeStub("symskills-legacy", script: jsonScript(symskillsLegacy))
        let adapter = SymskillsDiscoveryAdapter(binaryPath: stub)

        let sources = try await adapter.discover()

        XCTAssertEqual(sources.count, 1)
        XCTAssertEqual(sources.first?.capabilities, ["import", "unmanaged"])
    }

    func testSymskillsSchemaMismatchThrows() async throws {
        let stub = try makeStub("symskills-v2", script: jsonScript("{\"schema_version\": 2, \"candidates\": []}"))
        let adapter = SymskillsDiscoveryAdapter(binaryPath: stub)

        do {
            _ = try await adapter.discover()
            XCTFail("expected schemaMismatch")
        } catch let error as DiscoveryError {
            guard case .schemaMismatch(let tool, _, let actual) = error else {
                return XCTFail("unexpected error: \(error)")
            }
            XCTAssertEqual(tool, "symskills")
            XCTAssertEqual(actual, 2)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testMissingBinaryThrowsToolUnavailable() async {
        let adapter = SymmemoryDiscoveryAdapter(binaryPath: "/nonexistent/symmemory")

        do {
            _ = try await adapter.discover()
            XCTFail("expected toolUnavailable")
        } catch let error as DiscoveryError {
            guard case .toolUnavailable(let tool) = error else {
                return XCTFail("unexpected error: \(error)")
            }
            XCTAssertEqual(tool, "symmemory")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testHungBinaryTimesOutAndTerminates() async throws {
        // Sleeps longer than the runner timeout; the runner must time out
        // and terminate the process instead of hanging the test.
        let stub = try makeStub("symmemory-hung", script: """
        sleep 30
        echo '{"schema_version": 1, "sources": []}'
        """)
        let adapter = SymmemoryDiscoveryAdapter(
            binaryPath: stub,
            runner: CLIRunner(defaultTimeout: 1)
        )

        do {
            _ = try await adapter.discover()
            XCTFail("expected timeout")
        } catch let error as DiscoveryError {
            guard case .timeout = error else {
                return XCTFail("unexpected error: \(error)")
            }
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testNonZeroExitThrowsInvalidResponse() async throws {
        let stub = try makeStub("symmemory-broken", script: """
        echo 'boom' >&2
        exit 3
        """)
        let adapter = SymmemoryDiscoveryAdapter(binaryPath: stub)

        do {
            _ = try await adapter.discover()
            XCTFail("expected invalidResponse")
        } catch let error as DiscoveryError {
            guard case .invalidResponse = error else {
                return XCTFail("unexpected error: \(error)")
            }
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testSymskillsNonZeroExitThrowsInvalidResponse() async throws {
        let stub = try makeStub("symskills-broken", script: """
        echo 'boom' >&2
        exit 3
        """)
        let adapter = SymskillsDiscoveryAdapter(binaryPath: stub)

        do {
            _ = try await adapter.discover()
            XCTFail("expected invalidResponse")
        } catch let error as DiscoveryError {
            guard case .invalidResponse(let detail) = error else {
                return XCTFail("unexpected error: \(error)")
            }
            XCTAssertTrue(detail.contains("boom"))
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testSymskillsMissingBinaryThrowsToolUnavailable() async {
        let adapter = SymskillsDiscoveryAdapter(binaryPath: "/nonexistent/symskills")

        do {
            _ = try await adapter.discover()
            XCTFail("expected toolUnavailable")
        } catch let error as DiscoveryError {
            guard case .toolUnavailable(let tool) = error else {
                return XCTFail("unexpected error: \(error)")
            }
            XCTAssertEqual(tool, "symskills")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}
