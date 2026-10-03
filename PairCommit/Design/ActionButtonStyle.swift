//
//  ActionButtonStyle.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/21
//

import SwiftUI

struct FilledButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        FeedbackButton(configuration: configuration, feedback: .impact)
            .buttonStyle(Appearance())
    }
}

struct SoftButtonStyle: PrimitiveButtonStyle {
    let feedback: SensoryFeedback?

    func makeBody(configuration: Configuration) -> some View {
        FeedbackButton(
            configuration: configuration,
            feedback: feedback ?? (configuration.role == .destructive ? .warning : .impact(weight: .light))
        )
        .buttonStyle(Appearance())
    }
}

extension PrimitiveButtonStyle where Self == FilledButtonStyle {
    static var filled: Self { .init() }
}

extension PrimitiveButtonStyle where Self == SoftButtonStyle {
    static var soft: Self { .init(feedback: nil) }

    static func soft(feedback: SensoryFeedback) -> Self { .init(feedback: feedback) }
}

// MARK: - Private

// 押下状態の変化で鳴らすと、タップを取り消したときやスクロールし始めたときにも鳴る
private struct FeedbackButton: View {
    let configuration: PrimitiveButtonStyleConfiguration
    let feedback: SensoryFeedback

    @State private var actions = 0

    var body: some View {
        Button(role: configuration.role) {
            actions += 1
            configuration.trigger()
        } label: {
            configuration.label
        }
        .sensoryFeedback(feedback, trigger: actions)
    }
}

private extension FilledButtonStyle {
    struct Appearance: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            Surface(configuration: configuration)
        }
    }

    struct Surface: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(isEnabled ? AnyShapeStyle(.white) : AnyShapeStyle(Color.secondary))
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(fill, in: .capsule)
                .opacity(configuration.isPressed ? 0.7 : 1)
        }

        var fill: AnyShapeStyle {
            isEnabled ? AnyShapeStyle(.tint) : AnyShapeStyle(Color(.tertiarySystemFill))
        }
    }
}

private extension SoftButtonStyle {
    struct Appearance: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            Surface(configuration: configuration)
        }
    }

    struct Surface: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(fill)
                .frame(maxWidth: .infinity, minHeight: 42)
                .background(Color(.tertiarySystemFill), in: .capsule)
                .opacity(configuration.isPressed ? 0.7 : 1)
        }

        var fill: AnyShapeStyle {
            guard isEnabled else { return AnyShapeStyle(Color.secondary) }
            return configuration.role == .destructive ? AnyShapeStyle(Color.red) : AnyShapeStyle(.tint)
        }
    }
}
