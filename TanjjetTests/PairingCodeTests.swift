import XCTest
@testable import Tanjjet

final class PairingCodeTests: XCTestCase {
    func testGeneratedPairingCodeUsesSixSafeCharacters() {
        let allowedCharacters = CharacterSet(charactersIn: "ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

        for _ in 0..<100 {
            let code = SupabaseService.shared.generatePairingCode()

            XCTAssertEqual(code.count, 6)
            XCTAssertNil(code.rangeOfCharacter(from: allowedCharacters.inverted))
        }
    }
}
