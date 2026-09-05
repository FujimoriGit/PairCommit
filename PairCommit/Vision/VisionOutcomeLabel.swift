//
//  VisionOutcomeLabel.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/08/22
//

import Domain

extension Vision.Outcome {
    var label: String {
        switch self {
        case .achieved: "達成した"
        case .abandoned: "取りやめる"
        }
    }

    var result: String {
        switch self {
        case .achieved: "達成"
        case .abandoned: "取りやめ"
        }
    }

    var confirmation: String {
        switch self {
        case .achieved: "達成にする"
        case .abandoned: "取りやめにする"
        }
    }
}
