//
//  LinkPresentationPreviews.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/11/08
//

import Domain
import ImageIO
import LinkPresentation
import UIKit
import UniformTypeIdentifiers

public struct LinkPresentationPreviews: LinkPreviewing {
    public init() {}

    public func preview(of url: URL) async throws(LinkPreviewFailure) -> LinkPreview {
        let metadata: LPLinkMetadata
        do {
            // 1つの LPMetadataProvider で2回以上読み込むとエラーになる。
            metadata = try await LPMetadataProvider().startFetchingMetadata(for: url)
        } catch {
            throw .failed
        }
        guard let title = metadata.title, !title.isEmpty else { throw .failed }
        return .init(title: title, image: await Self.thumbnail(from: metadata.imageProvider))
    }
}

// MARK: - Private

private extension LinkPresentationPreviews {
    static let thumbnailMaxPixelSize = 900

    static func thumbnail(from provider: NSItemProvider?) async -> Data? {
        guard let provider, provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) else { return nil }
        let data: Data? = await withCheckedContinuation { continuation in
            _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                continuation.resume(returning: data)
            }
        }
        guard let data, let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: thumbnailMaxPixelSize
        ] as CFDictionary
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        return UIImage(cgImage: image).jpegData(compressionQuality: 0.8)
    }
}
