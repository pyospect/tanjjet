# Tanjjet - 커플 위젯 앱

커플이 서로에게 짧은 메시지를 보내고, 상대방의 잠금화면 위젯에 표시되는 iOS 앱입니다.

## 기술 스택

- **Frontend:** Swift, SwiftUI
- **Backend/DB:** Supabase (PostgreSQL, Auth, Realtime)
- **의존성 관리:** Swift Package Manager (SPM)
- **Widget:** WidgetKit (Accessory Rectangular)

## 프로젝트 구조

```
Tanjjet/
├── Tanjjet/                    # 메인 앱
│   ├── TanjjetApp.swift        # App Entry Point
│   ├── ContentView.swift       # 메인 라우팅 뷰
│   ├── Models/                 # 데이터 모델
│   ├── ViewModels/             # 비즈니스 로직
│   ├── Views/                  # UI 뷰
│   ├── Services/               # Supabase 서비스
│   └── Extensions/             # 확장 함수
├── TanjjetWidget/              # 위젯 익스텐션
└── Database/                   # SQL 스키마
```

## 설정 방법

### 1. Xcode 프로젝트 생성

이 저장소는 `project.yml`을 기준으로 Xcode 프로젝트를 재생성합니다.

```sh
xcodegen generate
open Tanjjet.xcodeproj
```

### 2. Apple Developer 설정

앱과 위젯 간 데이터 공유를 위해 App Group을 설정해야 합니다.

- App ID: `com.pyospect.tanjjet`
- Widget App ID: `com.pyospect.tanjjet.widget`
- App Group: `group.com.pyospect.tanjjet`
- 앱 타겟 권한: App Groups, Sign in with Apple, Push Notifications
- 위젯 타겟 권한: App Groups

### 3. Supabase 설정

1. [Supabase](https://supabase.com)에서 새 프로젝트 생성
2. `Database/schema.sql`, `Database/push_notification_schema.sql` 실행
3. 또는 `supabase/migrations/`의 마이그레이션을 `supabase db push`로 적용
4. `send-push-notification`, `delete-account` Edge Function 배포
5. `Tanjjet/Services/SupabaseService.swift`의 Project URL과 Anon Key 확인

### 4. Sign in with Apple (Supabase 설정)

1. Supabase 대시보드 > **Authentication > Providers**
2. **Apple** 활성화
3. Apple Developer Console에서 Service ID 생성 후 설정

## 주요 기능

- **Sign in with Apple**: Supabase Auth와 연동된 애플 로그인
- **커플 페어링**: 6자리 코드로 파트너와 연결
- **메시지 전송**: 파트너에게 짧은 메시지 전송
- **잠금화면 위젯**: 파트너가 보낸 최신 메시지 표시

## 배포 준비

TestFlight 업로드 전 체크리스트는 [`docs/testflight-checklist.md`](docs/testflight-checklist.md)를 확인하세요.

로컬 검증 명령:

```sh
xcodegen generate
xcodebuild test -project Tanjjet.xcodeproj -scheme Tanjjet -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -configuration Debug
xcodebuild -project Tanjjet.xcodeproj -scheme Tanjjet -destination 'generic/platform=iOS Simulator' -configuration Debug build
xcodebuild -project Tanjjet.xcodeproj -scheme Tanjjet -destination 'generic/platform=iOS Simulator' -configuration Release build
xcodebuild -project Tanjjet.xcodeproj -scheme Tanjjet -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

## 라이선스

MIT License
