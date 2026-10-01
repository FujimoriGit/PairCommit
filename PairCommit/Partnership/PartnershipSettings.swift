//
//  PartnershipSettings.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/27
//

import Domain
import SwiftUI

extension EnvironmentValues {
    @Entry var resettingPartnership: (@Sendable () async -> String?)?
}

extension View {
    func partnershipSettingsLink() -> some View {
        modifier(PartnershipSettingsLink())
    }

    func partnershipSettingsDestination(role: Role) -> some View {
        navigationDestination(for: PartnershipSettingsRoute.self) { _ in
            PartnershipSettingsView(role: role)
        }
    }
}

// MARK: - Private

private struct PartnershipSettingsRoute: Hashable {}

private struct PartnershipSettingsLink: ViewModifier {
    @Environment(\.resettingPartnership) private var reset

    func body(content: Content) -> some View {
        content
            .toolbar {
                if reset != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        NavigationLink(value: PartnershipSettingsRoute()) {
                            Label("設定", systemImage: "gearshape")
                        }
                    }
                }
            }
    }
}
