//
//  PresentingBinding.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/24
//

import SwiftUI

extension Binding where Value == Bool {
    /// `message` がある間は出し、閉じたら `message` を消す。
    init(presenting message: Binding<String?>) {
        self.init(
            get: { message.wrappedValue != nil },
            set: { presented in
                if !presented {
                    message.wrappedValue = nil
                }
            }
        )
    }
}
