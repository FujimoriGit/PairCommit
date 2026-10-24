//
//  PendingDiagnostics.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/10/24
//

/// 前に起動していた間に送れなかった記録を送る。
public enum PendingDiagnostics {
    public static func send() async {
        await DiagnosticOutbox.shared.send()
    }
}
