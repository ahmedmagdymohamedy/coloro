# Meta (Facebook) App Events — status and how to finish

**Status: blocked on one click that only Ahmed can make.**

## What happened

The Coloro app was configured end-to-end at
<https://developers.facebook.com/apps/creation/>:

| Field | Value |
|---|---|
| App name | `Coloro` |
| Contact email | `ahmedmagdymohamedy@gmail.com` |
| Use case | *Create and manage app ads through Meta Ads Manager* (app installs — no Marketing API) |
| Business portfolio | none (none exists on the account; can be linked later) |
| Requirements | none |

At the final **Create app** step Meta demanded the account password again for
re-authentication. **I do not enter passwords into any field** — so the app
was not created, the dialog was cancelled, and the account was left exactly
as it was (still 16 apps, no half-created `Coloro`).

## Step 1 — create the app (2 minutes, Ahmed)

1. Go to <https://developers.facebook.com/apps/creation/>
2. Name `Coloro`, email `ahmedmagdymohamedy@gmail.com` → **Next**
3. Use case: **Create and manage app ads through Meta Ads Manager** → **Next**
4. Business portfolio: skip → **Next** → **Next** → **Create app**
5. Enter the password when asked.

Then copy two values from **App settings → Basic**:
- **App ID** (a long number)
- **Client Token** (under *Client token*)

## Step 2 — add the SDK

```sh
flutter pub add facebook_app_events
```

**Android only.** Do not add it to the iOS target yet, for two specific
reasons recorded in this repo:

1. `ios/` is deliberately **Swift Package Manager only, with no Podfile**
   (`scripts/README.md`). `facebook_app_events` would drag CocoaPods back
   into the iOS build, which is not something to discover on a release night.
2. `ios/Runner/Info.plist` carries a comment recording that App Store Connect
   **already refused a submission once** over tracking signals, and the fix
   was removing `NSUserTrackingUsageDescription` entirely. The Facebook SDK
   reintroduces exactly that class of signal. Adding it to iOS needs a real
   ATT + UMP consent flow and its own submission, not a drive-by.

Android wiring — `android/app/src/main/AndroidManifest.xml`, inside
`<application>`:

```xml
<meta-data android:name="com.facebook.sdk.ApplicationId"
           android:value="@string/facebook_app_id" />
<meta-data android:name="com.facebook.sdk.ClientToken"
           android:value="@string/facebook_client_token" />
<!-- Manual init: the game decides when the SDK starts, so a missing or
     wrong id can never take the app down on launch. -->
<meta-data android:name="com.facebook.sdk.AutoInitEnabled"
           android:value="false" />
```

and `android/app/src/main/res/values/strings.xml`:

```xml
<resources>
  <string name="facebook_app_id">PASTE_APP_ID</string>
  <string name="facebook_client_token">PASTE_CLIENT_TOKEN</string>
</resources>
```

## Step 3 — switch it on (one file)

Everything else is already written. `lib/core/analytics/meta_events.dart`
defines the funnel and a `MetaEventSink` transport;
`lib/core/analytics/analytics_service.dart` already fans every relevant event
out to it. The layer is inert until `configure()` is called, which is why it
is safe in today's release.

Add the sink and call it from `main.dart`:

```dart
// lib/core/analytics/facebook_sink.dart
import 'dart:io';
import 'package:facebook_app_events/facebook_app_events.dart';
import 'meta_events.dart';

class FacebookSink implements MetaEventSink {
  final _fb = FacebookAppEvents();
  @override
  void logEvent(String name, Map<String, Object> parameters) {
    _fb.logEvent(name: name, parameters: parameters);
  }
}

// in main.dart, after Firebase init:
if (!kIsWeb && Platform.isAndroid) {
  MetaEvents.instance.configure(FacebookSink());
}
```

Then verify in **Events Manager → Coloro → Test Events** with a debug build.

## The events Meta receives

Deliberately a small, standard-named subset. Meta's ad models have
cross-advertiser priors for standard event names; the game's 365 per-level
Firebase names would mean nothing to them and would only dilute the signal.

| Meta event | Fired when | Why it is in the set |
|---|---|---|
| `fb_mobile_level_achieved` | any level completed | progression depth |
| `fb_mobile_tutorial_completion` | level 1 completed | **activation** — the install-campaign optimisation target until volume allows deeper |
| `fb_mobile_ad_impression` | any full-screen ad shown | the value event: ads are the only revenue |
| `fb_mobile_rewarded_video_completed` | rewarded ad watched | strongest single predictor of a high-value player |
| `fb_mobile_session_milestone` | retention checkpoints | feeds lookalikes of players who stay |

## Note on ads

Ahmed's Meta **ads** account is banned, so none of this is for running Meta
campaigns today. It exists so that the attribution and event history are
already accumulating if that ever changes — an app that starts collecting
events on day one is worth far more to a future campaign than one wired up
the week the campaign launches.
