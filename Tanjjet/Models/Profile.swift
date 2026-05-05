import Foundation

/// 사용자 프로필 모델
struct Profile: Codable, Identifiable, Equatable {
    let id: UUID
    var nickname: String?
    var coupleId: UUID?
    let createdAt: Date?
    var updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case nickname
        case coupleId = "couple_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    /// 페어링 완료 여부
    var isPaired: Bool {
        coupleId != nil
    }
}

/// 프로필 업데이트 DTO
struct ProfileUpdate: Encodable {
    var nickname: String?
    var coupleId: UUID?
    private var shouldClearCoupleId: Bool
    
    init(nickname: String? = nil, coupleId: UUID? = nil, clearCoupleId: Bool = false) {
        self.nickname = nickname
        self.coupleId = coupleId
        self.shouldClearCoupleId = clearCoupleId
    }
    
    enum CodingKeys: String, CodingKey {
        case nickname
        case coupleId = "couple_id"
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        if let nickname {
            try container.encode(nickname, forKey: .nickname)
        }
        
        if let coupleId {
            try container.encode(coupleId, forKey: .coupleId)
        } else if shouldClearCoupleId {
            try container.encodeNil(forKey: .coupleId)
        }
    }
}

/// 프로필 생성 DTO
struct ProfileInsert: Codable {
    let id: UUID
    var nickname: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case nickname
    }
}
