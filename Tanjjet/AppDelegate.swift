import UIKit
import UserNotifications

/// AppDelegate for Push Notifications
class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Push Notification delegate 설정
        UNUserNotificationCenter.current().delegate = PushNotificationService.shared
        return true
    }
    
    /// 디바이스 토큰 수신 성공
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        PushNotificationService.shared.saveDeviceToken(deviceToken)
    }
    
    /// 디바이스 토큰 수신 실패
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        AppLogger.error("Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
}
