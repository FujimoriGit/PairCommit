//
//  PairCommitUITests.swift
//  PairCommitUITests
//
//  Created by Daiki Fujimori on 2026/06/20
//

import XCTest

final class PairCommitUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testExample() throws {
        let app = XCUIApplication()
        app.launch()
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
