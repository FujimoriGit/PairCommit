//
//  ContentView.swift
//  PairCommit
//
//  Created by Daiki Fujimori on 2026/06/20
//

import Prefire
import SwiftUI

struct ContentView: View {
    var body: some View {
        // Spike中はペアリング検証画面を表示する。
        PartnershipSpikeView()
    }
}

#Preview {
    ContentView()
        // VRT: 記録環境(Intel)とCI(Apple Silicon)のアンチエイリアス差を吸収する許容値。
        .snapshot(precision: 0.98, perceptualPrecision: 0.98)
}
