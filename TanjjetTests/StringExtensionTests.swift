import XCTest
@testable import Tanjjet

final class StringExtensionTests: XCTestCase {
    func testBlankAndTrimmedHelpers() {
        XCTAssertTrue(" \n\t ".isBlank)
        XCTAssertFalse(" 딴젯 ".isBlank)
        XCTAssertEqual(" 딴젯 \n".trimmed, "딴젯")
    }
}
