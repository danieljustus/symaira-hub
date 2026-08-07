import XCTest
import SymscopeFeature
import SymseekFeature
@testable import SymairaHub

/// ToolDetailView.schemaMismatch: the installed-tool vs embedded-module
/// schema check extracted from the view body so it is unit-testable.
/// The view adapts the DetectedTool handshake to the primitive signature
/// (toolID + schemaVersion) — DetectedTool itself is not constructible
/// from tests (appkit's memberwise init is internal).
@MainActor
final class ToolDetailViewTests: XCTestCase {
    func testInstalledMismatchReturnsExpectedAndActual() {
        let mismatch = ToolDetailView.schemaMismatch(for: "symscope", schemaVersion: 2)

        XCTAssertEqual(mismatch?.expected, SymscopeModule.expectedSchemaVersion)
        XCTAssertEqual(mismatch?.actual, 2)
    }

    func testInstalledMatchingSchemaReturnsNil() {
        let mismatch = ToolDetailView.schemaMismatch(
            for: "symseek",
            schemaVersion: SymseekModule.expectedSchemaVersion
        )

        XCTAssertNil(mismatch)
    }

    func testLegacyInstallWithoutHandshakeReturnsNil() {
        // actual == 0 (no version --json) is best-effort compatible.
        let mismatch = ToolDetailView.schemaMismatch(for: "symscope", schemaVersion: 0)

        XCTAssertNil(mismatch)
    }

    func testNotInstalledReturnsNil() {
        // No handshake result at all — same as a missing detection.
        let mismatch = ToolDetailView.schemaMismatch(for: "symscope", schemaVersion: nil)

        XCTAssertNil(mismatch)
    }

    func testToolWithoutEmbeddedModuleReturnsNil() {
        let mismatch = ToolDetailView.schemaMismatch(for: "symvault", schemaVersion: 2)

        XCTAssertNil(mismatch)
    }
}
