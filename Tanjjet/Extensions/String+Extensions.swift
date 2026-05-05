import Foundation

extension String {
    /// 문자열이 비어있거나 공백만 있는지 확인
    var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// 앞뒤 공백 제거
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
