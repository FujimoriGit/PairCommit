//
//  ActionButtonStyle.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/21
//

import SwiftUI

struct FilledButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Surface(configuration: configuration)
    }
}

struct SoftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Surface(configuration: configuration)
    }
}

extension ButtonStyle where Self == FilledButtonStyle {
    static var filled: Self { .init() }
}

extension ButtonStyle where Self == SoftButtonStyle {
    static var soft: Self { .init() }
}

// MARK: - Private

private extension FilledButtonStyle {
    struct Surface: View {
        let configuration: Configuration
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
    struct Surface: View {
        let configuration: Configuration
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
