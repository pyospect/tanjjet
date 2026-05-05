import Foundation
import SwiftUI

/// 페어링 모드
enum PairingMode {
    case none
    case createCode
    case enterCode
}

/// 페어링 뷰모델
@MainActor
final class PairingViewModel: ObservableObject {
    @Published var pairingMode: PairingMode = .none
    @Published var generatedCode: String = ""
    @Published var inputCode: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isPaired = false
    @Published var currentCouple: Couple?
    
    // MARK: - Create Code
    
    /// 새 페어링 코드 생성
    func createPairingCode() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            if let existingCouple = try await SupabaseService.shared.fetchCurrentCouple() {
                currentCouple = existingCouple
                isPaired = existingCouple.isComplete
                generatedCode = existingCouple.code
                pairingMode = existingCouple.isComplete ? .none : .createCode
                AppLogger.info("Reusing existing pairing code")
                return
            }
            
            let couple = try await SupabaseService.shared.createCouple()
            generatedCode = couple.code
            currentCouple = couple
            pairingMode = .createCode
            AppLogger.info("Pairing code created")
        } catch {
            AppLogger.error("Create pairing code failed: \(error.localizedDescription)")
            errorMessage = "코드 생성에 실패했습니다"
        }
    }
    
    // MARK: - Join Code
    
    /// 코드 입력 모드로 전환
    func showEnterCodeView() {
        inputCode = ""
        errorMessage = nil
        pairingMode = .enterCode
    }
    
    /// 코드로 커플 참여
    func joinWithCode() async {
        let code = inputCode.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard code.count == 6 else {
            errorMessage = "6자리 코드를 입력해주세요"
            return
        }
        
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let success = try await SupabaseService.shared.joinCouple(code: code)
            
            if success {
                currentCouple = try await SupabaseService.shared.fetchCurrentCouple()
                isPaired = currentCouple?.isComplete == true
                AppLogger.info("Successfully joined couple")
            } else {
                errorMessage = "유효하지 않은 코드입니다"
            }
        } catch {
            AppLogger.error("Join couple failed: \(error.localizedDescription)")
            errorMessage = "연결에 실패했습니다"
        }
    }
    
    // MARK: - Check Status
    
    /// 페어링 상태 확인
    func checkPairingStatus(showLoading: Bool = true) async {
        if showLoading {
            isLoading = true
        }
        defer {
            if showLoading {
                isLoading = false
            }
        }
        
        do {
            if let couple = try await SupabaseService.shared.fetchCurrentCouple() {
                currentCouple = couple
                isPaired = couple.isComplete
                
                if !isPaired && couple.code.isEmpty == false {
                    // 코드를 생성했지만 아직 파트너가 참여하지 않은 상태
                    generatedCode = couple.code
                    pairingMode = .createCode
                }
                
                AppLogger.info("Pairing status: \(isPaired ? "paired" : "not paired")")
            } else {
                currentCouple = nil
                isPaired = false
            }
        } catch {
            AppLogger.error("Check pairing status failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Reset
    
    /// 상태 초기화
    func reset() {
        pairingMode = .none
        generatedCode = ""
        inputCode = ""
        errorMessage = nil
    }
    
    /// 코드 복사
    func copyCodeToClipboard() {
        UIPasteboard.general.string = generatedCode
        AppLogger.info("Code copied to clipboard")
    }
}
