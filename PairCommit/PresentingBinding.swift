//
//  PresentingBinding.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/24
//

import SwiftUI

extension Binding where Value == Bool {
    /// `value` がある間は出し、閉じたら `value` を消す。
    init<Wrapped: Sendable>(presenting value: Binding<Wrapped?>) {
        self.init(
            get: { value.wrappedValue != nil },
            set: { presented in
                if !presented {
                    value.wrappedValue = nil
                }
            }
        )
    }
}
