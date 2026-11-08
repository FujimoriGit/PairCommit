//
//  LinkPreviewing.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/11/08
//

import Foundation

public protocol LinkPreviewing: Sendable {
    /// リンク先のページのタイトルと画像を読み込む。
    func preview(of url: URL) async throws(LinkPreviewFailure) -> LinkPreview
}

public struct LinkPreview: Equatable, Sendable {
    public let title: String
    /// 画像のファイルの中身。ページに画像が無ければ nil。
    public let image: Data?

    public init(title: String, image: Data?) {
        self.title = title
        self.image = image
    }
}

public enum LinkPreviewFailure: Error, Equatable, Sendable {
    case failed
}
