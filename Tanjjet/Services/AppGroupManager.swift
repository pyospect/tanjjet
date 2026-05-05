import Foundation
import WidgetKit

/// App Group을 통한 앱-위젯 데이터 공유 관리
final class AppGroupManager {
    static let shared = AppGroupManager()
    
    private let appGroupID = "group.com.pyospect.tanjjet"
    
    private let widgetMessageKey = "widget_message"
    private let lastSyncKey = "last_sync_timestamp"
    
    private var userDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }
    
    private init() {}
    
    // MARK: - Widget Message
    
    /// 위젯에 표시할 메시지 저장
    func saveWidgetMessage(_ message: WidgetMessage) {
        guard let defaults = userDefaults else {
            print("[ERROR] App Group UserDefaults not available")
            return
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(message)
            defaults.set(data, forKey: widgetMessageKey)
            defaults.set(Date().timeIntervalSince1970, forKey: lastSyncKey)
            defaults.synchronize()
            
            print("[INFO] Widget message saved: \(message.content)")
            
            // 위젯 타임라인 리로드
            reloadWidgetTimelines()
        } catch {
            print("[ERROR] Failed to encode widget message: \(error.localizedDescription)")
        }
    }
    
    /// 위젯에 표시할 메시지 로드
    func loadWidgetMessage() -> WidgetMessage {
        guard let defaults = userDefaults,
              let data = defaults.data(forKey: widgetMessageKey) else {
            print("[DEBUG] No widget message found, returning empty")
            return .empty
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let message = try decoder.decode(WidgetMessage.self, from: data)
            return message
        } catch {
            print("[ERROR] Failed to decode widget message: \(error.localizedDescription)")
            return .empty
        }
    }
    
    /// 마지막 동기화 시간
    var lastSyncTimestamp: Date? {
        guard let defaults = userDefaults else { return nil }
        let timestamp = defaults.double(forKey: lastSyncKey)
        return timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
    }
    
    // MARK: - Widget Timeline
    
    /// 모든 위젯 타임라인 리로드
    func reloadWidgetTimelines() {
        WidgetCenter.shared.reloadAllTimelines()
        print("[INFO] Widget timelines reloaded")
    }
    
    /// 특정 위젯 타임라인 리로드
    func reloadTimeline(kind: String) {
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
        print("[INFO] Widget timeline reloaded for kind: \(kind)")
    }
    
    // MARK: - Clear Data
    
    /// 저장된 데이터 삭제
    func clearAllData() {
        guard let defaults = userDefaults else { return }
        defaults.removeObject(forKey: widgetMessageKey)
        defaults.removeObject(forKey: lastSyncKey)
        defaults.synchronize()
        
        reloadWidgetTimelines()
        print("[INFO] App Group data cleared")
    }
}
