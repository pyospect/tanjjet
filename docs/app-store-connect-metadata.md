# Tanjjet App Store Connect Metadata Draft

Last updated: 2026-05-05

## App Information

- App name: 딴젯
- Subtitle: 커플을 위한 잠금화면 메시지 위젯
- Primary category: Lifestyle
- Secondary category: Social Networking
- Bundle ID: `com.pyospect.tanjjet`
- SKU: `tanjjet-ios`
- Version: `1.0.0`
- Build: `6`

## Promotional Text

파트너가 보낸 짧은 메시지를 잠금화면 위젯에서 바로 확인하세요.

## Description

딴젯은 커플이 서로에게 짧은 메시지를 보내고, 상대방의 잠금화면 위젯에서 확인할 수 있는 iOS 앱입니다.

6자리 페어링 코드로 파트너와 연결한 뒤, 지금 전하고 싶은 말을 간단히 보내보세요. 앱을 열지 않아도 잠금화면 위젯에서 파트너의 최신 메시지를 확인할 수 있습니다.

주요 기능:
- Sign in with Apple을 통한 간편 로그인
- 6자리 코드 기반 커플 페어링
- 100자 이내 짧은 메시지 전송
- 잠금화면 위젯에서 최신 파트너 메시지 확인
- 새 메시지 푸시 알림
- 연결 해제 및 회원 탈퇴 기능

딴젯은 복잡한 피드나 공개 프로필 없이, 연결된 두 사람 사이의 짧은 메시지에 집중합니다.

## Keywords

커플,위젯,잠금화면,메시지,연인,애인,커플앱,알림,소통,딴젯

## Support And Privacy URLs

- Support URL: `https://pyospect.github.io/tanjjet/support.html`
- Privacy Policy URL: `https://pyospect.github.io/tanjjet/privacy-policy.html`

GitHub Pages is configured from `master` branch `/docs` and currently serves these URLs. Merge this PR to `master` before final submission so the updated privacy policy is published.

## Review Notes

딴젯은 두 계정이 6자리 코드로 페어링된 뒤 메시지를 주고받는 앱입니다.

Review flow:
1. Sign in with Apple로 로그인합니다.
2. 첫 번째 기기 또는 계정에서 페어링 코드를 생성합니다.
3. 두 번째 기기 또는 계정에서 해당 코드를 입력해 연결합니다.
4. 한쪽에서 메시지를 보내면 상대방 앱과 잠금화면 위젯에서 최신 메시지를 확인할 수 있습니다.

Testing note:
- 페어링과 메시지 흐름을 확인하려면 두 개의 Apple 계정 또는 두 기기가 필요합니다.
- 푸시 알림은 사용자가 알림 권한을 허용한 뒤 동작합니다.

No demo account is available because the app uses Sign in with Apple.

## App Privacy Label Draft

Data linked to the user:
- User ID: Sign in with Apple and Supabase Auth user identifier.
- Name: nickname entered by the user.
- Other User Content: messages sent to the paired partner.
- Device ID: push notification device token, used only for message notifications.

Purposes:
- App Functionality: authentication, pairing, messaging, widget display, push notifications.

The app privacy manifest mirrors this mapping with `UserID`, `Name`, `OtherUserContent`, and `DeviceID`, all linked to the user, not used for tracking, and used only for app functionality.

Tracking:
- No tracking.
- No third-party advertising.

## Screenshot Checklist

The app is configured as iPhone-only (`TARGETED_DEVICE_FAMILY = 1`). Use the existing iPhone screenshots for TestFlight/App Store setup, and recapture the same slots if the final TestFlight build changes visually:
- `screenshots/screenshot_1_lockscreen.png`
- `screenshots/screenshot_2_pairing.png`
- `screenshots/screenshot_3_message.png`

The current files are `1242 x 2688`, which is an accepted portrait size for Apple's 6.5-inch iPhone screenshot slot when 6.9-inch screenshots are not provided: <https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/>.

Before App Store submission, confirm screenshots match the final TestFlight build and actual App Store Connect slots.
