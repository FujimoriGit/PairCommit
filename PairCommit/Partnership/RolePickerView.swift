//
//  RolePickerView.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/09/27
//

import Domain
import SwiftUI

struct RolePickerView: View {
    let failureMessage: String?
    let onNearby: (Role) -> Void
    let onRemote: (Role) -> Void
    let onAcceptInvitation: () -> Void

    @State private var methodRole: Role?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(Role.allCases, id: \.self) { role in
                        Button {
                            methodRole = role
                        } label: {
                            roleCard(role)
                        }
                        .buttonStyle(.plain)
                    }

                    Text("役割は途中で入れ替えられません。入れ替えるには、ペアリングをやり直します。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Panel {
                        Button("相手の招待を受ける", action: onAcceptInvitation)
                            .buttonStyle(.filled)
                        Text("相手が選ばなかったほうの役割になります。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    FailureNote(message: failureMessage)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 36)
            }
            .background(Backdrop())
            .navigationTitle("どちらで使いますか")
            .navigationDestination(item: $methodRole) { role in
                PairingMethodView(
                    role: role,
                    onNearby: { onNearby(role) },
                    onRemote: { onRemote(role) }
                )
            }
        }
    }
}

// MARK: - Private

private extension RolePickerView {
    func roleCard(_ role: Role) -> some View {
        ChoiceCard(symbol: role.symbol, title: role.label, summary: role.summary, accent: role.accent)
    }
}

#Preview("役割の選択") {
    RolePickerView(failureMessage: nil, onNearby: { _ in }, onRemote: { _ in }, onAcceptInvitation: {})
}
