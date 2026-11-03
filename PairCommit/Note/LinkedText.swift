//
//  LinkedText.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/11/03
//

import Foundation

extension AttributedString {
    /// 文中の URL とメールアドレスを、タップで開けるリンクにする。
    init(linkingURLsIn text: String) {
        self.init(text)
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return }
        for match in detector.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let url = match.url,
                  let range = Range(match.range, in: text),
                  let linkRange = Range(range, in: self) else { continue }
            self[linkRange].link = url
            self[linkRange].underlineStyle = .single
        }
    }
}
