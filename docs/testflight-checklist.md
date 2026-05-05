# Tanjjet TestFlight Checklist

Last checked: 2026-05-05

## Verified Locally

- Unit tests pass: 6 tests, 0 failures.
- Debug simulator build passes.
- Release simulator build passes.
- Release iPhoneOS build passes with code signing disabled.
- App and widget `CFBundleVersion` now match.
- App and widget include `PrivacyInfo.xcprivacy` for App Group `UserDefaults`.
- Push entitlement is `development` for Debug and `production` for Release.
- App no longer implements remote-notification background fetch without declaring a matching background mode.
- Supabase Edge Functions are deployed:
  - `send-push-notification` v2
  - `delete-account` v1
- Supabase Function secrets are present for APNs, Supabase keys, and `BUNDLE_ID`.

## Commands

```sh
scripts/verify-release.sh
```

If the machine has a specific simulator you want to use:

```sh
SIMULATOR_DESTINATION='platform=iOS Simulator,id=...' scripts/verify-release.sh
```

Archive command after Apple account/provisioning is ready:

```sh
scripts/archive-testflight.sh
```

Upload the archive to App Store Connect internal TestFlight:

```sh
scripts/upload-testflight.sh
```

If Xcode is not signed in to an App Store Connect account for the team, upload with an App Store Connect API key:

```sh
APP_STORE_CONNECT_API_KEY_PATH=/path/to/AuthKey_XXXXXX.p8 \
APP_STORE_CONNECT_API_KEY_ID=XXXXXX \
APP_STORE_CONNECT_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx \
scripts/upload-testflight.sh
```

## Apple Developer Setup

- Add the Apple Developer account in Xcode settings.
- Register app id `com.pyospect.tanjjet`.
- Register widget app id `com.pyospect.tanjjet.widget`.
- Enable these capabilities on the app id:
  - App Groups
  - Sign in with Apple
  - Push Notifications
- Enable App Groups on the widget app id.
- Register App Group `group.com.pyospect.tanjjet` and attach it to both app ids.
- Create or refresh App Store provisioning profiles for both targets.
- Archive from Xcode and upload through Organizer, or use `xcodebuild -exportArchive` after archive succeeds.

## Supabase Setup

Run these SQL files in the Supabase SQL editor:

```text
Database/schema.sql
Database/push_notification_schema.sql
```

Or apply the CLI migration after linking with the database password:

```sh
SUPABASE_DB_PASSWORD=... scripts/apply-supabase-db.sh
```

Deploy or redeploy the Edge Functions:

```sh
supabase functions deploy send-push-notification --project-ref wxlfukoozmuwslppmkaf --use-api
supabase functions deploy delete-account --project-ref wxlfukoozmuwslppmkaf --use-api
```

Set these function secrets:

```sh
supabase secrets set SUPABASE_ANON_KEY=... --project-ref wxlfukoozmuwslppmkaf
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=... --project-ref wxlfukoozmuwslppmkaf
supabase secrets set APNS_KEY_ID=... --project-ref wxlfukoozmuwslppmkaf
supabase secrets set APNS_TEAM_ID=... --project-ref wxlfukoozmuwslppmkaf
supabase secrets set APNS_PRIVATE_KEY='-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----' --project-ref wxlfukoozmuwslppmkaf
supabase secrets set BUNDLE_ID=com.pyospect.tanjjet --project-ref wxlfukoozmuwslppmkaf
```

For TestFlight and App Store, keep `APNS_HOST` unset or set it to `api.push.apple.com`.

Local note: Deno was not installed on the verification machine, so Edge Functions were reviewed in source form but not run locally.

Remote DB note: `join_couple` exists, but `disconnect_couple` was not present in the remote PostgREST schema cache during verification. Apply the SQL or migration before TestFlight testing the disconnect flow.

## App Store Connect

- Create the app record with bundle id `com.pyospect.tanjjet`.
- Confirm privacy labels match the app behavior:
  - Account/user identifier through Sign in with Apple and Supabase Auth.
  - User-provided nickname.
  - User-generated messages.
  - Device token for push notifications.
- Upload screenshots from `screenshots/` or capture updated ones after UI review.
- Add a tester note explaining that the app requires two accounts or two devices to verify pairing.

## Current Blockers

Archive now succeeds locally at `build/Tanjjet.xcarchive`, but App Store Connect upload is blocked by account access. The latest upload attempt failed with:

```text
Failed to find an account with App Store Connect access for team 4Q2Q7M7G5X
```

Sign in to Xcode with an Apple account that has App Store Connect access for team `4Q2Q7M7G5X`, or rerun `scripts/upload-testflight.sh` with the App Store Connect API key environment variables shown above.

Remote database schema application is also blocked until the Supabase database password is available to the CLI or the SQL is run manually in the Supabase SQL editor.
