import XCTest
@testable import Tanjjet

final class EncodingTests: XCTestCase {
    func testMessageInsertEncodesSnakeCaseKeys() throws {
        let insert = MessageInsert(
            coupleId: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            senderId: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            content: "밥 먹었어?"
        )

        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(insert))
        let json = try XCTUnwrap(object as? [String: Any])

        XCTAssertEqual(json["couple_id"] as? String, "11111111-1111-1111-1111-111111111111")
        XCTAssertEqual(json["sender_id"] as? String, "22222222-2222-2222-2222-222222222222")
        XCTAssertEqual(json["content"] as? String, "밥 먹었어?")
    }

    func testProfileUpdateCanClearCoupleId() throws {
        let update = ProfileUpdate(clearCoupleId: true)
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(update))
        let json = try XCTUnwrap(object as? [String: Any])

        XCTAssertTrue(json.keys.contains("couple_id"))
        XCTAssertTrue(json["couple_id"] is NSNull)
    }
}
