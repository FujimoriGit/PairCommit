//
//  ActionButtonStyle.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/21
//

import SwiftUI

struct FilledButtonStyle: PrimitiveButtonStyle {
    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        let button = FeedbackButton(configuration: configuration, feedback: .impact)
            .font(.system(.headline, design: .rounded))
        if #available(iOS 26, *) {
            button
                .buttonStyle(.glassProminent)
                .controlSize(.large)
        } else {
            button.buttonStyle(Appearance())
        }
    }
}

struct SoftButtonStyle: PrimitiveButtonStyle {
    let feedback: SensoryFeedback?

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        let button = FeedbackButton(
            configuration: configuration,
            feedback: feedback ?? (configuration.role == .destructive ? .warning : .impact(weight: .light))
        )
        .font(.system(.subheadline, design: .rounded, weight: .semibold))
        if #available(iOS 26, *) {
            button
                .foregroundStyle(Self.ink(for: configuration.role))
                .buttonStyle(.glass)
        } else {
            button.buttonStyle(Appearance())
        }
    }
}

struct ChoiceButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        FeedbackButton(configuration: configuration, feedback: .impact(weight: .light))
            .buttonStyle(.plain)
    }
}

extension PrimitiveButtonStyle where Self == FilledButtonStyle {
    static var filled: Self { .init() }
}

extension PrimitiveButtonStyle where Self == SoftButtonStyle {
    static var soft: Self { .init(feedback: nil) }

    static func soft(feedback: SensoryFeedback) -> Self { .init(feedback: feedback) }
}

extension PrimitiveButtonStyle where Self == ChoiceButtonStyle {
    static var choice: Self { .init() }
}

extension View {
    // ツールバーの項目はボタンのスタイルを差し替えると見た目が変わるので、スタイルではなくタップのジェスチャーで鳴らす
    func tapFeedback() -> some View {
        modifier(TapFeedback())
    }
}

// MARK: - Private

// 押下状態の変化で鳴らすと、タップを取り消したときやスクロールし始めたときにも鳴る
private struct FeedbackButton: View {
    let configuration: PrimitiveButtonStyleConfiguration
    let feedback: SensoryFeedback

    @Environment(\.playingFeedback) private var playingFeedback

    var body: some View {
        Button(role: configuration.role) {
            playingFeedback?(feedback)
            configuration.trigger()
        } label: {
            configuration.label
                .frame(maxWidth: .infinity)
        }
    }
}

private struct TapFeedback: ViewModifier {
    @Environment(\.playingFeedback) private var playingFeedback

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(TapGesture().onEnded { playingFeedback?(.impact(weight: .light)) })
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
    static func ink(for role: ButtonRole?) -> AnyShapeStyle {
        role == .destructive ? AnyShapeStyle(Color.red) : AnyShapeStyle(.tint)
    }

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
                .foregroundStyle(fill)
                .frame(maxWidth: .infinity, minHeight: 42)
                .background(Color(.tertiarySystemFill), in: .capsule)
                .opacity(configuration.isPressed ? 0.7 : 1)
        }

        var fill: AnyShapeStyle {
            isEnabled ? SoftButtonStyle.ink(for: configuration.role) : AnyShapeStyle(Color.secondary)
        }
    }
}
