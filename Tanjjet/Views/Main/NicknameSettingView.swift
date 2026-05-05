import SwiftUI

/// 닉네임 설정 뷰 (처음 또는 설정에서)
struct NicknameSettingView: View {
    @Binding var isPresented: Bool
    @ObservedObject var authViewModel: AuthViewModel
    
    @State private var nickname: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(TanjjetTheme.accent.opacity(0.12))
                        .frame(width: 96, height: 96)

                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 54, weight: .semibold))
                        .foregroundStyle(TanjjetTheme.accentGradient)
                }
                
                VStack(spacing: 8) {
                    Text("이름을 설정해주세요")
                        .font(.title2.bold())
                        .foregroundStyle(TanjjetTheme.ink)
                    
                    Text("파트너에게 표시될 이름이에요")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 8) {
                    TextField("이름 입력", text: $nickname)
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal, 40)
                        .onChange(of: nickname) { _, newValue in
                            if newValue.count > 10 {
                                nickname = String(newValue.prefix(10))
                            }
                        }
                    
                    Text("\(nickname.count)/10")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                Button {
                    TanjjetTheme.impact(.medium)
                    saveNickname()
                } label: {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("저장")
                    }
                }
                .buttonStyle(TanjjetPrimaryButtonStyle(isDisabled: !isValidNickname || isLoading))
                .padding(.horizontal)
                .disabled(!isValidNickname || isLoading)
                
                Spacer()
                    .frame(height: 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("건너뛰기") {
                        isPresented = false
                    }
                    .foregroundColor(.secondary)
                }
            }
            .onAppear {
                nickname = authViewModel.currentProfile?.nickname ?? ""
            }
            .background(TanjjetTheme.screenBackground.ignoresSafeArea())
        }
    }
    
    private var isValidNickname: Bool {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 10
    }
    
    private func saveNickname() {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard isValidNickname else {
            errorMessage = "1~10자 이내로 입력해주세요"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            let didSave = await authViewModel.updateNickname(trimmed)
            isLoading = false

            if didSave {
                isPresented = false
            } else {
                errorMessage = authViewModel.errorMessage ?? "이름을 저장하지 못했습니다. 다시 시도해주세요."
            }
        }
    }
}
