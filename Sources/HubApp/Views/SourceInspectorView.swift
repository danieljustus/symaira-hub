import SwiftUI
import SymairaTheme

/// Pending-source inspector: list/detail view with Add, Ignore, Review-later decisions.
struct SourceInspectorView: View {
    @Environment(HubState.self) private var state

    var body: some View {
        let pending = state.sourceCandidates.filter(\.isPending)

        if pending.isEmpty, state.sourceScanError == nil {
            emptyState
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    if let error = state.sourceScanError {
                        errorBanner(error)
                    }

                    ForEach(state.sourceCandidates) { candidate in
                        SourceCandidateCard(candidate: candidate)
                    }

                    // Show the ignored-source management section whenever
                    // ignored sources exist — including when every candidate
                    // has been handled and none are pending — so Reset All
                    // stays reachable.
                    if !state.decisionStore.ignoredSourceIDs.isEmpty {
                        ignoredSection
                    }
                }
                .padding(28)
                .frame(maxWidth: 640, alignment: .leading)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Sources")
                    .symairaText(.display)
                Spacer()
                Button {
                    Task { await state.refreshSources() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help("Rescan sources")
            }
            Text("Pending source candidates discovered by installed tools. "
                 + "Choose Add, Ignore, or Review later for each.")
                .symairaText(.secondary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkle.magnifyingglass")
                .symairaText(.display, respectsForeground: false)
                .foregroundStyle(SymairaTheme.textMuted)
            Text("No new sources found")
                .symairaText(.title)
            Text("Sources discovered by installed tools will appear here. "
                 + "Click the refresh button to scan again.")
                .symairaText(.secondary)
                .multilineTextAlignment(.center)
            Button("Scan Now") {
                Task { await state.refreshSources() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(SymairaTheme.goldPrimary)
            Text(message)
                .symairaText(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SymairaTheme.goldPrimary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var ignoredSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider().overlay(SymairaTheme.textMuted.opacity(0.2))
            HStack {
                Text("Ignored Sources")
                    .symairaText(.subheading, respectsForeground: false)
                    .foregroundStyle(SymairaTheme.textMuted)
                Spacer()
                Button("Reset All") {
                    state.resetIgnoredSources()
                }
                .buttonStyle(.plain)
                .symairaText(.callout, respectsForeground: false)
                .foregroundStyle(SymairaTheme.goldPrimary)
            }
            Text("Ignored sources are hidden from future scans. "
                 + "Reset to make them visible again.")
                .symairaText(.caption)
        }
    }
}

// MARK: - Source Candidate Card

struct SourceCandidateCard: View {
    let candidate: SourceCandidate
    @Environment(HubState.self) private var state

    @State private var showAddConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header row
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(candidate.source.displayName)
                        .symairaText(.subheading)
                    SymairaStatusLabel(decisionLabel, tone: decisionTone)
                }
                Spacer()
            }

            // Metadata
            VStack(alignment: .leading, spacing: 4) {
                row("Tool", candidate.source.tool)
                row("Type", candidate.source.kind)
                row("Location", candidate.source.location)
                if let count = candidate.source.itemCount {
                    row("Items", "\(count)")
                }
                row("Capabilities", candidate.source.capabilitySummary)
                if let hint = candidate.source.privacyHint {
                    row("Privacy", hint)
                }
            }

            // Action buttons (only for pending sources)
            if candidate.isPending {
                HStack(spacing: 8) {
                    addButton
                    ignoreButton
                    snoozeButton
                }
                .padding(.top, 6)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassmorphicPanel()
        .confirmationDialog(
            "Import \(candidate.source.displayName)?",
            isPresented: $showAddConfirmation
        ) {
            Button("Import \(candidate.source.itemCount ?? 0) items") {
                state.approveSource(candidate)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will import data from \(candidate.source.tool). "
                 + "A preview is not yet available — the import will start immediately.")
        }
    }

    private var addButton: some View {
        Button {
            showAddConfirmation = true
        } label: {
            Label("Add", systemImage: "plus.circle.fill")
                .symairaText(.bodyEmphasized, respectsForeground: false)
        }
        .buttonStyle(.borderedProminent)
        .tint(SymairaTheme.goldPrimary)
    }

    private var ignoreButton: some View {
        Button {
            state.ignoreSource(candidate)
        } label: {
            Label("Ignore", systemImage: "eye.slash")
                .symairaText(.callout, respectsForeground: false)
        }
        .buttonStyle(.bordered)
    }

    private var snoozeButton: some View {
        Button {
            state.snoozeSource(candidate)
        } label: {
            Label("Later", systemImage: "clock")
                .symairaText(.callout, respectsForeground: false)
        }
        .buttonStyle(.bordered)
    }

    private var decisionLabel: String {
        switch candidate.decision {
        case .approved: return "Added"
        case .ignored: return "Ignored"
        case .snoozed: return "Snoozed"
        case .pending: return "Pending"
        }
    }

    private var decisionTone: SymairaTone {
        switch candidate.decision {
        case .pending: return .warning
        case .approved: return .positive
        case .ignored: return .neutral
        case .snoozed: return .informative
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .frame(width: 90, alignment: .leading)
                .symairaText(.caption)
            Text(value)
                .symairaText(.monoSmall)
                .textSelection(.enabled)
        }
    }
}
