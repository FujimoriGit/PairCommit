//
//  PartnershipTabs.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/10
//

import Application
import Domain
import SwiftUI

struct PartnershipTabs: View {
    let store: PartnershipStore
    let makeCriteriaReviewing: () -> (any CriteriaReviewing)?

    @State private var destination = Destination.home
    @State private var refreshFailure: String?
    @State private var isNaming = false

    var body: some View {
        TabView(selection: $destination) {
            Tab(String(localized: .tabHome), systemImage: "house", value: .home) {
                home
                    .refreshable { await refresh() }
                    .simultaneousGesture(tabSwipe)
            }
            Tab(String(localized: .commonHistory), systemImage: "clock.arrow.circlepath", value: .history) {
                NavigationStack {
                    PartnershipHistoryView(state: store.state, role: store.role)
                        .refreshable { await refresh() }
                        .simultaneousGesture(tabSwipe)
                }
            }
            Tab(String(localized: .commonSettings), systemImage: "gearshape", value: .settings) {
                NavigationStack {
                    PartnershipSettingsView(store: store)
                        .simultaneousGesture(tabSwipe)
                }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: destination)
        .alert(.rootRefreshFailed, isPresented: Binding(presenting: $refreshFailure)) {
            Button(.commonOk) {}
        } message: {
            Text(refreshFailure ?? "")
        }
        // 保存の結果を待たずに名前の入った状態へ切り替わるので、それで閉じると、
        // 保存に失敗して元に戻ったときに入力し直しの画面が開き直し、失敗を伝えられない
        .fullScreenCover(isPresented: $isNaming) {
            NamingScreen(store: store)
        }
        .onChange(of: isNamingRequired, initial: true) { _, isRequired in
            if isRequired {
                isNaming = true
            }
        }
    }
}

// MARK: - Private

private extension PartnershipTabs {
    enum Destination: CaseIterable {
        case home
        case history
        case settings
    }

    @ViewBuilder
    var home: some View {
        switch (store.role, store.state.activeVision) {
        case (.manager, .none): ManagerVisionView(store: store)
        case (.manager, .some(let vision)):
            TimelineView(.everyMinute) { context in
                ManagerTaskView(store: store, vision: vision, now: context.date)
            }
        case (.player, .none):
            TimelineView(.everyMinute) { context in
                PlayerVisionView(store: store, reviewing: makeCriteriaReviewing(), now: context.date)
            }
        case (.player, .some(let vision)):
            TimelineView(.everyMinute) { context in
                PlayerTaskView(store: store, vision: vision, now: context.date)
            }
        }
    }

    var tabSwipe: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                let distance = value.translation.width
                guard abs(distance) > 80, abs(distance) > abs(value.translation.height) * 2 else { return }
                let destinations = Destination.allCases
                guard let index = destinations.firstIndex(of: destination) else { return }
                let next = index + (distance < 0 ? 1 : -1)
                guard destinations.indices.contains(next) else { return }
                withAnimation { destination = destinations[next] }
            }
    }

    // ペアが終わったときは最初の画面へ戻るので、入力を求めない
    var isNamingRequired: Bool {
        guard let pairing = store.state.pairing else { return false }
        return pairing.name(of: store.role) == nil
    }

    func refresh() async {
        do throws(SyncFailure) {
            try await store.refresh()
        } catch {
            refreshFailure = error.message
        }
    }
}

#Preview("ペアのタブ") {
    PartnershipTabs(store: .preview(role: .manager, visions: []), makeCriteriaReviewing: { nil })
}
