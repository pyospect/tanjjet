# 딴젯 TestFlight 릴리즈 인수인계

Last checked: 2026-05-05

이 문서는 개발자가 아닌 사람이 마지막 릴리즈 단계를 이어서 진행할 수 있도록 정리한 한국어 가이드입니다. 실제 앱 코드, 빌드, 문서, 감사 스크립트는 준비되어 있고, 현재 남은 작업은 외부 계정/DB 권한이 필요한 두 가지입니다.

## 현재 상태

- PR: https://github.com/pyospect/tanjjet/pull/1
- 브랜치: `codex/testflight-readiness`
- 앱 버전: `1.0.0`
- 빌드 번호: `6`
- 최신 릴리즈 검증: GitHub Actions `Verify iOS Release Build` 통과
- 로컬 최종 감사: 실패 0개, 외부 블로커 2개

## 남은 블로커

### 1. App Store Connect 접근

TestFlight 업로드를 하려면 둘 중 하나가 필요합니다.

- Xcode에 team `4Q2Q7M7G5X` 권한이 있는 Apple 계정으로 로그인
- 또는 App Store Connect API 키 3종 준비

API 키로 진행할 경우 `.env.release`에 아래 값을 넣습니다.

```sh
APP_STORE_CONNECT_API_KEY_PATH=/absolute/path/to/AuthKey_XXXXXX.p8
APP_STORE_CONNECT_API_KEY_ID=XXXXXX
APP_STORE_CONNECT_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

Xcode 로그인으로 진행할 경우에는 위 API 키 placeholder를 그대로 둬도 됩니다. 릴리즈 스크립트는 예시값을 실제 키로 오인하지 않고, 아래의 `ASSUME_XCODE_ACCOUNT_READY=1` 옵션이 있을 때 Xcode 로그인 계정으로 업로드를 시도합니다.

주의: `.env.release`는 git에 올리면 안 됩니다. 이미 `.gitignore`에 포함되어 있으니 그대로 사용하면 됩니다.

### 2. Supabase DB 마이그레이션

Supabase 원격 DB에 `disconnect_couple` RPC가 아직 없어 strict gate가 실패합니다. 둘 중 하나로 해결합니다.

- Supabase SQL editor에서 아래 파일 내용을 실행
  - `supabase/migrations/20260505041000_pairing_push_account_hardening.sql`
- 또는 DB 비밀번호를 사용해 CLI로 적용

```sh
SUPABASE_DB_PASSWORD=... scripts/apply-supabase-db.sh
```

SQL editor에서 수동으로 실행했다면, 같은 SQL editor에서 아래 확인 쿼리를 실행해 `disconnect_couple` 행이 나오는지 먼저 보면 됩니다.

```sql
select proname, pg_get_function_arguments(oid) as arguments
from pg_proc
where pronamespace = 'public'::regnamespace
and proname in ('join_couple', 'disconnect_couple')
order by proname;
```

## 권장 진행 순서

1. `.env.release.example`을 `.env.release`로 복사합니다.

```sh
cp .env.release.example .env.release
```

현재 이 작업공간에는 `.env.release`가 이미 만들어져 있습니다. 새 Mac이나 새 clone에서만 위 복사 명령을 다시 실행하면 됩니다.

2. `.env.release`에 실제 값을 채웁니다.

```sh
SUPABASE_DB_PASSWORD=...
APP_STORE_CONNECT_API_KEY_PATH=/absolute/path/to/AuthKey_XXXXXX.p8
APP_STORE_CONNECT_API_KEY_ID=XXXXXX
APP_STORE_CONNECT_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

Xcode 로그인 방식으로 App Store Connect를 해결한다면 `APP_STORE_CONNECT_*` 값은 예시값 그대로 두고, `SUPABASE_DB_PASSWORD`만 채워도 됩니다. Supabase SQL editor에서 migration을 직접 실행했다면 `SUPABASE_DB_PASSWORD`도 비워둘 수 있습니다.

3. 자격 증명만 먼저 빠르게 확인합니다.

```sh
scripts/check-release-credentials.sh
```

이 명령은 로컬 디스크 여유 공간도 함께 확인합니다. 최종 빌드 전에 기본 4096 MB 이상을 요구하며, 의도적으로 기준을 바꾸려면 `MIN_FREE_SPACE_MB=...`를 붙여 실행할 수 있습니다.

4. 최종 파이프라인을 실행합니다.

```sh
scripts/finalize-testflight-release.sh
```

이 스크립트는 아래 순서로 실행됩니다.

- Supabase strict remote gate 확인 또는 마이그레이션 적용
- Release 빌드/테스트 검증
- 재생성 가능한 DerivedData 캐시 정리
- TestFlight용 archive 생성
- App Store Connect/TestFlight 업로드
- 최종 릴리즈 감사

## Xcode 로그인으로 진행하는 경우

API 키 대신 Xcode 로그인으로 App Store Connect 접근을 해결했다면 아래처럼 실행합니다.

```sh
ASSUME_XCODE_ACCOUNT_READY=1 scripts/check-release-credentials.sh
ASSUME_XCODE_ACCOUNT_READY=1 scripts/finalize-testflight-release.sh
```

이 옵션은 예전 업로드 실패 로그 때문에 preflight가 멈추는 것을 건너뜁니다. 실제 업로드 권한이 없으면 업로드 단계에서 다시 실패합니다.

Supabase SQL editor에서 migration을 직접 실행했다면, 최종 파이프라인 전에 strict gate만 따로 확인할 수 있습니다.

```sh
REQUIRE_DISCONNECT_RPC=1 scripts/verify-supabase-remote.sh
```

이 명령에서 `disconnect_couple RPC exists and responded`가 보이면 Supabase strict blocker가 풀린 상태입니다.

## 성공 후 할 일

1. App Store Connect에서 빌드 processing이 끝날 때까지 기다립니다.
2. 내부 TestFlight 테스터에게 빌드를 배포합니다.
3. `docs/testflight-qa-plan.md`를 따라 두 기기 또는 두 계정으로 핵심 플로우를 확인합니다.
4. PR을 `master`로 merge해서 GitHub Pages의 개인정보 처리방침/지원 페이지를 최신 상태로 배포합니다.
5. App Store Connect metadata는 `docs/app-store-connect-metadata.md`를 기준으로 입력합니다.

## 문제가 생겼을 때 보는 파일

- 최종 릴리즈 체크리스트: `docs/testflight-checklist.md`
- TestFlight QA 플랜: `docs/testflight-qa-plan.md`
- App Store Connect 입력 초안: `docs/app-store-connect-metadata.md`
- 최종 감사 스크립트: `scripts/release-readiness-audit.sh`
- TestFlight 업로드 로그: `build/testflight-upload.log`
