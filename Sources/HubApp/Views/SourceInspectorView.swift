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

                    if !state.sourceCandidates.isEmpty {
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
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(SymairaTheme.textPrimary)
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
                .font(.callout)
                .foregroundStyle(SymairaTheme.textMuted)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(SymairaTheme.textMuted)
            Text("No new sources found")
                .font(.title2)
                .foregroundStyle(SymairaTheme.textPrimary)
            Text("Sources discovered by installed tools will appear here. "
                 + "Click the refresh button to scan again.")
                .foregroundStyle(SymairaTheme.textMuted)
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
                .font(.callout)
                .foregroundStyle(SymairaTheme.textSecondary)
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
                    .font(.headline)
                    .foregroundStyle(SymairaTheme.textMuted)
                Spacer()
                Button("Reset All") {
                    state.resetIgnoredSources()
                }
                .buttonStyle(.plain)
                .foregroundStyle(SymairaTheme.goldPrimary)
                .font(.callout)
            }
            Text("Ignored sources are hidden from future scans. "
                 + "Reset to make them visible again.")
                .font(.caption)
                .foregroundStyle(SymairaTheme.textMuted)
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
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(candidate.source.displayName)
                    .font(.headline)
                    .foregroundStyle(SymairaTheme.textPrimary)
                Spacer()
                decisionBadge
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
                .font(.callout.weight(.medium))
        }
        .buttonStyle(.borderedProminent)
        .tint(SymairaTheme.goldPrimary)
    }

    private var ignoreButton: some View {
        Button {
            state.ignoreSource(candidate)
        } label: {
            Label("Ignore", systemImage: "eye.slash")
                .font(.callout)
        }
        .buttonStyle(.bordered)
    }

    private var snoozeButton: some View {
        Button {
            state.snoozeSource(candidate)
        } label: {
            Label("Later", systemImage: "clock")
                .font(.callout)
        }
        .buttonStyle(.bordered)
    }

    private var decisionBadge: some View {
        Group {
            switch candidate.decision {
            case .approved:
                Label("Added", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            case .ignored:
                Label("Ignored", systemImage: "eye.slash.fill")
                    .font(.caption)
                    .foregroundStyle(SymairaTheme.textMuted)
            case .snoozed:
                Label("Snoozed", systemImage: "clock.fill")
                    .font(.caption)
                    .foregroundStyle(SymairaTheme.goldPrimary)
            case .pending:
                EmptyView()
            }
        }
    }

    private var statusColor: Color {
        switch candidate.decision {
        case .pending: return SymairaTheme.goldPrimary
        case .approved: return .green
        case .ignored: return SymairaTheme.textMuted.opacity(0.4)
        case .snoozed: return .orange
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .frame(width: 90, alignment: .leading)
                .foregroundStyle(SymairaTheme.textMuted)
                .font(.caption)
            Text(value)
                .font(.caption.monospaced())
                .foregroundStyle(SymairaTheme.textSecondary)
                .textSelection(.enabled)
        }
    }
}
