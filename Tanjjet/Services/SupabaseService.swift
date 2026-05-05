import Foundation
import Supabase
import AuthenticationServices
import CryptoKit

/// Supabase 서비스 싱글톤
final class SupabaseService {
    static let shared = SupabaseService()
    
    private let supabaseURL = URL(string: "https://wxlfukoozmuwslppmkaf.supabase.co")!
    private let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind4bGZ1a29vem11d3NscHBta2FmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk3OTY3MDIsImV4cCI6MjA4NTM3MjcwMn0.4C41WUr3nfZqQgethA6GMq_F1tV4btBUWiN8XMOi4oQ"
    
    let client: SupabaseClient
    
    private init() {
        client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey
        )
    }
    
    // MARK: - Authentication
    
    /// 현재 로그인된 사용자
    var currentUser: User? {
        get async {
            try? await client.auth.session.user
        }
    }
    
    /// 현재 사용자 ID
    var currentUserId: UUID? {
        get async {
            await currentUser?.id
        }
    }
    
    /// Sign in with Apple nonce 생성
    func generateNonce(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        return String(nonce)
    }
    
    /// SHA256 해시 (Apple Sign In용)
    func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap { String(format: "%02x", $0) }.joined()
        return hashString
    }
    
    /// Sign in with Apple 처리
    func signInWithApple(idToken: String, nonce: String) async throws -> Session {
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )
        return session
    }
    
    /// 로그아웃
    func signOut() async throws {
        try await client.auth.signOut()
    }
    
    // MARK: - Profile
    
    /// 현재 사용자 프로필 조회 (없으면 생성)
    func fetchCurrentProfile() async throws -> Profile? {
        guard let userId = await currentUserId else { return nil }
        
        // 먼저 프로필 조회 시도
        let profiles: [Profile] = try await client
            .from("profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .execute()
            .value
        
        if let profile = profiles.first {
            return profile
        }
        
        // 프로필이 없으면 생성
        let newProfile = ProfileInsert(id: userId, nickname: "사용자")
        let created: Profile = try await client
            .from("profiles")
            .insert(newProfile)
            .select()
            .single()
            .execute()
            .value
        
        return created
    }
    
    /// 프로필 업데이트
    func updateProfile(_ update: ProfileUpdate) async throws {
        guard let userId = await currentUserId else { return }
        
        try await client
            .from("profiles")
            .update(update)
            .eq("id", value: userId.uuidString)
            .execute()
    }
    
    // MARK: - Couple Pairing
    
    /// 6자리 랜덤 코드 생성
    func generatePairingCode() -> String {
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in characters.randomElement()! })
    }
    
    /// 커플 생성 (코드 발급)
    func createCouple() async throws -> Couple {
        guard let userId = await currentUserId else {
            throw SupabaseError.notAuthenticated
        }
        
        let code = generatePairingCode()
        let insert = CoupleInsert(code: code, user1Id: userId)
        
        let couple: Couple = try await client
            .from("couples")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value
        
        // 프로필에 couple_id 업데이트
        try await updateProfile(ProfileUpdate(coupleId: couple.id))
        
        return couple
    }
    
    /// 코드로 커플 참여
    func joinCouple(code: String) async throws -> Bool {
        guard let userId = await currentUserId else {
            throw SupabaseError.notAuthenticated
        }
        
        // RPC 함수 호출
        let result: Bool = try await client
            .rpc("join_couple", params: [
                "input_code": code.uppercased(),
                "joining_user_id": userId.uuidString
            ])
            .execute()
            .value
        
        return result
    }
    
    /// 현재 커플 정보 조회
    func fetchCurrentCouple() async throws -> Couple? {
        guard let profile = try await fetchCurrentProfile(),
              let coupleId = profile.coupleId else {
            return nil
        }
        
        let couples: [Couple] = try await client
            .from("couples")
            .select()
            .eq("id", value: coupleId.uuidString)
            .execute()
            .value
        
        return couples.first
    }
    
    // MARK: - Messages
    
    /// 메시지 전송
    func sendMessage(content: String) async throws -> Message {
        guard let userId = await currentUserId,
              let couple = try await fetchCurrentCouple() else {
            throw SupabaseError.notAuthenticated
        }
        
        let insert = MessageInsert(
            coupleId: couple.id,
            senderId: userId,
            content: content
        )
        
        let message: Message = try await client
            .from("messages")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value
        
        await sendPushNotificationIfNeeded(message: message, couple: couple, senderId: userId)
        
        return message
    }
    
    /// 메시지 저장 후 파트너에게 푸시 알림 요청
    private func sendPushNotificationIfNeeded(message: Message, couple: Couple, senderId: UUID) async {
        guard let receiverId = couple.partnerId(for: senderId) else {
            return
        }
        
        do {
            let accessToken = try await client.auth.session.accessToken
            let payload = PushNotificationPayload(
                messageId: message.id.uuidString,
                coupleId: couple.id.uuidString,
                senderId: senderId.uuidString,
                receiverId: receiverId.uuidString,
                content: message.content
            )
            
            var request = URLRequest(url: supabaseURL.appendingPathComponent("functions/v1/send-push-notification"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONEncoder().encode(payload)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                print("[ERROR] Push function returned an invalid response")
                return
            }
            
            print("[INFO] Push notification requested")
        } catch {
            print("[ERROR] Push notification request failed: \(error.localizedDescription)")
        }
    }
    
    /// 최근 메시지 조회
    func fetchRecentMessages(limit: Int = 50) async throws -> [Message] {
        guard let couple = try await fetchCurrentCouple() else {
            return []
        }
        
        let messages: [Message] = try await client
            .from("messages")
            .select()
            .eq("couple_id", value: couple.id.uuidString)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        
        return messages
    }
    
    /// 파트너가 보낸 최신 메시지 조회
    func fetchLatestPartnerMessage() async throws -> Message? {
        guard let userId = await currentUserId,
              let couple = try await fetchCurrentCouple() else {
            return nil
        }
        
        let messages: [Message] = try await client
            .from("messages")
            .select()
            .eq("couple_id", value: couple.id.uuidString)
            .neq("sender_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value
        
        return messages.first
    }
    
    /// 파트너 닉네임 조회
    func fetchPartnerNickname() async throws -> String? {
        guard let userId = await currentUserId,
              let couple = try await fetchCurrentCouple(),
              let partnerId = couple.partnerId(for: userId) else {
            return nil
        }
        
        let profiles: [Profile] = try await client
            .from("profiles")
            .select()
            .eq("id", value: partnerId.uuidString)
            .execute()
            .value
        
        return profiles.first?.nickname
    }
    
    // MARK: - Disconnect & Delete
    
    /// 커플 연결 해제
    func disconnectCouple() async throws {
        guard let userId = await currentUserId else {
            throw SupabaseError.notAuthenticated
        }
        
        let didDisconnect: Bool = try await client
            .rpc("disconnect_couple", params: [
                "disconnecting_user_id": userId.uuidString
            ])
            .execute()
            .value
        
        if !didDisconnect {
            try await updateProfile(ProfileUpdate(clearCoupleId: true))
        }
    }
    
    /// 계정 삭제
    func deleteAccount() async throws {
        let accessToken = try await client.auth.session.accessToken
        var request = URLRequest(url: supabaseURL.appendingPathComponent("functions/v1/delete-account"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.unknown
        }
        
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = Self.functionErrorMessage(from: data) ?? "계정 삭제 요청에 실패했습니다"
            throw SupabaseError.server(message)
        }
        
        try? await signOut()
    }
    
    // MARK: - Device Tokens (Push Notifications)
    
    /// 디바이스 토큰 저장
    func saveDeviceToken(token: String, userId: UUID) async throws {
        let insert = DeviceTokenInsert(
            userId: userId,
            token: token,
            platform: "ios"
        )
        
        // UPSERT: 이미 있으면 업데이트, 없으면 삽입
        try await client
            .from("device_tokens")
            .upsert(insert, onConflict: "user_id,token")
            .execute()
    }
    
    /// 디바이스 토큰 삭제
    func removeDeviceToken(token: String, userId: UUID) async throws {
        try await client
            .from("device_tokens")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .eq("token", value: token)
            .execute()
    }
    
    /// 현재 사용자의 모든 디바이스 토큰 삭제
    func removeAllDeviceTokens(userId: UUID) async throws {
        try await client
            .from("device_tokens")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .execute()
    }
}

// MARK: - Custom Errors

enum SupabaseError: LocalizedError {
    case notAuthenticated
    case pairingFailed
    case server(String)
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "로그인이 필요합니다"
        case .pairingFailed:
            return "페어링에 실패했습니다"
        case .server(let message):
            return message
        case .unknown:
            return "알 수 없는 오류가 발생했습니다"
        }
    }
}

private extension SupabaseService {
    static func functionErrorMessage(from data: Data) -> String? {
        guard !data.isEmpty else {
            return nil
        }
        
        if let errorResponse = try? JSONDecoder().decode(FunctionErrorResponse.self, from: data) {
            return errorResponse.error
        }
        
        return String(data: data, encoding: .utf8)
    }
}

private struct FunctionErrorResponse: Decodable {
    let error: String?
}

private struct PushNotificationPayload: Encodable {
    let messageId: String
    let coupleId: String
    let senderId: String
    let receiverId: String
    let content: String
    
    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case coupleId = "couple_id"
        case senderId = "sender_id"
        case receiverId = "receiver_id"
        case content
    }
}
