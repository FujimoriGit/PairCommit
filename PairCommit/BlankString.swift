//
//  BlankString.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/24
//

import Foundation

extension String {
    var isBlank: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}
