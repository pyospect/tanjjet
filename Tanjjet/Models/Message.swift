import Foundation

/// 메시지 모델
struct Message: Codable, Identifiable, Equatable {
    let id: UUID
    let coupleId: UUID
    let senderId: UUID
    let content: String
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case coupleId = "couple_id"
        case senderId = "sender_id"
        case content
        case createdAt = "created_at"
    }
}

/// 메시지 생성 DTO
struct MessageInsert: Codable {
    let coupleId: UUID
    let senderId: UUID
    let content: String
    
    enum CodingKeys: String, CodingKey {
        case coupleId = "couple_id"
        case senderId = "sender_id"
        case content
    }
}

/// 위젯용 메시지 데이터 (App Group 공유)
struct WidgetMessage: Codable {
    let content: String
    let senderNickname: String
    let timestamp: Date
    
    static let empty = WidgetMessage(
        content: "아직 메시지가 없어요",
        senderNickname: "",
        timestamp: Date()
    )
}
