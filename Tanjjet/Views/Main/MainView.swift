import SwiftUI
import UserNotifications

/// 메인 화면 (메시지 전송)
struct MainView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var messageViewModel = MessageViewModel()
    @StateObject private var pushService = PushNotificationService.shared
    @FocusState private var isInputFocused: Bool
    @State private var showNicknameSetting = false
    @State private var showDisconnectConfirmation = false
    @State private var showDeleteConfirmation = false
    
    private var myNickname: String {
        authViewModel.currentProfile?.nickname ?? "나"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                TanjjetTheme.screenBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    MainHeaderView(
                        myNickname: myNickname,
                        partnerNickname: messageViewModel.partnerNickname,
                        isLoading: messageViewModel.isLoading,
                        onNickname: { showNicknameSetting = true },
                        onDisconnect: { showDisconnectConfirmation = true },
                        onSignOut: {
                            Task {
                                await messageViewModel.cleanup()
                                await authViewModel.signOut()
                            }
                        },
                        onDelete: { showDeleteConfirmation = true }
                    )
                    
                    if pushService.authorizationStatus == .notDetermined {
                        NotificationPermissionBanner(pushService: pushService)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 10)
                    }
                    
                    ChatMessagesView(
                        messageViewModel: messageViewModel,
                        currentUserId: authViewModel.currentProfile?.id,
                        myNickname: myNickname
                    )
                    
                    MessageInputSection(
                        messageViewModel: messageViewModel,
                        isInputFocused: $isInputFocused
                    )
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await pushService.refreshAuthorizationStatus()
                await messageViewModel.initialize()
            }
            .refreshable {
                await messageViewModel.refresh()
            }
            .sheet(isPresented: $showNicknameSetting) {
                NicknameSettingView(isPresented: $showNicknameSetting, authViewModel: authViewModel)
            }
            .confirmationDialog("파트너 연결을 해제할까요?", isPresented: $showDisconnectConfirmation, titleVisibility: .visible) {
                Button("연결 해제", role: .destructive) {
                    Task {
                        await messageViewModel.cleanup()
                        await authViewModel.disconnectCouple()
                    }
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("현재 위젯 메시지는 지워지고 다시 페어링해야 합니다.")
            }
            .confirmationDialog("정말 회원 탈퇴할까요?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("회원 탈퇴", role: .destructive) {
                    Task {
                        await messageViewModel.cleanup()
                        await authViewModel.deleteAccount()
                    }
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("프로필과 연결 정보가 삭제됩니다. 이 작업은 되돌릴 수 없습니다.")
            }
            .onAppear {
                if myNickname == "사용자" || myNickname.isEmpty {
                    showNicknameSetting = true
                }
            }
        }
    }
}

private struct MainHeaderView: View {
    let myNickname: String
    let partnerNickname: String
    let isLoading: Bool
    let onNickname: () -> Void
    let onDisconnect: () -> Void
    let onSignOut: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("딴젯")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.75)
                            .tint(TanjjetTheme.accent)
                    }
                }
                
                HStack(spacing: 6) {
                    Text(myNickname)
                        .lineLimit(1)
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                        .foregroundStyle(TanjjetTheme.accent)
                    Text(partnerNickname)
                        .lineLimit(1)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button(action: onNickname) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .background(.thinMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("내 이름 변경")
            
            Menu {
                Section {
                    Label("나: \(myNickname)", systemImage: "person.fill")
                    Label("상대: \(partnerNickname)", systemImage: "heart.fill")
                }
                
                Button(action: onNickname) {
                    Label("내 이름 변경", systemImage: "pencil")
                }
                
                Button(action: onDisconnect) {
                    Label("연결 해제", systemImage: "link.badge.plus")
                }
                
                Button(action: onSignOut) {
                    Label("로그아웃", systemImage: "rectangle.portrait.and.arrow.right")
                }
                
                Button(role: .destructive, action: onDelete) {
                    Label("회원 탈퇴", systemImage: "person.crop.circle.badge.xmark")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .bold))
                    .rotationEffect(.degrees(90))
                    .frame(width: 40, height: 40)
                    .background(.thinMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("더보기")
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }
}

private struct NotificationPermissionBanner: View {
    @ObservedObject var pushService: PushNotificationService
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(TanjjetTheme.accent)
                .frame(width: 34, height: 34)
                .background(TanjjetTheme.accent.opacity(0.12))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 3) {
                Text("새 메시지 알림")
                    .font(.subheadline.weight(.semibold))
                
                Text("파트너의 한마디를 바로 받을 수 있어요")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button {
                TanjjetTheme.impact(.medium)
                Task {
                    _ = await pushService.requestPermission()
                }
            } label: {
                Text("켜기")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(TanjjetTheme.accent)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// 채팅 메시지 목록 뷰
struct ChatMessagesView: View {
    @ObservedObject var messageViewModel: MessageViewModel
    let currentUserId: UUID?
    let myNickname: String
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if messageViewModel.messages.isEmpty && !messageViewModel.isLoading {
                        EmptyMessageView(partnerNickname: messageViewModel.partnerNickname)
                            .padding(.top, 96)
                    } else {
                        ForEach(messageViewModel.messages.reversed()) { message in
                            ChatBubble(
                                message: message,
                                isFromMe: message.senderId == currentUserId,
                                senderNickname: message.senderId == currentUserId ? myNickname : messageViewModel.partnerNickname
                            )
                            .id(message.id)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messageViewModel.messages.count) { _, _ in
                if let lastMessage = messageViewModel.messages.first {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

private struct EmptyMessageView: View {
    let partnerNickname: String
    
    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(TanjjetTheme.accent.opacity(0.1))
                    .frame(width: 86, height: 86)
                
                Image(systemName: "bubble.left.and.text.bubble.right.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(TanjjetTheme.accentGradient)
            }
            
            VStack(spacing: 6) {
                Text("아직 오간 메시지가 없어요")
                    .font(.headline)
                
                Text("\(partnerNickname)에게 첫 한마디를 보내보세요")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// 채팅 버블
struct ChatBubble: View {
    let message: Message
    let isFromMe: Bool
    let senderNickname: String
    
    var body: some View {
        HStack(alignment: .bottom) {
            if isFromMe {
                Spacer(minLength: 52)
            }
            
            VStack(alignment: isFromMe ? .trailing : .leading, spacing: 5) {
                Text(senderNickname)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isFromMe ? TanjjetTheme.accent : .secondary)
                
                Text(message.content)
                    .font(.body)
                    .lineSpacing(2)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 11)
                    .background(isFromMe ? AnyShapeStyle(TanjjetTheme.accentGradient) : AnyShapeStyle(.thinMaterial))
                    .foregroundStyle(isFromMe ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: isFromMe ? TanjjetTheme.accent.opacity(0.18) : .black.opacity(0.04), radius: 10, x: 0, y: 5)
                
                if let createdAt = message.createdAt {
                    Text(createdAt.chatTimeString)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            if !isFromMe {
                Spacer(minLength: 52)
            }
        }
        .transition(.move(edge: isFromMe ? .trailing : .leading).combined(with: .opacity))
    }
}

/// 메시지 입력 섹션
struct MessageInputSection: View {
    @ObservedObject var messageViewModel: MessageViewModel
    @FocusState.Binding var isInputFocused: Bool
    
    private var trimmedInput: String {
        messageViewModel.messageInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var isOverLimit: Bool {
        messageViewModel.messageInput.count > 100
    }
    
    var body: some View {
        VStack(spacing: 8) {
            if let error = messageViewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }
            
            HStack(alignment: .bottom, spacing: 10) {
                VStack(alignment: .trailing, spacing: 4) {
                    TextField("짧은 마음을 전해보세요", text: $messageViewModel.messageInput, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...4)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .focused($isInputFocused)
                        .submitLabel(.send)
                        .onSubmit {
                            sendMessage()
                        }
                    
                    Text("\(messageViewModel.messageInput.count)/100")
                        .font(.caption2)
                        .foregroundStyle(isOverLimit ? .red : .secondary)
                        .padding(.trailing, 8)
                }
                
                Button {
                    TanjjetTheme.impact(.medium)
                    sendMessage()
                } label: {
                    Image(systemName: messageViewModel.isSending ? "ellipsis" : "arrow.up")
                        .font(.system(size: 18, weight: .bold))
                        .frame(width: 48, height: 48)
                        .background(canSend ? TanjjetTheme.accentGradient : LinearGradient(colors: [Color(.systemGray4)], startPoint: .top, endPoint: .bottom))
                        .foregroundStyle(.white)
                        .clipShape(Circle())
                        .shadow(color: canSend ? TanjjetTheme.accent.opacity(0.28) : .clear, radius: 12, x: 0, y: 6)
                }
                .disabled(!canSend)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.regularMaterial)
    }
    
    private var canSend: Bool {
        !trimmedInput.isEmpty && !isOverLimit && !messageViewModel.isSending
    }
    
    private func sendMessage() {
        guard canSend else {
            return
        }
        
        Task {
            await messageViewModel.sendMessage()
        }
    }
}

// MARK: - Date Extension

extension Date {
    var relativeTimeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    var chatTimeString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        
        if Calendar.current.isDateInToday(self) {
            formatter.dateFormat = "a h:mm"
        } else if Calendar.current.isDateInYesterday(self) {
            formatter.dateFormat = "'어제' a h:mm"
        } else {
            formatter.dateFormat = "M/d a h:mm"
        }
        
        return formatter.string(from: self)
    }
}

#Preview {
    MainView(authViewModel: AuthViewModel())
}
