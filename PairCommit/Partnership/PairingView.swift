//
//  PairingView.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/06/20
//

import SwiftUI

struct PairingView: View {
    let phase: MultipeerPairing.Phase
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(.tint)
                .frame(width: 96, height: 96)
                .background(Color(.secondarySystemGroupedBackground), in: .circle)
                .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
                .accessibilityHidden(true)

            Text("相手と繋ぐ")
                .font(.system(.title2, design: .rounded, weight: .bold))

            if case .failed(let message) = phase {
                FailureNote(message: message)
                Text("「戻る」を押して、2台とも選び直してください。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                steps
                if currentStep != .loading {
                    Text("2台を近くに置いたまま待ってください。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer()
            Button(isFailed ? "戻る" : "やめる", action: onCancel)
                .buttonStyle(.soft)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Backdrop())
    }
}

// MARK: - Private

private extension PairingView {
    enum Step: Int, CaseIterable {
        case searching
        case sharing
        case loading

        var title: String {
            switch self {
            case .searching: return "近くの相手を見つける"
            case .sharing:   return "iCloud で共有する"
            case .loading:   return "ペアの情報を読み込む"
            }
        }
    }

    // 成功してからも、読み込みが終わるまではこの画面が出ている。
    var currentStep: Step {
        switch phase {
        case .idle, .searching, .failed: return .searching
        case .connected, .sharing:       return .sharing
        case .done:                      return .loading
        }
    }

    var isFailed: Bool {
        if case .failed = phase { return true }
        return false
    }

    var steps: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Step.allCases, id: \.self) { step in
                HStack(spacing: 12) {
                    Image(systemName: symbol(for: step))
                        .foregroundStyle(symbolStyle(for: step))
                        .accessibilityHidden(true)
                    Text(step.title)
                        .fontWeight(step == currentStep ? .semibold : .regular)
                        .foregroundStyle(step == currentStep ? HierarchicalShapeStyle.primary : .secondary)
                }
            }
        }
        .card()
    }

    func symbol(for step: Step) -> String {
        if step.rawValue < currentStep.rawValue { return "checkmark.circle.fill" }
        if step == currentStep { return "ellipsis.circle.fill" }
        return "circle"
    }

    func symbolStyle(for step: Step) -> AnyShapeStyle {
        step.rawValue > currentStep.rawValue ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.tint)
    }
}

#Preview("ペアリングの相手待ち") {
    PairingView(phase: .searching, onCancel: {})
}

#Preview("ペアリングの共有中") {
    PairingView(phase: .sharing, onCancel: {})
}

#Preview("ペアリングの読み込み中") {
    PairingView(phase: .done, onCancel: {})
}

#Preview("ペアリングの失敗") {
    PairingView(phase: .failed("相手も役割を選んでいます。どちらか一方が「相手の招待を受ける」を選んでください。"), onCancel: {})
}
