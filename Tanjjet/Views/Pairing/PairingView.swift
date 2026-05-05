import SwiftUI

/// 커플 페어링 화면
struct PairingView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var pairingViewModel = PairingViewModel()
    @State private var showNicknameSetting = false
    
    private var myNickname: String {
        authViewModel.currentProfile?.nickname ?? "사용자"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                TanjjetTheme.screenBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 28) {
                        topBar
                        
                        VStack(spacing: 12) {
                            Image(systemName: "heart.circle.fill")
                                .font(.system(size: 64, weight: .semibold))
                                .foregroundStyle(TanjjetTheme.accentGradient)
                            
                            Text("파트너와 연결하기")
                                .font(.title2.bold())
                            
                            Text("둘 중 한 명은 코드를 만들고, 다른 한 명은 그 코드를 입력하면 바로 연결돼요.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(2)
                                .padding(.horizontal, 12)
                        }
                        .padding(.top, 16)
                        
                        Group {
                            switch pairingViewModel.pairingMode {
                            case .none:
                                ModeSelectionView(pairingViewModel: pairingViewModel)
                            case .createCode:
                                CodeDisplayView(pairingViewModel: pairingViewModel)
                            case .enterCode:
                                CodeInputView(pairingViewModel: pairingViewModel)
                            }
                        }
                        .padding(.top, 8)
                        
                        if let error = pairingViewModel.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .overlay {
                if pairingViewModel.isLoading {
                    LoadingOverlay()
                }
            }
            .onChange(of: pairingViewModel.isPaired) { _, isPaired in
                if isPaired {
                    Task {
                        await authViewModel.refreshProfile()
                    }
                }
            }
            .task {
                await pairingViewModel.checkPairingStatus()
            }
            .task(id: pairingViewModel.pairingMode) {
                guard pairingViewModel.pairingMode == .createCode else { return }
                
                while !Task.isCancelled &&
                        pairingViewModel.pairingMode == .createCode &&
                        !pairingViewModel.isPaired {
                    try? await Task.sleep(for: .seconds(3))
                    await pairingViewModel.checkPairingStatus(showLoading: false)
                }
            }
            .sheet(isPresented: $showNicknameSetting) {
                NicknameSettingView(isPresented: $showNicknameSetting, authViewModel: authViewModel)
            }
            .onAppear {
                if myNickname == "사용자" || myNickname.isEmpty {
                    showNicknameSetting = true
                }
            }
        }
    }
    
    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                showNicknameSetting = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.fill")
                    Text(myNickname)
                        .lineLimit(1)
                    Image(systemName: "pencil")
                        .font(.caption)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.thinMaterial)
                .clipShape(Capsule())
            }
            
            Spacer()
            
            Button {
                Task {
                    await authViewModel.signOut()
                }
            } label: {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 40, height: 40)
                    .background(.thinMaterial)
                    .clipShape(Circle())
            }
            .accessibilityLabel("로그아웃")
        }
    }
}

/// 모드 선택 뷰
struct ModeSelectionView: View {
    @ObservedObject var pairingViewModel: PairingViewModel
    
    var body: some View {
        VStack(spacing: 14) {
            Button {
                TanjjetTheme.impact()
                Task {
                    await pairingViewModel.createPairingCode()
                }
            } label: {
                Label("내 코드 만들기", systemImage: "plus.circle.fill")
            }
            .buttonStyle(TanjjetPrimaryButtonStyle())
            
            Button {
                TanjjetTheme.impact()
                pairingViewModel.showEnterCodeView()
            } label: {
                Label("파트너 코드 입력", systemImage: "keyboard")
            }
            .buttonStyle(TanjjetSecondaryButtonStyle())
        }
    }
}

/// 생성된 코드 표시 뷰
struct CodeDisplayView: View {
    @ObservedObject var pairingViewModel: PairingViewModel
    @State private var copied = false
    
    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 6) {
                Text("이 코드를 파트너에게 보내주세요")
                    .font(.headline)
                
                Text("상대가 입력하면 자동으로 연결을 확인합니다")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            HStack(spacing: 8) {
                ForEach(Array(pairingViewModel.generatedCode.enumerated()), id: \.offset) { _, char in
                    Text(String(char))
                        .font(.system(size: 30, weight: .bold, design: .monospaced))
                        .frame(width: 43, height: 58)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .minimumScaleFactor(0.82)
            
            Button {
                pairingViewModel.copyCodeToClipboard()
                TanjjetTheme.impact(.medium)
                copied = true
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    copied = false
                }
            } label: {
                Label(copied ? "복사됨" : "코드 복사", systemImage: copied ? "checkmark" : "doc.on.doc")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(TanjjetTheme.accent)
            }
            
            HStack(spacing: 8) {
                ProgressView()
                    .tint(TanjjetTheme.accent)
                
                Text("파트너를 기다리는 중")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
            
            Button {
                pairingViewModel.reset()
            } label: {
                Text("다른 방법 선택")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)
        }
        .padding(20)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

/// 코드 입력 뷰
struct CodeInputView: View {
    @ObservedObject var pairingViewModel: PairingViewModel
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 6) {
                Text("파트너의 6자리 코드")
                    .font(.headline)
                
                Text("영문과 숫자만 입력할 수 있어요")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { index in
                    let char = index < pairingViewModel.inputCode.count
                        ? String(pairingViewModel.inputCode[pairingViewModel.inputCode.index(pairingViewModel.inputCode.startIndex, offsetBy: index)])
                        : ""
                    
                    Text(char)
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .frame(width: 43, height: 58)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(index == pairingViewModel.inputCode.count ? TanjjetTheme.accent : Color.clear, lineWidth: 2)
                        )
                }
            }
            .minimumScaleFactor(0.82)
            .onTapGesture {
                isFocused = true
            }
            
            TextField("", text: $pairingViewModel.inputCode)
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.characters)
                .focused($isFocused)
                .onChange(of: pairingViewModel.inputCode) { _, newValue in
                    let filtered = newValue
                        .uppercased()
                        .filter { $0.isLetter || $0.isNumber }
                        .prefix(6)
                    pairingViewModel.inputCode = String(filtered)
                }
                .frame(width: 1, height: 1)
                .opacity(0)
            
            Button {
                TanjjetTheme.impact(.medium)
                Task {
                    await pairingViewModel.joinWithCode()
                }
            } label: {
                Text("연결하기")
            }
            .buttonStyle(TanjjetPrimaryButtonStyle(isDisabled: pairingViewModel.inputCode.count != 6))
            .disabled(pairingViewModel.inputCode.count != 6)
            
            Button {
                pairingViewModel.reset()
            } label: {
                Text("다른 방법 선택")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onAppear {
            isFocused = true
        }
    }
}

#Preview {
    PairingView(authViewModel: AuthViewModel())
}
