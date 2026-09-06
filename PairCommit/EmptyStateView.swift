//
//  EmptyStateView.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/06
//

import SwiftUI

struct EmptyStateView: View {
    let title: LocalizedStringKey
    let systemImage: String
    let description: Text

    // ContentUnavailableView を NavigationStack の直下に置くと、ナビゲーションタイトルは出るのに
    // ツールバー項目が描画されない。直下は List にして、空状態はその上に重ねる。
    var body: some View {
        List {}
            .overlay {
                ContentUnavailableView(title, systemImage: systemImage, description: description)
            }
    }
}
