# Release automation

One command builds and ships both stores:

```sh
./scripts/deploy_mobile_version.sh
```

It ships one platform at a time: build the AAB → upload it to Play internal
testing → build the IPA → upload it to TestFlight. If the iOS half fails, the
Android release has already landed; fix it and re-run with `--ios-only`.

**The version in `pubspec.yaml` is never modified.** Set it yourself before
running. Both stores permanently burn a build number the moment it is
uploaded to any track, so raising the `+N` is a deliberate decision — you will
get a rejection ("version code already used" / "bundle version must be
higher") if you re-run without changing it.

```
--android-only     --ios-only     --check
--skip-build       --track beta   --notes "Fixed the startup crash"
```

`--check` runs preflight and stops — no build, no network calls, nothing
uploaded. Use it to confirm credentials before committing to a long run.
Note that `--skip-build` is **not** a dry run: it skips compiling but still
uploads whatever is already in `build/`.

Expect **15–35 minutes** end to end; the TestFlight upload and Apple's
processing are the slow parts.

---

## One-time setup

### 1. Secrets

There is no config file. The script reads everything from the environment:

| Variable | Default |
|---|---|
| `APPLE_APP_SPECIFIC_PASSWORD` | **required** — already exported in your shell profile |
| `APPLE_ID` | `ahmedmagdymohamedy@gmail.com` |
| `PLAY_SERVICE_ACCOUNT_JSON` | `scripts/play-service-account.json` |
| `ASC_PROVIDER` | unset — only needed with multiple Apple teams |

`scripts/*.json` is gitignored so the Play key never gets committed.

### 2. App Store Connect app record

TestFlight can only accept a build for an app that already exists:

1. <https://appstoreconnect.apple.com> → **My Apps** → **+** → **New App**
2. Platform **iOS**, bundle ID **`com.megz.coloro`**, pick an SKU (any string)

You do *not* need to fill in the store listing to use TestFlight — the app
record is enough.

### 3. Google Play service account

The full step-by-step is in the section below.

---

## Creating the Google Play service account

This is what lets the script upload without you logging in. Two halves:
create the key in **Google Cloud**, then grant it access in **Play Console**.

### Part A — Google Cloud (make the key)

1. Go to <https://console.cloud.google.com>
2. Create a project (or select any existing one) — name it e.g. `coloro-deploy`.
   The project is only a container for the key; it costs nothing.
3. **APIs & Services** → **Library** → search **"Google Play Android Developer API"**
   → open it → **Enable**.
   *Skipping this is the #1 cause of `403` on first run.*
4. **IAM & Admin** → **Service Accounts** → **Create service account**
   - Name: `coloro-play-deploy`
   - **Skip** the "Grant this service account access to project" step — it
     needs no GCP roles, only Play Console permissions.
   - **Done**
5. Click the new service account → **Keys** tab → **Add key** → **Create new key**
   → **JSON** → **Create**. A `.json` file downloads.
6. Move it into the project and point the script at it:
   ```sh
   mv ~/Downloads/coloro-deploy-*.json scripts/play-service-account.json
   ```
7. Copy the `client_email` from that file — it looks like
   `coloro-play-deploy@coloro-deploy.iam.gserviceaccount.com`.

### Part B — Play Console (grant it access)

8. Go to <https://play.google.com/console> → **Users and permissions**
   (left sidebar, near the bottom).
9. **Invite new user** → paste the `client_email` from step 7 as the email.
10. **App permissions** → **Add app** → select **Coloro**.
11. Give it at least:
    - ✅ **Release to testing tracks** (required)
    - ✅ **View app information and download bulk reports** (required)
    - ✅ *Release to production* — only if you ever want `--track production`
12. **Invite user**. It applies immediately — there is no email to accept.

> **Older Play Console UI:** if you don't see the invite flow above, the
> equivalent lives under **Setup → API access**, where you link the Cloud
> project and grant access to the service account there instead.

### Verify

```sh
./scripts/deploy_mobile_version.sh --android-only --no-bump --skip-build
```

If the credentials are wrong you'll get a named error before anything uploads.

---

## Notes

- **The first upload to each store must be manual.** Play already has Coloro
  (you uploaded an AAB to internal testing), so Play is ready. For iOS, step 3
  above creates the record — after that the script handles every build.
- **Play version codes are permanent.** Once a code is uploaded to *any*
  track, Play refuses it forever. That's why the script bumps by default; use
  `--no-bump` only when re-running after a failed upload.
- **`status: "completed"`** in the track update means the release goes live to
  internal testers immediately. Change it to `"draft"` in the script if you'd
  rather review in the Console first.
- **Secrets** are read from `scripts/.env` and never echoed. The script does
  not use `set -x` for that reason.
- **`altool` is on Apple's way out.** It works in current Xcode. If a future
  Xcode removes it, the script fails preflight with a pointer to Transporter
  and `iTMSTransporter`.
- **iOS uses Swift Package Manager, not CocoaPods.** Every plugin this app
  uses ships as a Swift Package, so there is deliberately no `Podfile`. Do not
  add one back — Flutter generates one automatically if a future plugin ever
  needs it. `pod install` is not part of the release flow.
- **Team ID is checked in preflight.** `ios/ExportOptions.plist` and
  `Runner.xcodeproj` must name the same team (currently `7TR5648CPX`). If they
  drift, the archive builds fine and then fails at export, so the script
  compares them up front instead.
