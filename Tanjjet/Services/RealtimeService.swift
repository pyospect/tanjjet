import Foundation
import Supabase
import Realtime

/// Supabase Realtime 구독 관리
@MainActor
final class RealtimeService: ObservableObject {
    static let shared = RealtimeService()
    
    private var channel: RealtimeChannelV2?
    private var isSubscribed = false
    
    /// 새 메시지 수신 콜백
    var onNewMessage: ((Message) -> Void)?
    
    private init() {}
    
    // MARK: - Subscribe
    
    /// 메시지 테이블 실시간 구독
    func subscribeToMessages(coupleId: UUID) async {
        // 이미 구독 중이면 무시
        guard !isSubscribed else {
            print("[INFO] Already subscribed")
            return
        }
        
        // 기존 구독 해제
        await unsubscribe()
        
        let client = SupabaseService.shared.client
        
        // 채널 생성
        let channel = client.realtimeV2.channel("messages-\(coupleId.uuidString)")
        
        // Postgres Changes 구독 (새로운 filter 구문)
        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "messages",
            filter: "couple_id=eq.\(coupleId.uuidString)"
        )
        
        // 구독 시작
        await channel.subscribe()
        
        self.channel = channel
        self.isSubscribed = true
        
        print("[INFO] Subscribed to messages for couple: \(coupleId)")
        
        // 변경사항 리스닝
        Task { [weak self] in
            for await change in changes {
                await self?.handleChange(change)
            }
        }
    }
    
    /// 변경사항 처리
    private func handleChange(_ action: AnyAction) async {
        print("[INFO] Realtime change received: \(action)")
        
        switch action {
        case .insert(let insertAction):
            await handleInsert(insertAction)
        default:
            break
        }
    }
    
    /// INSERT 처리
    private func handleInsert(_ action: InsertAction) async {
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                
                if let date = formatter.date(from: dateString) {
                    return date
                }
                
                formatter.formatOptions = [.withInternetDateTime]
                if let date = formatter.date(from: dateString) {
                    return date
                }
                
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Cannot decode date: \(dateString)"
                )
            }
            
            let message = try action.decodeRecord(as: Message.self, decoder: decoder)
            
            print("[INFO] New message received via Realtime: \(message.content)")
            
            // 위젯 업데이트 (파트너 메시지인 경우)
            if let currentUserId = await SupabaseService.shared.currentUserId,
               message.senderId != currentUserId {
                let partnerNickname = try? await SupabaseService.shared.fetchPartnerNickname()
                let widgetMessage = WidgetMessage(
                    content: message.content,
                    senderNickname: partnerNickname ?? "파트너",
                    timestamp: message.createdAt ?? Date()
                )
                AppGroupManager.shared.saveWidgetMessage(widgetMessage)
            }
            
            // 콜백 호출 (모든 메시지)
            onNewMessage?(message)
            
        } catch {
            print("[ERROR] Failed to decode message: \(error)")
        }
    }
    
    // MARK: - Unsubscribe
    
    /// 구독 해제
    func unsubscribe() async {
        if let channel = channel {
            await channel.unsubscribe()
            self.channel = nil
            self.isSubscribed = false
            print("[INFO] Unsubscribed from messages")
        }
    }
}
