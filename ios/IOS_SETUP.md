# Running CardCircle on iOS

Everything in this file is a step that has to happen on a Mac with Xcode, or
in a console the repo has no access to. The code-side iOS fixes are already
committed; these are the ones that need a human.

## 1. Firebase — required, push is dead without it

`android/app/google-services.json` exists. There is **no**
`ios/Runner/GoogleService-Info.plist`, so `Firebase.initializeApp()` fails on
iOS. It is wrapped in a try/catch, so the app still runs — it just has no
push notifications, ever, silently.

In the Firebase console, on the same project the Android app uses:

1. Add app → iOS.
2. Bundle ID must be **`com.cardcircle.mobileFlutter`** exactly. Note this is
   *not* the Android id (`com.cardcircle.cardcircle`) — they were set up
   differently and Firebase matches on the exact string.

   > The plist downloaded on 2026-09-11 has `BUNDLE_ID` = `CardCircle.appname`,
   > which matches nothing in this project — it looks like a placeholder typed
   > into the Firebase "Add app" form. Firebase compares that value against
   > the running app's bundle id and refuses to register for FCM when they
   > differ, so that file cannot work as-is. A Firebase app's bundle id is not
   > editable after creation: add a **new** iOS app with the correct id,
   > download its plist, and delete the old app.
3. Download `GoogleService-Info.plist`.
4. Drag it into `ios/Runner/` **in Xcode** (not Finder), with "Copy items if
   needed" ticked and the Runner target checked. Dropping it in via Finder
   leaves it out of the bundle and it will not be found at runtime.

## 2. Push Notifications capability

Three separate things have to line up, which is why this step is fiddly: an
**entitlement** in the app binary, a **provisioning profile** that permits
that entitlement, and an **APNs key** that lets Firebase's servers talk to
Apple's on your behalf. Miss any one and `getAPNSToken()` returns null
forever — which the app now logs as a warning instead of failing silently.

FCM on iOS needs an APNs key and the capability enabled. Without it,
`getAPNSToken()` returns null forever and the app logs a warning instead of
registering (see `lib/core/services/notification_service.dart`).

1. Xcode → Runner target → Signing & Capabilities → **+ Capability** → Push
   Notifications. Let Xcode create `Runner.entitlements` itself; do not
   hand-write it, or signing fails when the provisioning profile doesn't
   carry the entitlement.
2. Same screen → + Capability → Background Modes → tick **Remote
   notifications**. (`UIBackgroundModes` is already in `Info.plist`; the
   capability is what makes the profile allow it.)
3. Apple Developer → Keys → create an **APNs Auth Key** (.p8), then upload it
   in Firebase → Project settings → Cloud Messaging → iOS app.

Push cannot be tested on the Simulator — it has no APNs. Use a real device.

## 3. App Transport Security — temporary, must not ship

The API is plain HTTP on a bare IP (`http://13.205.204.182:8080`). iOS blocks
cleartext by default, which broke **every** request — OTP, feed, cards, all
of it.

`Info.plist` now carries `NSAllowsArbitraryLoads`. This is a deliberate
stopgap, and `NSExceptionDomains` was not used because its keys are matched
as domain names and do not apply reliably to IP literals.

**Before any App Store submission:** put the API behind HTTPS and delete the
whole `NSAppTransportSecurity` block. Apple requires written justification
for `NSAllowsArbitraryLoads` and rejects "our backend has no TLS yet".

The same backend broke Android release builds for the same reason — see
`android/app/src/main/res/xml/network_security_config.xml`, which is scoped
to that one host. Delete it at the same time.

## 4. First build

There is no `ios/Podfile` — CocoaPods has never run here, which suggests iOS
has not been built yet. Flutter generates one on first build:

```bash
flutter pub get
cd ios && pod install && cd ..
flutter run -d <your-iphone>
```

If `pod install` complains about the deployment target, the Xcode project is
already set to iOS 13.0 (what firebase_core 3.x needs); make the generated
Podfile's `platform :ios` line match.

## 5. Signing

`PRODUCT_BUNDLE_IDENTIFIER` is `com.cardcircle.mobileFlutter`. Set a
development team in Xcode → Signing & Capabilities before running on a
device.
