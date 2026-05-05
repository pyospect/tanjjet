import SwiftUI

/// 메인 라우팅 뷰
struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        Group {
            switch authViewModel.authState {
            case .loading:
                // 로딩 화면
                LoadingView()
                
            case .signedOut:
                // 로그인 화면
                SignInView(authViewModel: authViewModel)
                
            case .signedIn:
                // 페어링이 실제로 완료된 경우에만 메인 화면으로 이동
                if authViewModel.hasCompletedPairing {
                    MainView(authViewModel: authViewModel)
                } else {
                    PairingView(authViewModel: authViewModel)
                }
            }
        }
        .animation(.easeInOut, value: authViewModel.authState)
        .animation(.easeInOut, value: authViewModel.hasCompletedPairing)
    }
}

/// 초기 로딩 화면
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "heart.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.pink, .red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            ProgressView()
                .tint(.pink)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
