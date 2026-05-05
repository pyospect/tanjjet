# 딴젯 릴리즈 완료 감사

Last checked: 2026-05-05

이 문서는 원래 목표인 "기능, 사용자 경험, 개발 품질 측면에서 앱을 정리하고 TestFlight에서 확인한 뒤 배포 준비 가능한 상태로 만든다"를 실제 산출물과 검증 증거에 매핑한 감사 기록입니다.

## 성공 기준

1. 앱 핵심 기능이 TestFlight에서 검증 가능한 수준으로 동작해야 합니다.
2. 사용자 경험이 초기 사용자와 심사자가 이해하기 쉬운 상태여야 합니다.
3. 개발 품질, 빌드, 테스트, 로그, 개인정보, 배포 스크립트가 릴리즈 기준을 통과해야 합니다.
4. App Store Connect/TestFlight 업로드가 가능해야 합니다.
5. Supabase 원격 DB와 Edge Functions가 앱의 실제 운영 플로우를 뒷받침해야 합니다.
6. 최종 사용자가 TestFlight에서 확인한 뒤 App Store 제출로 이어갈 문서가 있어야 합니다.

## 프롬프트-산출물 체크리스트

| 요구사항 | 산출물 또는 증거 | 상태 |
| --- | --- | --- |
| 기능 정리 | 인증, 닉네임, 커플 생성/참여, 메시지, 실시간 동기화, 위젯, 푸시, 연결 해제, 계정 삭제 플로우가 PR에 포함됨 | 완료 |
| 닉네임 저장 UX | `Tanjjet/ViewModels/AuthViewModel.swift`, `Tanjjet/Views/Main/NicknameSettingView.swift`에서 저장 실패 시 시트를 닫지 않고 오류 표시 | 완료 |
| 사용자 경험 정리 | `docs/testflight-qa-plan.md`에 두 기기 QA 플로우, foreground push, badge, widget, logout/disconnect/delete 계정 확인 항목 포함 | 완료 |
| App Store 메타데이터 | `docs/app-store-connect-metadata.md`에 앱 정보, 설명, 심사 노트, 개인정보 라벨 매핑, 스크린샷 가이드 포함 | 완료 |
| 개인정보/지원 URL | `docs/privacy-policy.html`, `docs/support.html` 존재 및 `scripts/release-readiness-audit.sh`에서 공개 URL reachable 확인 | 완료 |
| 개인정보 manifest | `Tanjjet/PrivacyInfo.xcprivacy`, `TanjjetWidget/PrivacyInfo.xcprivacy`가 `plutil` lint 통과 | 완료 |
| 앱 아이콘/스크린샷 | `scripts/release-readiness-audit.sh`에서 1024px 앱 아이콘 무알파, 1242 x 2688 스크린샷 확인 | 완료 |
| Release 빌드/테스트 | GitHub Actions `Verify iOS Release Build` 통과, `scripts/verify-release.sh`가 Debug test, Release simulator build, Release iPhoneOS build 수행 | 완료 |
| 릴리즈 워크플로 품질 | `.github/workflows/release-verify.yml`이 `actions/checkout@v6.0.2`와 job/step timeout 사용, 감사 스크립트가 이를 확인 | 완료 |
| 로깅 정리 | 앱 직접 `print`는 DEBUG 전용 `AppLogger`로 제한, 메시지 본문/토큰/코드/닉네임 로그 제거 | 완료 |
| Supabase Edge Functions | `send-push-notification`, `delete-account`, `disconnect-couple` 배포 및 unauthenticated 401 확인 | 완료 |
| Supabase 원격 DB strict gate | `scripts/verify-supabase-remote.sh`가 `disconnect_couple` RPC 404를 보고 | 미완료 |
| TestFlight archive | `build/Tanjjet.xcarchive` 존재, bundle id와 signing identity 감사 통과 | 완료 |
| TestFlight upload | `scripts/upload-testflight.sh`가 App Store Connect 접근 권한 부족으로 차단됨 | 미완료 |
| 최종 파이프라인 | `scripts/finalize-testflight-release.sh`가 Supabase/App Store Connect preflight 블로커를 함께 표시 | 완료 |
| 한국어 인수인계 | `docs/release-handoff-ko.md`에 남은 권한 입력, DB 마이그레이션, 최종 실행 순서, 성공 후 QA 절차 정리 | 완료 |
| PR 상태 | PR #1은 draft이고 merge state는 clean. 최종 제출 전 master merge 필요 | 대기 |

## 실제 확인 명령

최근 확인한 명령과 결과는 아래와 같습니다.

```sh
git status --short --branch
```

결과: 작업 트리 clean.

```sh
gh pr checks 1 --watch=false
```

결과: `Verify iOS Release Build` 통과.

```sh
gh pr view 1 --json mergeStateStatus,isDraft,headRefOid,url
```

결과: PR #1은 draft, merge state `CLEAN`.

```sh
scripts/release-readiness-audit.sh
```

결과: 실패 0개, 블로커 2개, 경고 2개.

## 아직 완료가 아닌 이유

목표를 완료로 표시하려면 아래 두 조건이 실제로 해결되어야 합니다.

1. App Store Connect 접근 권한 또는 API 키 3종이 준비되어 TestFlight upload가 성공해야 합니다.
2. Supabase 원격 DB에 `supabase/migrations/20260505041000_pairing_push_account_hardening.sql`이 적용되어 `disconnect_couple` RPC strict gate가 통과해야 합니다.

이 두 조건이 해결되기 전에는 앱 코드와 릴리즈 준비물은 정리되어 있어도 "TestFlight에서 확인하고 바로 배포" 상태로 볼 수 없습니다.

## 다음 실행

자격 증명이 준비되면 아래 명령을 실행합니다.

```sh
scripts/finalize-testflight-release.sh
```

이후 App Store Connect에서 빌드 processing이 끝나면 `docs/testflight-qa-plan.md`로 두 기기 QA를 진행합니다.
