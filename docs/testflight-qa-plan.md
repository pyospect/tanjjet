# Tanjjet TestFlight QA Plan

Last updated: 2026-05-05

Use this plan after a build is available in TestFlight. Tanjjet is a two-person app, so the core QA path needs either two physical iPhones or two testers with separate Apple accounts.

## Test Setup

- Install the same TestFlight build on both devices.
- Use two different Apple accounts for Sign in with Apple.
- Allow push notifications on at least one device, and preferably both.
- Add the `딴젯` accessory rectangular widget to the lock screen on at least one device.
- Keep `docs/testflight-checklist.md` open for release gates and environment checks.

## Pass Criteria

- A new user can sign in, set or skip a nickname, and reach pairing.
- A pair can connect through a 6-character code without manual database edits.
- A message sent by one user appears for the partner in the app, on refresh, and in the lock-screen widget.
- Push notifications are delivered to the partner when notification permission is granted.
- Invalid inputs and failure states show clear Korean error messages and do not trap the user.
- Disconnect, logout, and account deletion leave the app in a recoverable signed-out or pairing state.
- No release build exposes message content, device tokens, pairing codes, or nicknames in app logs.

## Smoke Test Matrix

| Area | Scenario | Expected result |
| --- | --- | --- |
| First launch | Open the app after a fresh install | Loading resolves to Sign in with Apple without a crash |
| Sign in | Complete Sign in with Apple | User lands on nickname or pairing flow |
| Nickname | Enter 1 to 10 characters and save | Name appears in the pairing or main header |
| Nickname validation | Try an empty nickname or more than 10 characters | Save is blocked or an error is shown |
| Pairing code | Device A taps `내 코드 만들기` | A 6-character code appears and can be copied |
| Invalid pairing | Device B enters fewer than 6 characters | `6자리 코드를 입력해주세요` appears |
| Invalid pairing | Device B enters a random unused 6-character code | A clear failure message appears |
| Valid pairing | Device B enters Device A's code | Both devices resolve into the main message view |
| Message length | Try sending an empty message | Nothing is sent and the input remains usable |
| Message length | Try sending more than 100 characters | `100자 이내로 입력해주세요` appears |
| Messaging | Device A sends a valid message | The message appears locally and later on Device B |
| Realtime | Keep Device B open while Device A sends | Device B updates without relaunching |
| Refresh | Pull to refresh on Device B | The latest messages remain consistent |
| Widget | Add the lock-screen widget on Device B | The latest partner message appears after send or refresh |
| Push | Device A sends while Device B allows notifications | Device B receives a push notification |
| Badge | Open Device B after receiving a push notification | The app badge clears after launch or foregrounding |
| Foreground push | Keep Device B open while Device A sends | Device B shows the banner/sound path without leaving a stale app badge |
| Permission | Tap the notification permission banner | iOS permission prompt appears and app remains usable |
| Logout | Log out from the overflow menu | App returns to Sign in with Apple |
| Disconnect | Use `연결 해제` from the overflow menu | Widget data clears and user returns to pairing |
| Re-pair | Pair the same users again after disconnect | Main message view works again |
| Delete account | Use `회원 탈퇴` and confirm | User is signed out and profile state is removed |
| Reinstall | Delete and reinstall the app | App starts cleanly without stale widget/app group state |

## App Store Reviewer Flow

Use this condensed flow in App Store Connect review notes if screenshots or reviewer instructions need a shorter version:

1. Sign in with Apple on two devices or two Apple accounts.
2. On the first device, create a pairing code.
3. On the second device, enter the pairing code.
4. Send a short message from either device.
5. Confirm the partner sees the message in the app and lock-screen widget.
6. Optionally allow push notifications to verify notification delivery.

## Known External Gates

- TestFlight upload still needs App Store Connect access for team `4Q2Q7M7G5X`, or the App Store Connect API key environment variables documented in `docs/testflight-checklist.md`.
- Final App Store submission still needs the Supabase SQL migration so strict remote verification passes with `REQUIRE_DISCONNECT_RPC=1 scripts/verify-supabase-remote.sh`.
- The PR must be merged to `master` before final submission so GitHub Pages publishes the latest privacy policy and support pages.
