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
    
    func testGeneratedNonceUsesRequestedLengthAndSafeCharacters() throws {
        let allowedCharacters = CharacterSet(charactersIn: "0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        
        let nonce = try SupabaseService.shared.generateNonce(length: 64)
        
        XCTAssertEqual(nonce.count, 64)
        XCTAssertNil(nonce.rangeOfCharacter(from: allowedCharacters.inverted))
    }
    
    func testGeneratedNonceRejectsInvalidLength() {
        XCTAssertThrowsError(try SupabaseService.shared.generateNonce(length: 0))
    }
}
