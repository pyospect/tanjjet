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
                
                // 아이콘
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.pink)
                
                // 설명
                VStack(spacing: 8) {
                    Text("이름을 설정해주세요")
                        .font(.title2.bold())
                    
                    Text("파트너에게 표시될 이름이에요")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // 입력 필드
                VStack(spacing: 8) {
                    TextField("이름 입력", text: $nickname)
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal, 40)
                    
                    Text("\(nickname.count)/10")
                        .font(.caption)
                        .foregroundColor(nickname.count > 10 ? .red : .secondary)
                }
                
                // 에러 메시지
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                // 저장 버튼
                Button {
                    saveNickname()
                } label: {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("저장")
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(isValidNickname ? .pink : Color(.systemGray4))
                .foregroundColor(.white)
                .cornerRadius(12)
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
            await authViewModel.updateNickname(trimmed)
            isLoading = false
            isPresented = false
        }
    }
}
