//
//  Marker.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/21
//

import SwiftUI

extension View {
    func marker(_ tint: Color) -> some View {
        font(.caption2.weight(.bold))
            .foregroundStyle(tint)
    }
}
