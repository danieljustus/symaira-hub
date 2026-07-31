import SwiftUI
import SymairaTheme
import SymairaToolKit

struct ContentView: View {
    @Environment(HubState.self) private var state

    var body: some View {
        @Bindable var state = state
        NavigationSplitView {
            List(selection: $state.selectedToolID) {
                // Source inspector section
                if state.pendingSourceCount > 0 {
                    Section {
                        SourceInspectorRow()
                            .tag("__source_inspector__")
                    } header: {
                        Text("Sources")
                    }
                }

                Section("Installiert (\(state.installedCount))") {
                    ForEach(state.rows.filter(\.isInstalled)) { row in
                        ToolRowView(row: row).tag(row.id)
                    }
                }
                Section("Verfügbar") {
                    ForEach(state.rows.filter { !$0.isInstalled }) { row in
                        ToolRowView(row: row).tag(row.id)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 220, ideal: 250)
            .toolbar {
                ToolbarItem {
                    Button {
                        Task { await state.refresh() }
                    } label: {
                        if state.isRefreshing {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .help("Tools neu erkennen")
                    .disabled(state.isRefreshing)
                }
            }
        } detail: {
            ZStack {
                SymairaTheme.bgDark.ignoresSafeArea()
                AmbientGlows()
                if state.selectedToolID == "__source_inspector__" {
                    SourceInspectorView()
                } else if let row = state.selectedRow {
                    ToolDetailView(row: row)
                } else {
                    Text("Tool auswählen")
                        .foregroundStyle(SymairaTheme.textMuted)
                }
            }
        }
        .navigationTitle("Symaira Hub")
    }
}

/// Sidebar row for the source inspector, with a pending count badge.
struct SourceInspectorRow: View {
    @Environment(HubState.self) private var state

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkle.magnifyingglass")
                .foregroundStyle(SymairaTheme.goldPrimary)
            Text("Pending Sources")
            Spacer()
            Text("\(state.pendingSourceCount)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.black)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(SymairaTheme.goldPrimary)
                .clipShape(Capsule())
        }
    }
}

struct ToolRowView: View {
    let row: ToolRow

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(row.isInstalled ? SymairaTheme.goldPrimary : SymairaTheme.textMuted.opacity(0.4))
                .frame(width: 8, height: 8)
            Text(row.tool.displayName)
            Spacer()
            if let version = row.detected?.versionInfo?.version {
                Text(version)
                    .font(.caption2.monospaced())
                    .foregroundStyle(SymairaTheme.textMuted)
            }
        }
    }
}

struct SettingsView: View {
    @Environment(HubState.self) private var state

    var body: some View {
        Form {
            LabeledContent("Erkannte Tools", value: "\(state.installedCount) von \(state.rows.count)")
            if let last = state.lastRefresh {
                LabeledContent("Letzte Erkennung", value: last.formatted(date: .omitted, time: .standard))
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}
