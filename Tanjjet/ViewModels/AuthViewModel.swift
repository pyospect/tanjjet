import Foundation
import AuthenticationServices
import SwiftUI

/// 인증 상태
enum AuthState {
    case loading
    case signedOut
    case signedIn
}

/// 인증 뷰모델
@MainActor
final class AuthViewModel: ObservableObject {
    @Published var authState: AuthState = .loading
    @Published var currentProfile: Profile?
    @Published var currentCouple: Couple?
    @Published var errorMessage: String?
    @Published var isLoading = false
    
    private var currentNonce: String?
    
    var hasCompletedPairing: Bool {
        currentCouple?.isComplete == true
    }
    
    init() {
        Task {
            await checkAuthStatus()
        }
    }
    
    // MARK: - Auth Status
    
    /// 현재 인증 상태 확인
    func checkAuthStatus() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            if let _ = await SupabaseService.shared.currentUser {
                try await loadSignedInContext()
                authState = .signedIn
                await PushNotificationService.shared.registerForRemoteNotificationsIfAuthorized()
                AppLogger.info("User signed in")
            } else {
                currentProfile = nil
                currentCouple = nil
                authState = .signedOut
                AppLogger.info("User not signed in")
            }
        } catch {
            AppLogger.error("Check auth status failed: \(error.localizedDescription)")
            currentProfile = nil
            currentCouple = nil
            authState = .signedOut
        }
    }
    
    // MARK: - Sign in with Apple
    
    /// Sign in with Apple 요청 설정
    func configureAppleSignIn(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
        errorMessage = nil
        currentNonce = nil
        
        do {
            let nonce = try SupabaseService.shared.generateNonce()
            currentNonce = nonce
            request.nonce = SupabaseService.shared.sha256(nonce)
        } catch {
            AppLogger.error("Failed to prepare Apple Sign In nonce: \(error.localizedDescription)")
            errorMessage = "로그인을 준비하지 못했습니다. 다시 시도해주세요."
        }
    }
    
    /// Sign in with Apple 결과 처리
    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        isLoading = true
        errorMessage = nil
        
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityTokenData = appleIDCredential.identityToken,
                  let identityToken = String(data: identityTokenData, encoding: .utf8),
                  let nonce = currentNonce else {
                errorMessage = "Apple 로그인 정보를 가져올 수 없습니다"
                isLoading = false
                return
            }
            
            do {
                _ = try await SupabaseService.shared.signInWithApple(
                    idToken: identityToken,
                    nonce: nonce
                )
                
                try await loadSignedInContext()
                
                // 닉네임 설정 (최초 로그인 시)
                if let fullName = appleIDCredential.fullName,
                   let profile = currentProfile,
                   profile.nickname == nil || profile.nickname == "사용자" {
                    let nickname = [fullName.givenName, fullName.familyName]
                        .compactMap { $0 }
                        .joined(separator: " ")
                    
                    if !nickname.isEmpty {
                        try await SupabaseService.shared.updateProfile(
                            ProfileUpdate(nickname: nickname)
                        )
                        try await loadSignedInContext()
                    }
                }
                
                authState = .signedIn
                await PushNotificationService.shared.registerForRemoteNotificationsIfAuthorized()
                AppLogger.info("Sign in with Apple successful")
                
            } catch {
                AppLogger.error("Sign in with Apple failed: \(error.localizedDescription)")
                errorMessage = "로그인에 실패했습니다: \(error.localizedDescription)"
            }
            
        case .failure(let error):
            if let authError = error as? ASAuthorizationError,
               authError.code == .canceled {
                // 사용자가 취소한 경우
                AppLogger.info("Sign in with Apple canceled")
            } else {
                AppLogger.error("Sign in with Apple error: \(error.localizedDescription)")
                errorMessage = "로그인 중 오류가 발생했습니다"
            }
        }
        
        isLoading = false
    }
    
    // MARK: - Sign Out
    
    /// 로그아웃
    func signOut() async {
        isLoading = true
        
        do {
            // Realtime 구독 해제
            await RealtimeService.shared.unsubscribe()
            
            // 푸시 토큰 삭제
            await PushNotificationService.shared.removeToken()
            
            // App Group 데이터 클리어
            AppGroupManager.shared.clearAllData()
            
            // Supabase 로그아웃
            try await SupabaseService.shared.signOut()
            
            currentProfile = nil
            currentCouple = nil
            authState = .signedOut
            AppLogger.info("Signed out successfully")
            
        } catch {
            AppLogger.error("Sign out failed: \(error.localizedDescription)")
            errorMessage = "로그아웃에 실패했습니다"
        }
        
        isLoading = false
    }
    
    // MARK: - Profile
    
    /// 프로필 새로고침
    func refreshProfile() async {
        do {
            try await loadSignedInContext()
        } catch {
            AppLogger.error("Refresh profile failed: \(error.localizedDescription)")
        }
    }
    
    /// 닉네임 업데이트
    @discardableResult
    func updateNickname(_ nickname: String) async -> Bool {
        do {
            try await SupabaseService.shared.updateProfile(
                ProfileUpdate(nickname: nickname)
            )
            try await loadSignedInContext()
            AppLogger.info("Nickname updated")
            return true
        } catch {
            AppLogger.error("Update nickname failed: \(error.localizedDescription)")
            errorMessage = "닉네임 변경에 실패했습니다"
            return false
        }
    }
    
    /// 커플 연결 해제
    func disconnectCouple() async {
        isLoading = true
        
        do {
            try await SupabaseService.shared.disconnectCouple()
            currentCouple = nil
            try await loadSignedInContext()
            AppGroupManager.shared.clearAllData()
            AppLogger.info("Couple disconnected")
        } catch {
            AppLogger.error("Disconnect couple failed: \(error.localizedDescription)")
            errorMessage = "연결 해제에 실패했습니다"
        }
        
        isLoading = false
    }
    
    /// 회원 탈퇴
    func deleteAccount() async {
        isLoading = true
        
        do {
            // Realtime 구독 해제
            await RealtimeService.shared.unsubscribe()
            
            // 푸시 토큰 삭제
            await PushNotificationService.shared.removeToken()
            
            // App Group 데이터 클리어
            AppGroupManager.shared.clearAllData()
            
            // 계정 삭제
            try await SupabaseService.shared.deleteAccount()
            
            currentProfile = nil
            currentCouple = nil
            authState = .signedOut
            AppLogger.info("Account deleted")
            
        } catch {
            AppLogger.error("Delete account failed: \(error.localizedDescription)")
            errorMessage = "회원 탈퇴에 실패했습니다"
        }
        
        isLoading = false
    }
    
    private func loadSignedInContext() async throws {
        currentProfile = try await SupabaseService.shared.fetchCurrentProfile()
        currentCouple = try await SupabaseService.shared.fetchCurrentCouple()
    }
}
