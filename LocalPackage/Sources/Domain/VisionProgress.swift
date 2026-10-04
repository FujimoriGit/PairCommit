//
//  VisionProgress.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/04
//

import Foundation

extension Vision {
    public struct Progress: Equatable, Sendable {
        public let approved: Int
        public let total: Int

        public init(approved: Int, total: Int) {
            self.approved = approved
            self.total = total
        }

        /// タスクが1つも無ければ nil。
        public var fraction: Double? {
            total > 0 ? Double(approved) / Double(total) : nil
        }
    }
}

extension PartnershipState {
    /// 採用前の起案と、取り消したタスクは数えない。
    public func progress(of visionID: Vision.ID) -> Vision.Progress {
        let counted = tasks(for: visionID).filter { $0.status != .proposed && $0.status != .cancelled }
        return .init(approved: counted.filter { $0.status == .approved }.count, total: counted.count)
    }
}
