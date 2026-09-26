//
//  PairCommitUITestsLaunchTests.swift
//  PairCommitUITests
//
//  Created by Daiki Fujimori on 2026/06/20
//

import XCTest

final class PairCommitUITestsLaunchTests: XCTestCase {

    override static var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
