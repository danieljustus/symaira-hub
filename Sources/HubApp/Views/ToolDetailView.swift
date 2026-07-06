import SwiftUI
import AppKit
import SymairaTheme
import SymairaToolKit

struct ToolDetailView: View {
    let row: ToolRow

    var body: some View {
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
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(SymairaTheme.textPrimary)
            Text(row.tool.binaryName)
                .font(.callout.monospaced())
                .foregroundStyle(SymairaTheme.textMuted)
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
                .font(.headline)
                .foregroundStyle(SymairaTheme.textPrimary)
            Text("Dieses Modul erscheint automatisch, sobald das CLI installiert ist.")
                .foregroundStyle(SymairaTheme.textSecondary)
            HStack {
                Text("brew install \(row.tool.homebrewFormula)")
                    .font(.callout.monospaced())
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
                .font(.headline)
                .foregroundStyle(SymairaTheme.textPrimary)
            Text("Das Feature-Modul für \(row.tool.displayName) ist noch nicht in den Hub eingebettet. Integrationsvertrag: siehe AGENTS.md (\"Module Integration Contract\").")
                .foregroundStyle(SymairaTheme.textSecondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassmorphicPanel(addCorners: false)
    }

    private func schemaLabel(_ schema: Int?) -> String {
        switch schema {
        case nil: return "unbekannt"
        case 0: return "0 (kein version --json — best effort)"
        case let v?: return "\(v)"
        }
    }

    private func row1(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .frame(width: 80, alignment: .leading)
                .foregroundStyle(SymairaTheme.textMuted)
            Text(value)
                .font(.callout.monospaced())
                .foregroundStyle(SymairaTheme.textSecondary)
                .textSelection(.enabled)
        }
    }
}
