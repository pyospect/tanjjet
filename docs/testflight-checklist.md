# Tanjjet TestFlight Checklist

Last checked: 2026-05-05

## Verified Locally

- Unit tests pass: 8 tests, 0 failures.
- Debug simulator build passes.
- Release simulator build passes.
- Release iPhoneOS build passes with code signing disabled.
- App and widget `CFBundleVersion` now match.
- App and widget include `PrivacyInfo.xcprivacy` for App Group `UserDefaults`; the app manifest also declares User ID, Name, Other User Content, and Device ID as linked app-functionality data, with no tracking.
- Push entitlement is `development` for Debug and `production` for Release.
- Source entitlements include App Groups for app/widget, Sign in with Apple for the app, and production APNs for Release.
- App target is iPhone-only (`TARGETED_DEVICE_FAMILY = 1`) so the current iPhone screenshot set matches the submitted device family.
- App Store icon is `1024 x 1024` with no alpha channel.
- App no longer implements remote-notification background fetch without declaring a matching background mode.
- Supabase Edge Functions are deployed:
  - `send-push-notification` v4
  - `delete-account` v2
  - `disconnect-couple` v1
- Supabase Function secrets are present for APNs, Supabase keys, and `BUNDLE_ID`.
- Push Edge Function responses and logs do not expose stored APNs device tokens.
- App disconnect flow uses the `disconnect-couple` Edge Function first, with DB RPC fallback for projects where `disconnect_couple` is installed.
- Remote verification confirms `join_couple` exists for the pairing flow.
- Database hardening removes direct user UPDATE access to `couples`; pairing changes go through RPC or the disconnect Edge Function.
- `scripts/verify-release.sh` passes using repo-local `build/DerivedData`.
- GitHub Actions `Release Verification` runs the same release verification on pull requests and release-branch pushes.
- `scripts/archive-testflight.sh` creates `build/Tanjjet.xcarchive` using repo-local `build/ArchiveDerivedData`.
- Release/TestFlight builds do not emit app logs directly; app logging is routed through DEBUG-only `AppLogger`, with message bodies, device tokens, pairing codes, and nicknames removed from log messages.

## Commands

Korean handoff guide for the final credential-gated steps:

```text
docs/release-handoff-ko.md
```

```sh
scripts/verify-release.sh
```

The verification script clears and uses `build/DerivedData` by default so Xcode's global DerivedData cache does not corrupt or contend with package checkouts. Override with `DERIVED_DATA_PATH=...` if needed.

If the machine has a specific simulator you want to use:

```sh
SIMULATOR_DESTINATION='platform=iOS Simulator,id=...' scripts/verify-release.sh
```

Archive command after Apple account/provisioning is ready:

```sh
scripts/archive-testflight.sh
```

The archive script clears the default `build/Tanjjet.xcarchive` and `build/ArchiveDerivedData` before rebuilding so repeated release attempts stay deterministic.

Upload the archive to App Store Connect internal TestFlight:

```sh
scripts/upload-testflight.sh
```

The upload script writes its export log to `build/testflight-upload.log` by default. Override with `UPLOAD_LOG=...` if needed.

If Xcode is not signed in to an App Store Connect account for the team, upload with an App Store Connect API key:

```sh
APP_STORE_CONNECT_API_KEY_PATH=/path/to/AuthKey_XXXXXX.p8 \
APP_STORE_CONNECT_API_KEY_ID=XXXXXX \
APP_STORE_CONNECT_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx \
scripts/upload-testflight.sh
```

Final readiness audit after archive creation and before TestFlight/App Store release:

```sh
scripts/release-readiness-audit.sh
```

This script checks the current archive, App Store Connect authentication readiness, strict Supabase remote state, public support/privacy URLs, and PR state. It exits non-zero while an external blocker remains.

Once Supabase DB access and App Store Connect access are ready, run the full final pipeline:

```sh
SUPABASE_DB_PASSWORD=... scripts/finalize-testflight-release.sh
```

Alternatively, copy `.env.release.example` to `.env.release`, fill in the real Supabase and App Store Connect values, and run:

```sh
scripts/finalize-testflight-release.sh
```

All release scripts automatically load `.env.release` when it exists. Set `RELEASE_ENV_FILE=/path/to/env` if you want to use a different ignored env file.
If you fixed App Store Connect by signing in through Xcode instead of using an API key, run `ASSUME_XCODE_ACCOUNT_READY=1 scripts/finalize-testflight-release.sh` to ignore the previous upload-failure log during preflight.

The final pipeline checks or applies the strict Supabase migration, runs release verification, recreates the archive, uploads to TestFlight, and then reruns the release-readiness audit.

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

For an existing Supabase project where only the hardening changes are missing, run this migration in the SQL editor:

```text
supabase/migrations/20260505041000_pairing_push_account_hardening.sql
```

After applying SQL manually or through the CLI, verify the remote project:

```sh
scripts/verify-supabase-remote.sh
```

Deploy or redeploy the Edge Functions:

```sh
supabase functions deploy send-push-notification --project-ref wxlfukoozmuwslppmkaf --use-api
supabase functions deploy delete-account --project-ref wxlfukoozmuwslppmkaf --use-api
supabase functions deploy disconnect-couple --project-ref wxlfukoozmuwslppmkaf --use-api
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

Remote DB note: `join_couple` exists and responds, but `disconnect_couple` was not present in the remote PostgREST schema cache during verification. The app now uses the `disconnect-couple` Edge Function for the disconnect flow, but the SQL migration should still be applied before final App Store submission for schema and RLS hardening.

## App Store Connect

- Create the app record with bundle id `com.pyospect.tanjjet`.
- Use `docs/app-store-connect-metadata.md` as the first draft for app information, description, keywords, review notes, and privacy-label mapping.
- Use `docs/testflight-qa-plan.md` for the two-device TestFlight smoke test before submitting for App Review.
- Confirm privacy labels match the app behavior:
  - Account/user identifier through Sign in with Apple and Supabase Auth.
  - User-provided nickname as Name.
  - User-generated messages as Other User Content.
  - Device token for push notifications as Device ID.
- Confirm the hosted support and privacy-policy URLs before submission. GitHub Pages is already configured from `master` branch `/docs`, so merge this PR before final App Store submission to publish the updated privacy policy.
- Upload screenshots from `screenshots/` or capture updated ones after UI review.
- Current screenshots are `1242 x 2688`, an accepted portrait size for Apple's 6.5-inch iPhone slot when 6.9-inch screenshots are not provided.
- Add a tester note explaining that the app requires two accounts or two devices to verify pairing.

## Current Blockers

Archive now succeeds locally at `build/Tanjjet.xcarchive`, but App Store Connect upload is blocked by account access. The latest upload attempt failed with:

```text
App Store Connect access for “4Q2Q7M7G5X” is required.
```

Sign in to Xcode with an Apple account that has App Store Connect access for team `4Q2Q7M7G5X`, or rerun `scripts/upload-testflight.sh` with the App Store Connect API key environment variables shown above.

Remote database schema application is still blocked until the Supabase database password is available to the CLI or the SQL is run manually in the Supabase SQL editor. TestFlight disconnect now has an Edge Function path, but final database hardening still needs the SQL migration.
