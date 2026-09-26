//
//  PairingView.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/06/20
//

import Prefire
import SwiftUI

struct PairingView: View {
    let phase: MultipeerPairing.Phase
    var isAnimated = true
    let onCancel: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            beacon

            VStack(spacing: 8) {
                Text(headline)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .contentTransition(.opacity)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
            }
            .multilineTextAlignment(.center)

            Spacer()
            if isFailed {
                Button("選び直す", action: onCancel)
                    .buttonStyle(.filled)
            } else {
                Button("やめる", action: onCancel)
                    .buttonStyle(.soft)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Backdrop())
        .animation(.spring(duration: 0.5, bounce: 0.25), value: phase)
        .sensoryFeedback(trigger: phase) { _, new in
            switch new {
            case .connected: return .impact(weight: .light)
            case .done: return .success
            case .failed: return .error
            case .idle, .searching, .sharing: return nil
            }
        }
    }
}

// MARK: - Private

private extension PairingView {
    struct Radar: View {
        let isAnimated: Bool

        var body: some View {
            TimelineView(.animation(paused: !isAnimated)) { context in
                let time = isAnimated ? context.date.timeIntervalSinceReferenceDate : 0
                ZStack {
                    ForEach(0..<3, id: \.self) { index in
                        let progress = (time / 2.4 + Double(index) / 3).truncatingRemainder(dividingBy: 1)
                        Circle()
                            .stroke(lineWidth: 1.5)
                            .foregroundStyle(.tint)
                            .scaleEffect(1 + progress)
                            .opacity(1 - progress)
                    }
                }
            }
            .frame(width: 96, height: 96)
        }
    }

    struct Orbit: View {
        let isAnimated: Bool

        var body: some View {
            TimelineView(.animation(paused: !isAnimated)) { context in
                let time = isAnimated ? context.date.timeIntervalSinceReferenceDate : 0
                ZStack {
                    Circle()
                        .stroke(lineWidth: 3)
                        .foregroundStyle(.tint)
                        .opacity(0.15)
                    Circle()
                        .trim(from: 0, to: 0.3)
                        .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .foregroundStyle(.tint)
                        .rotationEffect(.degrees(time.truncatingRemainder(dividingBy: 1.2) / 1.2 * 360))
                }
            }
            .frame(width: 116, height: 116)
        }
    }

    var animates: Bool {
        isAnimated && !reduceMotion
    }

    var isFailed: Bool {
        if case .failed = phase { return true }
        return false
    }

    var isSearching: Bool {
        phase == .idle || phase == .searching
    }

    var isSharing: Bool {
        phase == .connected || phase == .sharing
    }

    var headline: String {
        switch phase {
        case .idle, .searching:    return "相手を探しています"
        case .connected, .sharing: return "つながりました"
        case .done:                return "ペアになりました"
        case .failed:              return "つながりませんでした"
        }
    }

    var message: String {
        switch phase {
        case .idle, .searching:    return "相手にも同じ画面を開いてもらい、2台を近づけてください。"
        case .connected, .sharing: return "iCloud で共有しています。2台を近くに置いたままお待ちください。"
        case .done:                return "ふたりの情報を読み込んでいます…"
        case .failed(let message): return message
        }
    }

    var beacon: some View {
        ZStack {
            if isSearching {
                Radar(isAnimated: animates)
                    .transition(.opacity)
            }
            if isSharing {
                Orbit(isAnimated: animates)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
            Image(systemName: beaconSymbol)
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(beaconForeground)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.variableColor.iterative.reversing, options: .repeating, isActive: animates && isSearching)
                .symbolEffect(.pulse, options: .repeating, isActive: animates && isSharing)
                .symbolEffect(.bounce, value: phase == .done)
                .symbolEffect(.wiggle, value: isFailed)
                .frame(width: 96, height: 96)
                .background(beaconBackground, in: .circle)
                .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        }
        .frame(width: 200, height: 200)
        .accessibilityHidden(true)
    }

    var beaconSymbol: String {
        switch phase {
        case .idle, .searching:    return "dot.radiowaves.left.and.right"
        case .connected, .sharing: return "icloud"
        case .done:                return "person.2.fill"
        case .failed:              return "exclamationmark"
        }
    }

    var beaconForeground: AnyShapeStyle {
        phase == .done || isFailed ? AnyShapeStyle(.white) : AnyShapeStyle(.tint)
    }

    var beaconBackground: AnyShapeStyle {
        switch phase {
        case .done:   return AnyShapeStyle(.tint)
        case .failed: return AnyShapeStyle(.red)
        case .idle, .searching, .connected, .sharing:
            return AnyShapeStyle(Color(.secondarySystemGroupedBackground))
        }
    }
}

#Preview("ペアリングの相手待ち") {
    PairingView(phase: .searching, isAnimated: false, onCancel: {})
}

#Preview("ペアリングの共有中") {
    PairingView(phase: .sharing, isAnimated: false, onCancel: {})
}

#Preview("ペアリングの読み込み中") {
    PairingView(phase: .done, isAnimated: false, onCancel: {})
}

#Preview("ペアリングの失敗") {
    PairingView(
        phase: .failed("相手も役割を選んでいます。どちらか一方が「相手の招待を受ける」を選んでください。"),
        isAnimated: false,
        onCancel: {}
    )
}

#Preview("ペアリングの流れ") {
    let flow: [MultipeerPairing.Phase] = [.searching, .connected, .sharing, .done, .failed("相手との接続が切れました")]
    TimelineView(.periodic(from: .now, by: 2.5)) { context in
        PairingView(
            phase: flow[Int(context.date.timeIntervalSinceReferenceDate / 2.5) % flow.count],
            onCancel: {}
        )
    }
    .prefireIgnored()
}
