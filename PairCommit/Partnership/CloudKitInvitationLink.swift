//
//  CloudKitInvitationLink.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/27
//

import CloudKit

struct CloudKitInvitationLink: InvitationLink {
    let metadata: CKShare.Metadata

    func join() async throws -> RemoteRecordID {
        try await PartnershipShare.accept(metadata)
        guard let invitationID = metadata.hierarchicalRootRecordID else {
            throw PartnershipShareError.metadataMissing
        }
        return .init(invitationID)
    }
}
