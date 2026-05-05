import WidgetKit
import SwiftUI

// MARK: - Widget Entry

struct TanjjetWidgetEntry: TimelineEntry {
    let date: Date
    let message: WidgetMessage
}

// MARK: - Timeline Provider

struct TanjjetWidgetProvider: TimelineProvider {
    
    private let appGroupID = "group.com.pyospect.tanjjet"
    private let widgetMessageKey = "widget_message"
    
    /// Placeholder (위젯 갤러리용)
    func placeholder(in context: Context) -> TanjjetWidgetEntry {
        TanjjetWidgetEntry(
            date: Date(),
            message: WidgetMessage(
                content: "사랑해",
                senderNickname: "파트너",
                timestamp: Date()
            )
        )
    }
    
    /// Snapshot (빠른 미리보기)
    func getSnapshot(in context: Context, completion: @escaping (TanjjetWidgetEntry) -> Void) {
        let message = loadWidgetMessage()
        let entry = TanjjetWidgetEntry(date: Date(), message: message)
        completion(entry)
    }
    
    /// Timeline (실제 업데이트)
    func getTimeline(in context: Context, completion: @escaping (Timeline<TanjjetWidgetEntry>) -> Void) {
        let message = loadWidgetMessage()
        let entry = TanjjetWidgetEntry(date: Date(), message: message)
        
        // 15분 후 다음 업데이트 (앱에서 reloadTimelines 호출 시 즉시 업데이트됨)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        
        completion(timeline)
    }
    
    /// App Group에서 메시지 로드
    private func loadWidgetMessage() -> WidgetMessage {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: widgetMessageKey) else {
            return .empty
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(WidgetMessage.self, from: data)
        } catch {
            return .empty
        }
    }
}

// MARK: - Widget View

struct TanjjetWidgetEntryView: View {
    var entry: TanjjetWidgetEntry
    
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .accessoryRectangular:
            AccessoryRectangularView(message: entry.message)
        default:
            // 지원하지 않는 위젯 패밀리
            Text("지원하지 않음")
        }
    }
}

/// 잠금화면 Rectangular 위젯 (2x1)
struct AccessoryRectangularView: View {
    let message: WidgetMessage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // 발신자 (선택적)
            if !message.senderNickname.isEmpty {
                Text(message.senderNickname)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .opacity(0.7)
            }
            
            // 메시지 내용
            Text(message.content)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .minimumScaleFactor(0.5)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            // 투명 배경
            Color.clear
        }
    }
}

// MARK: - Widget Configuration

struct TanjjetWidget: Widget {
    let kind: String = "TanjjetWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TanjjetWidgetProvider()) { entry in
            TanjjetWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Tanjjet")
        .description("파트너의 메시지를 잠금화면에서 확인하세요")
        .supportedFamilies([.accessoryRectangular])
    }
}

// MARK: - Preview

#Preview(as: .accessoryRectangular) {
    TanjjetWidget()
} timeline: {
    TanjjetWidgetEntry(
        date: Date(),
        message: WidgetMessage(
            content: "오늘 하루도 파이팅!",
            senderNickname: "소중한 사람",
            timestamp: Date()
        )
    )
    TanjjetWidgetEntry(
        date: Date(),
        message: WidgetMessage(
            content: "사랑해",
            senderNickname: "파트너",
            timestamp: Date()
        )
    )
}
