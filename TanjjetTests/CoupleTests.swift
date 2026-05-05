import XCTest
@testable import Tanjjet

final class CoupleTests: XCTestCase {
    func testPartnerIdReturnsTheOtherUser() {
        let user1Id = UUID()
        let user2Id = UUID()
        let couple = Couple(
            id: UUID(),
            code: "ABC123",
            user1Id: user1Id,
            user2Id: user2Id,
            createdAt: nil,
            updatedAt: nil
        )

        XCTAssertEqual(couple.partnerId(for: user1Id), user2Id)
        XCTAssertEqual(couple.partnerId(for: user2Id), user1Id)
    }

    func testPartnerIdIsNilForUnknownOrIncompleteCouple() {
        let user1Id = UUID()
        let couple = Couple(
            id: UUID(),
            code: "ABC123",
            user1Id: user1Id,
            user2Id: nil,
            createdAt: nil,
            updatedAt: nil
        )

        XCTAssertNil(couple.partnerId(for: user1Id))
        XCTAssertNil(couple.partnerId(for: UUID()))
        XCTAssertFalse(couple.isComplete)
    }
}
