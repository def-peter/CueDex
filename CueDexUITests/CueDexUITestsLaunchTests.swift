//
//  CueDexUITestsLaunchTests.swift
//  CueDexUITests
//
//  Created by code_peter on 2026/8/18.
//

import XCTest

final class CueDexUITestsLaunchTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchEnvironment["CUEDEX_DISABLE_RUNTIME_SERVICES"] = "1"
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
