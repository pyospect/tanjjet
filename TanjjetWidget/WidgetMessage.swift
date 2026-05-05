import Foundation

/// 위젯용 메시지 데이터 (App Group 공유)
/// 메인 앱과 동일한 모델 - 위젯 타겟에서 사용
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
