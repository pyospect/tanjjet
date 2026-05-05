import SwiftUI
import AuthenticationServices

/// 로그인 화면
struct SignInView: View {
    @ObservedObject var authViewModel: AuthViewModel
    
    var body: some View {
        ZStack {
            TanjjetTheme.screenBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer(minLength: 44)
                
                VStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .fill(TanjjetTheme.accent.opacity(0.12))
                            .frame(width: 112, height: 112)
                        
                        Image(systemName: "heart.text.square.fill")
                            .font(.system(size: 56, weight: .semibold))
                            .foregroundStyle(TanjjetTheme.accentGradient)
                    }
                    
                    VStack(spacing: 8) {
                        Text("딴젯")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundStyle(TanjjetTheme.ink)
                        
                        Text("잠금화면까지 닿는 짧은 마음")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer(minLength: 48)
                
                VStack(spacing: 14) {
                    SignInFeatureRow(
                        icon: "link",
                        title: "둘만 연결",
                        description: "6자리 코드로 파트너와 안전하게 이어져요"
                    )
                    SignInFeatureRow(
                        icon: "rectangle.on.rectangle",
                        title: "위젯에 바로 표시",
                        description: "상대가 보낸 한마디를 잠금화면에서 확인해요"
                    )
                    SignInFeatureRow(
                        icon: "paperplane.fill",
                        title: "가볍게 전송",
                        description: "길게 쓰지 않아도 충분한 말을 빠르게 보내요"
                    )
                }
                .padding(.horizontal, 24)
                
                Spacer(minLength: 48)
                
                VStack(spacing: 14) {
                    SignInWithAppleButton(
                        onRequest: { request in
                            authViewModel.configureAppleSignIn(request)
                        },
                        onCompletion: { result in
                            Task {
                                await authViewModel.handleAppleSignIn(result)
                            }
                        }
                    )
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    
                    if let error = authViewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                    
                    Text("Apple 계정으로 로그인하고 바로 시작하세요")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
        .overlay {
            if authViewModel.isLoading {
                LoadingOverlay()
            }
        }
    }
}

private struct SignInFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(TanjjetTheme.accent)
                .frame(width: 34, height: 34)
                .background(TanjjetTheme.accent.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// 로딩 오버레이
struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.4)
                    .tint(TanjjetTheme.accent)
                
                Text("잠시만 기다려주세요")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
            .padding(28)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }
}

#Preview {
    SignInView(authViewModel: AuthViewModel())
}
