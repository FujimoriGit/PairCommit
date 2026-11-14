//
//  SelectableText.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/11/08
//

import SwiftUI
import UIKit

// SwiftUI の Text は、iOS 26 以前では長押しのメニューが文全体にしか効かず、範囲を選べない。
/// 一部の範囲を選んでコピーできる文。文中の URL とメールアドレスはタップで開く。
struct SelectableText: UIViewRepresentable {
    let text: String
    let font: UIFont.TextStyle
    let color: Color
    let linkColor: Color

    func makeCoordinator() -> Coordinator {
        .init()
    }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.isEditable = false
        view.isSelectable = true
        view.isScrollEnabled = false
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        let next = appearance(in: context.environment)
        // UITextView は attributedText を代入されると、中身が同じでも選択を解除する。
        guard context.coordinator.shown != next else { return }
        view.attributedText = attributedText(sized: next.size)
        view.linkTextAttributes = [
            .foregroundColor: UIColor(linkColor),
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        context.coordinator.shown = next
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let limit = proposal.width ?? .greatestFiniteMagnitude
        let used = attributedText(sized: context.environment.dynamicTypeSize).boundingRect(
            with: CGSize(width: limit, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        let width = min(ceil(used.width), limit)
        return CGSize(width: width, height: uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height)
    }
}

extension SelectableText {
    struct Appearance: Equatable {
        let text: String
        let font: UIFont.TextStyle
        let color: Color
        let linkColor: Color
        let size: DynamicTypeSize
        let scheme: ColorScheme
    }

    @MainActor
    final class Coordinator {
        var shown: Appearance?
    }
}

// MARK: - Private

private extension SelectableText {
    func appearance(in environment: EnvironmentValues) -> Appearance {
        .init(
            text: text,
            font: font,
            color: color,
            linkColor: linkColor,
            size: environment.dynamicTypeSize,
            scheme: environment.colorScheme
        )
    }

    func attributedText(sized size: DynamicTypeSize) -> NSAttributedString {
        let base = UIFont.preferredFont(
            forTextStyle: font,
            compatibleWith: UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(size))
        )
        // SwiftUI の Text は行の高さを欧文のフォントで決める。UIKit は何もしないと、和文のフォントの高い行で描く。
        let lines = NSMutableParagraphStyle()
        lines.minimumLineHeight = base.lineHeight
        lines.maximumLineHeight = base.lineHeight
        let linked = NSMutableAttributedString(AttributedString(linkingURLsIn: text))
        linked.addAttributes(
            [
                .font: base,
                .foregroundColor: UIColor(color),
                .paragraphStyle: lines
            ],
            range: NSRange(location: 0, length: linked.length)
        )
        return linked
    }
}
