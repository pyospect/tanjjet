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
4. `send-push-notification`, `delete-account`, `disconnect-couple` Edge Function 배포
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
App Store Connect 입력 초안은 [`docs/app-store-connect-metadata.md`](docs/app-store-connect-metadata.md)에 정리되어 있습니다.
TestFlight 설치 후 수동 QA 시나리오는 [`docs/testflight-qa-plan.md`](docs/testflight-qa-plan.md)를 사용하세요.

로컬 검증 명령:

```sh
scripts/verify-release.sh
```

Archive와 TestFlight 업로드:

```sh
scripts/archive-testflight.sh
scripts/upload-testflight.sh
```

Supabase DB 비밀번호와 App Store Connect 권한이 모두 준비된 뒤에는 전체 마무리 흐름을 한 번에 실행할 수 있습니다.

```sh
SUPABASE_DB_PASSWORD=... scripts/finalize-testflight-release.sh
```

여러 값을 반복 입력하기 싫다면 `.env.release.example`을 `.env.release`로 복사한 뒤 실제 값을 채워도 됩니다. `.env.release`는 git에 올라가지 않도록 무시됩니다.

최종 배포 직전에는 현재 아카이브, App Store Connect 인증, Supabase strict gate, 공개 문서 URL을 한 번에 확인합니다.

```sh
scripts/release-readiness-audit.sh
```

Xcode에 App Store Connect 권한이 있는 계정이 없으면, App Store Connect API 키 환경변수와 함께 업로드할 수 있습니다. 자세한 값 이름은 체크리스트를 확인하세요.

## 라이선스

MIT License
