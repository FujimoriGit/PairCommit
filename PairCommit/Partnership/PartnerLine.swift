//
//  PartnerLine.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/10
//

import Domain
import SwiftUI

struct PartnerLine: View {
    let pairing: Pairing?
    let role: Role

    var body: some View {
        Text(text)
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Private

private extension PartnerLine {
    var text: String {
        switch (role, pairing?.name(of: role.counterpart)) {
        case (.manager, let name?): String(localized: .partnerLineWitnessing(name))
        case (.manager, nil): String(localized: .partnerLineWitnessingUnnamed)
        case (.player, let name?): String(localized: .partnerLineWitnessed(name))
        case (.player, nil): String(localized: .partnerLineWitnessedUnnamed)
        }
    }
}
