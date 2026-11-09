//
//  LinkPreviewCard.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/11/08
//

import Domain
import SwiftUI
import UIKit

struct LinkPreviewCard: View {
    let url: URL
    let preview: LinkPreview

    var body: some View {
        Link(destination: url) {
            VStack(alignment: .leading, spacing: 0) {
                if let image = preview.image.flatMap(UIImage.init(data:)) {
                    Color.clear
                        .aspectRatio(1.91, contentMode: .fit)
                        .overlay {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        }
                        .clipped()
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(preview.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if let host = url.host() {
                        Text(host)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 13)
                .padding(.top, 9)
                .padding(.bottom, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color(.separator), lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview("画像つきのリンクプレビュー") {
    LinkPreviewCard(url: URL(string: "https://example.com/running-plan") ?? .homeDirectory, preview: .preview)
        .padding(.leading, 20)
        .padding(.trailing, 76)
        .frame(maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
}

#Preview("画像のないリンクプレビュー") {
    LinkPreviewCard(url: URL(string: "https://example.com/running-plan") ?? .homeDirectory, preview: .previewWithoutImage)
        .padding(.leading, 20)
        .padding(.trailing, 76)
        .frame(maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
}
