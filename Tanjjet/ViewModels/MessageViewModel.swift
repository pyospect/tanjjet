import Foundation
import SwiftUI

/// 메시지 뷰모델
@MainActor
final class MessageViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var latestPartnerMessage: Message?
    @Published var partnerNickname: String = "파트너"
    @Published var messageInput: String = ""
    @Published var isLoading = false
    @Published var isSending = false
    @Published var errorMessage: String?
    
    private var couple: Couple?
    private var currentUserId: UUID?
    
    // MARK: - Initialize
    
    /// 초기화 및 데이터 로드
    func initialize() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // 현재 사용자 ID
            currentUserId = await SupabaseService.shared.currentUserId
            
            // 커플 정보 로드
            couple = try await SupabaseService.shared.fetchCurrentCouple()
            
            guard let couple = couple else {
                print("[ERROR] No couple found")
                isLoading = false
                return
            }
            
            // 파트너 닉네임 로드
            if let nickname = try await SupabaseService.shared.fetchPartnerNickname() {
                partnerNickname = nickname
            }
            
            // 메시지 로드
            messages = try await SupabaseService.shared.fetchRecentMessages()
            print("[INFO] Loaded \(messages.count) messages")
            
            // 파트너의 최신 메시지 로드
            latestPartnerMessage = try await SupabaseService.shared.fetchLatestPartnerMessage()
            
            // 위젯 데이터 업데이트
            updateWidgetData()
            
            // Realtime 구독 시작
            await subscribeToMessages(coupleId: couple.id)
            
            print("[INFO] MessageViewModel initialized")
            
        } catch {
            print("[ERROR] Initialize failed: \(error)")
            errorMessage = nil // 에러 메시지 숨김 (첫 메시지 없을 수 있음)
        }
        
        isLoading = false
    }
    
    // MARK: - Send Message
    
    /// 메시지 전송
    func sendMessage() async {
        let content = messageInput.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !content.isEmpty else {
            return
        }
        
        guard content.count <= 100 else {
            errorMessage = "100자 이내로 입력해주세요"
            return
        }
        
        isSending = true
        errorMessage = nil
        
        // 입력 필드 즉시 초기화 (UX 개선)
        let sentContent = content
        messageInput = ""
        
        do {
            let message = try await SupabaseService.shared.sendMessage(content: sentContent)
            
            // 로컬 목록에 추가 (Realtime이 느릴 수 있으므로)
            addMessageIfNotExists(message)
            
            // 위젯 리로드
            AppGroupManager.shared.reloadWidgetTimelines()
            
            print("[INFO] Message sent: \(sentContent)")
            
        } catch {
            print("[ERROR] Send message failed: \(error)")
            errorMessage = "전송 실패. 다시 시도해주세요."
            // 전송 실패 시 입력 복원
            messageInput = sentContent
        }
        
        isSending = false
    }
    
    // MARK: - Realtime
    
    /// Realtime 메시지 구독
    private func subscribeToMessages(coupleId: UUID) async {
        RealtimeService.shared.onNewMessage = { [weak self] message in
            Task { @MainActor in
                self?.handleNewMessage(message)
            }
        }
        
        await RealtimeService.shared.subscribeToMessages(coupleId: coupleId)
    }
    
    /// 새 메시지 처리 (Realtime)
    private func handleNewMessage(_ message: Message) {
        print("[INFO] Handling new message: \(message.id)")
        
        // 중복 방지하며 추가
        addMessageIfNotExists(message)
        
        // 파트너 메시지인 경우 최신 메시지 업데이트
        if let currentUserId = currentUserId, message.senderId != currentUserId {
            latestPartnerMessage = message
            updateWidgetData()
        }
    }
    
    /// 메시지 추가 (중복 방지)
    private func addMessageIfNotExists(_ message: Message) {
        if !messages.contains(where: { $0.id == message.id }) {
            // 최신 메시지가 맨 앞에 오도록 (역순 정렬)
            messages.insert(message, at: 0)
            print("[INFO] Message added to list: \(message.id)")
        } else {
            print("[INFO] Message already exists: \(message.id)")
        }
    }
    
    // MARK: - Widget
    
    /// 위젯 데이터 업데이트
    private func updateWidgetData() {
        if let message = latestPartnerMessage {
            let widgetMessage = WidgetMessage(
                content: message.content,
                senderNickname: partnerNickname,
                timestamp: message.createdAt ?? Date()
            )
            AppGroupManager.shared.saveWidgetMessage(widgetMessage)
        }
    }
    
    // MARK: - Refresh
    
    /// 데이터 새로고침
    func refresh() async {
        do {
            messages = try await SupabaseService.shared.fetchRecentMessages()
            latestPartnerMessage = try await SupabaseService.shared.fetchLatestPartnerMessage()
            updateWidgetData()
            print("[INFO] Messages refreshed: \(messages.count) messages")
        } catch {
            print("[ERROR] Refresh failed: \(error)")
        }
    }
    
    // MARK: - Cleanup
    
    /// 정리
    func cleanup() async {
        await RealtimeService.shared.unsubscribe()
    }
}
