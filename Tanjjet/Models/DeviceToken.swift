import Foundation

/// 디바이스 토큰 모델
struct DeviceToken: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let token: String
    let platform: String
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case token
        case platform
        case createdAt = "created_at"
    }
}

/// 디바이스 토큰 생성 DTO
struct DeviceTokenInsert: Codable {
    let userId: UUID
    let token: String
    let platform: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case token
        case platform
    }
}
