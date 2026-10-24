//
//  DiagnosticsView.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/24
//

import Application
import Domain
import SwiftUI

struct DiagnosticsView: View {
    let session: PartnershipSession

    @State private var entries: [DiagnosticEntry] = []

    var body: some View {
        DiagnosticsList(entries: entries)
            .task { entries = session.recentDiagnostics() }
    }
}

struct DiagnosticsList: View {
    let entries: [DiagnosticEntry]

    var body: some View {
        List {
            if entries.isEmpty {
                Text(.diagnosticsEmpty)
                    .foregroundStyle(.secondary)
            }
            ForEach(entries) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.occurredAt, format: Date.FormatStyle.monthDayTimeSeconds)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Label(entry.operation, systemImage: entry.isFailure ? "exclamationmark.triangle" : "info.circle")
                        .font(.subheadline.weight(.semibold))
                    Text(entry.detail)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
            }
        }
        .navigationTitle(.diagnosticsTitle)
        .toolbar {
            ShareLink(item: sharedText)
        }
    }
}

// MARK: - Private

private extension DiagnosticsList {
    var sharedText: String {
        entries.map { entry in
            "\(entry.occurredAt.formatted(.iso8601)) \(entry.isFailure ? "failure" : "decision") \(entry.operation): \(entry.detail)"
        }
        .joined(separator: "\n")
    }
}

#Preview("診断の記録") {
    NavigationStack {
        DiagnosticsList(entries: DiagnosticEntry.previews)
    }
}

#Preview("診断の記録が空") {
    NavigationStack {
        DiagnosticsList(entries: [])
    }
}
