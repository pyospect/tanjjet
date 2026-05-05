import Foundation

/// 커플 연결 모델
struct Couple: Codable, Identifiable, Equatable {
    let id: UUID
    let code: String
    let user1Id: UUID
    var user2Id: UUID?
    let createdAt: Date?
    var updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case code
        case user1Id = "user1_id"
        case user2Id = "user2_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    /// 페어링 완료 여부
    var isComplete: Bool {
        user2Id != nil
    }
    
    /// 파트너 ID 반환
    func partnerId(for userId: UUID) -> UUID? {
        if user1Id == userId {
            return user2Id
        } else if user2Id == userId {
            return user1Id
        }
        return nil
    }
}

/// 커플 생성 DTO
struct CoupleInsert: Codable {
    let code: String
    let user1Id: UUID
    
    enum CodingKeys: String, CodingKey {
        case code
        case user1Id = "user1_id"
    }
}
