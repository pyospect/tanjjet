import Foundation
import UserNotifications
import UIKit

/// Push Notification 서비스
final class PushNotificationService: NSObject, ObservableObject {
    static let shared = PushNotificationService()
    
    @Published var deviceToken: String?
    @Published var isAuthorized = false
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    private override init() {
        super.init()
    }
    
    // MARK: - Request Permission
    
    /// 푸시 알림 권한 요청
    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshAuthorizationStatus()
            
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                AppLogger.info("Push notification permission granted")
            } else {
                AppLogger.info("Push notification permission denied")
            }
            
            return granted
        } catch {
            AppLogger.error("Push notification permission error: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 현재 알림 권한 상태 확인
    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let status = settings.authorizationStatus
        let authorized = status == .authorized || status == .provisional || status == .ephemeral
        
        await MainActor.run {
            self.authorizationStatus = status
            self.isAuthorized = authorized
        }
    }
    
    /// 이미 허용된 사용자만 조용히 푸시 토큰 등록
    func registerForRemoteNotificationsIfAuthorized() async {
        await refreshAuthorizationStatus()
        
        guard isAuthorized else {
            return
        }
        
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    // MARK: - Device Token
    
    /// 디바이스 토큰 저장
    func saveDeviceToken(_ token: Data) {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
        
        Task { @MainActor in
            self.deviceToken = tokenString
        }
        
        AppLogger.info("Device token received")
        
        // Supabase에 토큰 저장
        Task {
            await saveTokenToSupabase(tokenString)
        }
    }
    
    /// Supabase에 디바이스 토큰 저장
    private func saveTokenToSupabase(_ token: String) async {
        guard let userId = await SupabaseService.shared.currentUserId else {
            AppLogger.error("Cannot save device token: not authenticated")
            return
        }
        
        do {
            try await SupabaseService.shared.saveDeviceToken(token: token, userId: userId)
            AppLogger.info("Device token saved to Supabase")
        } catch {
            AppLogger.error("Failed to save device token: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Handle Notification
    
    /// 푸시 알림 수신 처리
    func handleNotification(_ userInfo: [AnyHashable: Any]) {
        AppLogger.info("Received notification")
        
        // 위젯 업데이트
        AppGroupManager.shared.reloadWidgetTimelines()
    }
    
    // MARK: - Remove Token
    
    /// 토큰 삭제 (로그아웃 시)
    func removeToken() async {
        guard let userId = await SupabaseService.shared.currentUserId else {
            return
        }
        
        do {
            if let token = deviceToken {
                try await SupabaseService.shared.removeDeviceToken(token: token, userId: userId)
            } else {
                try await SupabaseService.shared.removeAllDeviceTokens(userId: userId)
            }
            
            await MainActor.run {
                self.deviceToken = nil
            }
            
            AppLogger.info("Device token removed")
        } catch {
            AppLogger.error("Failed to remove device token: \(error.localizedDescription)")
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationService: UNUserNotificationCenterDelegate {
    
    /// 포그라운드에서 알림 표시
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
    
    /// 알림 탭 처리
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        handleNotification(response.notification.request.content.userInfo)
        completionHandler()
    }
}
