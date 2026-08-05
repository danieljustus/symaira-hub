import SwiftUI
import AppKit
import SymairaTheme
import SymairaToolKit
import SymscopeFeature
import SymseekFeature

struct ToolDetailView: View {
    let row: ToolRow

    var body: some View {
        if row.isInstalled, let mismatch = schemaMismatch {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    upgradeWarningView(expected: mismatch.expected, actual: mismatch.actual)
                }
                .padding(28)
                .frame(maxWidth: 640, alignment: .leading)
            }
        } else if row.isInstalled, let module = embeddedModule {
            module
        } else {
            infoView
        }
    }

    // Embedded feature modules (Module Integration Contract). A tool
    // appears here once its repo exposes a feature package.
    // No trailing else on purpose: the builder yields nil for tools
    // without an embedded module, so the info view renders instead.
    @ViewBuilder
    private var embeddedModule: (some View)? {
        if row.tool.id == "symscope" {
            SymscopeModuleView()
        } else if row.tool.id == "symseek" {
            SymseekModuleView()
        }
    }

    private var schemaMismatch: (expected: Int, actual: Int)? {
        guard let detected = row.detected else { return nil }
        let actual = detected.versionInfo?.schemaVersion ?? 0
        let expected: Int
        if row.tool.id == "symscope" {
            expected = SymscopeModule.expectedSchemaVersion
        } else if row.tool.id == "symseek" {
            expected = SymseekModule.expectedSchemaVersion
        } else {
            return nil
        }

        if actual != 0 && actual != expected {
            return (expected, actual)
        }
        return nil
    }

    private func upgradeWarningView(expected: Int, actual: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Inkompatible CLI-Version")
                .symairaText(.subheading)
            Text("Das installierte CLI-Tool verwendet Schema-Version "
                 + "\\(actual), aber dieses Hub-Modul erwartet Version \\(expected).")
                .symairaText(.secondary)
            Text("Bitte aktualisiere das CLI-Tool:")
                .symairaText(.subheading)
            HStack {
                Text("brew upgrade \(row.tool.homebrewFormula)")
                    .symairaText(.monoSmall, respectsForeground: false)
                    .foregroundStyle(SymairaTheme.goldPrimary)
                    .textSelection(.enabled)
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("brew upgrade \(row.tool.homebrewFormula)", forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.plain)
                .help("Befehl kopieren")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassmorphicPanel()
    }

    private var infoView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if let detected = row.detected {
                    installedCard(detected)
                    modulePlaceholder
                } else {
                    installCard
                }
            }
            .padding(28)
            .frame(maxWidth: 640, alignment: .leading)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(row.tool.displayName)
                .symairaText(.display)
            Text(row.tool.binaryName)
                .symairaText(.monoSmall)
        }
    }

    private func installedCard(_ detected: DetectedTool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            row1("Version", detected.versionInfo?.version ?? "unbekannt")
            row1("Schema", schemaLabel(detected.versionInfo?.schemaVersion))
            row1("Pfad", detected.location.url.path)
            row1("Quelle", detected.location.source.rawValue)
            if row.tool.supportsMCP {
                row1("MCP", ([row.tool.binaryName] + row.tool.mcpArgs).joined(separator: " "))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassmorphicPanel()
    }

    private var installCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nicht installiert")
                .symairaText(.subheading)
            Text("Dieses Modul erscheint automatisch, sobald das CLI installiert ist.")
                .symairaText(.secondary)
            HStack {
                Text("brew install \(row.tool.homebrewFormula)")
                    .symairaText(.monoSmall, respectsForeground: false)
                    .foregroundStyle(SymairaTheme.goldPrimary)
                    .textSelection(.enabled)
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("brew install \(row.tool.homebrewFormula)", forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.plain)
                .help("Befehl kopieren")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassmorphicPanel()
    }

    private var modulePlaceholder: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Modul")
                .symairaText(.subheading)
            Text("Das Feature-Modul für \(row.tool.displayName) ist noch nicht "
                 + "in den Hub eingebettet. Integrationsvertrag: "
                 + "siehe AGENTS.md (\"Module Integration Contract\").")
                .symairaText(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassmorphicPanel(addCorners: false)
    }

    private func schemaLabel(_ schema: Int?) -> String {
        switch schema {
        case nil: return "unbekannt"
        case 0: return "0 (kein version --json — best effort)"
        case let ver?: return "\(ver)"
        }
    }

    private func row1(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .frame(width: 80, alignment: .leading)
                .symairaText(.caption)
            Text(value)
                .symairaText(.monoSmall)
                .textSelection(.enabled)
        }
    }
}
