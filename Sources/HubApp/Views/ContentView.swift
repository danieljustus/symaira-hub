import SwiftUI
import SymairaTheme
import SymairaToolKit

struct ContentView: View {
    @Environment(HubState.self) private var state

    var body: some View {
        @Bindable var state = state
        NavigationSplitView {
            List(selection: $state.selectedToolID) {
                // Source inspector section — always rendered so ignored
                // sources stay resettable and scan errors stay visible even
                // when no sources are pending.
                Section {
                    SourceInspectorRow()
                        .tag("__source_inspector__")
                } header: {
                    Text("Sources")
                }

                Section("Installed (\(state.installedCount))") {
                    ForEach(state.rows.filter(\.isInstalled)) { row in
                        ToolRowView(row: row).tag(row.id)
                    }
                }
                Section("Available") {
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
                    .help("Rescan tools")
                    .disabled(state.isRefreshing)
                }
            }
        } detail: {
            ZStack {
                SymairaTheme.bgDark.ignoresSafeArea()
                AmbientGlows()
                if state.selectedToolID == "__source_inspector__" {
                    SourceInspectorView(model: SourceInspectorModel(state: state))
                } else if let row = state.selectedRow {
                    ToolDetailView(row: row)
                } else {
                    Text("Select a tool")
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
            if state.pendingSourceCount > 0 {
                Text("\\(state.pendingSourceCount)")
                    .symairaText(.monoSmall, respectsForeground: false)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(SymairaTheme.goldPrimary)
                    .clipShape(Capsule())
            }
        }
    }
}

struct ToolRowView: View {
    let row: ToolRow

    var body: some View {
        HStack(spacing: 8) {
            Text(row.tool.displayName)
                .symairaText(.body)
            Spacer()
            SymairaStatusLabel(
                row.isInstalled ? "Installed" : "Available",
                tone: row.isInstalled ? .positive : .neutral
            )
            if let version = row.detected?.versionInfo?.version {
                Text(version)
                    .symairaText(.monoSmall)
            }
        }
    }
}

struct SettingsView: View {
    @Environment(HubState.self) private var state

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SymairaFormSection("Hub", footer: "Tools are detected at launch and on every refresh.") {
                SymairaFormRow("Detected Tools") {
                    Text("\(state.installedCount) of \(state.rows.count)")
                        .symairaText(.bodyEmphasized)
                }

                if let last = state.lastRefresh {
                    SymairaFormDivider()
                    SymairaFormRow("Last Scan") {
                        Text(last.formatted(date: .omitted, time: .standard))
                            .symairaText(.monoSmall)
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}
