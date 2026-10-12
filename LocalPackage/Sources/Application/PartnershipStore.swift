//
//  PartnershipStore.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/07/04
//

import Domain
import Foundation
import Observation

@MainActor
@Observable
public final class PartnershipStore {
    public private(set) var state: PartnershipState
    public let role: Role
    /// `send(_:)` で反映した変更を、保存できずに元へ戻したときの失敗。
    public private(set) var saveFailure: SyncFailure?

    private let synchronizer: any PartnershipSyncing
    private var pending: Task<Void, Never>?

    public init(role: Role, synchronizer: any PartnershipSyncing, state: PartnershipState) {
        self.role = role
        self.synchronizer = synchronizer
        self.state = state
    }

    /// 共有から同期を始め、ペアでの役割を決める。共有にまだペアが入っていないか、もう終わっていれば nil。
    public convenience init?(starting share: any PairedShare) async throws(SyncFailure) {
        let synchronizer = share.synchronizer()
        let state = try await synchronizer.start()
        guard let ownerRole = state.pairing?.ownerRole else { return nil }
        let agreement = PairingAgreement(ownerRole: ownerRole, isOwner: share.isOwner)
        self.init(role: agreement.role, synchronizer: synchronizer, state: state)
    }

    public func refresh() async throws(SyncFailure) {
        let failure = await serialized { [self] () -> SyncFailure? in
            do throws(SyncFailure) {
                state = try await synchronizer.load()
                return nil
            } catch {
                return error
            }
        }
        if let failure {
            throw failure
        }
    }

    public func perform<Rejection: Error>(
        _ transform: @escaping @Sendable (PartnershipState, Role) throws(Rejection) -> PartnershipState
    ) async throws(PartnershipFailure<Rejection>) {
        let failure = await serialized { [self] in
            await apply(transform, to: state, remaining: Self.attempts)
        }
        if let failure {
            throw failure
        }
    }

    /// `perform(_:)` と同じく保存を待たずに反映するが、失敗は投げずに `saveFailure` に残す。
    /// 反映した画面が保存の前に消える操作に使う。
    /// - Returns: 保存できたかどうか。
    @discardableResult
    public func send<Rejection: Error>(
        _ transform: @escaping @Sendable (PartnershipState, Role) throws(Rejection) -> PartnershipState
    ) async -> Bool {
        do throws(PartnershipFailure<Rejection>) {
            try await perform(transform)
            return true
        } catch {
            switch error {
            // 押せる状態で押した操作が成り立たないのは、押したあとに相手の変更が届いたとき。
            case .rejected: saveFailure = .outdated(latest: state)
            case .notSynchronized(let failure): saveFailure = failure
            }
            return false
        }
    }

    public func dismissSaveFailure() {
        saveFailure = nil
    }
}

// MARK: - Private

private extension PartnershipStore {
    static let attempts = 3

    func apply<Rejection: Error>(
        _ transform: @Sendable (PartnershipState, Role) throws(Rejection) -> PartnershipState,
        to base: PartnershipState,
        remaining: Int
    ) async -> PartnershipFailure<Rejection>? {
        let next: PartnershipState
        do throws(Rejection) {
            next = try transform(base, role)
        } catch {
            state = base
            return .rejected(error)
        }
        state = next
        do throws(SyncFailure) {
            try await synchronizer.save(next, replacing: base)
            return nil
        } catch {
            switch error {
            case .outdated(let latest) where remaining > 1:
                return await apply(transform, to: latest, remaining: remaining - 1)
            case .outdated(let latest):
                state = latest
            case .unavailable:
                state = base
            }
            return .notSynchronized(error)
        }
    }

    // 保存と取り直しを1件ずつ流す。重ねると、サーバーに着く順とローカルの順が食い違う。
    func serialized<T: Sendable>(_ body: @escaping @MainActor () async -> T) async -> T {
        let queued = pending
        let turn = Task { @MainActor in
            await queued?.value
            return await body()
        }
        pending = Task { _ = await turn.value }
        return await turn.value
    }
}
