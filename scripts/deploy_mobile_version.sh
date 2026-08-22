#!/usr/bin/env bash
#
# Coloro — one-command release to Google Play (internal testing) + TestFlight.
#
#   ./scripts/deploy_mobile_version.sh
#
# Each platform is built and shipped before the next one starts:
#   AAB → Play  →  IPA → TestFlight
#
# The version in pubspec.yaml is NEVER modified. Both stores permanently burn
# a build number once it is uploaded, so bumping it is a deliberate decision
# you make by hand before running this.
#
# Secrets come from the environment — nothing is stored in this repo:
#   APPLE_APP_SPECIFIC_PASSWORD   exported from your shell profile
#   PLAY_SERVICE_ACCOUNT_JSON     defaults to scripts/play-service-account.json
# Neither is ever echoed. Setup instructions: scripts/README.md
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# ---------------------------------------------------------------- options ---
DO_ANDROID=1
DO_IOS=1
DO_BUILD=1
CHECK_ONLY=0
TRACK="internal"
RELEASE_NOTES="Automated build."

usage() {
  cat <<'EOF'
Usage: ./scripts/deploy_mobile_version.sh [options]

Builds and ships one platform at a time: AAB → Play, then IPA → TestFlight.
The version in pubspec.yaml is never changed — set it yourself beforehand.

  --android-only      Build + upload the AAB only
  --ios-only          Build + upload the IPA only
  --skip-build        Upload the artifacts already in build/ (no rebuild)
  --check             Run preflight only, then stop. Uploads nothing.
  --track <name>      Play track: internal (default) | alpha | beta | production
  --notes "<text>"    Play release notes (default: "Automated build.")
  -h, --help          Show this help

Environment (override by exporting before the run):
  APPLE_APP_SPECIFIC_PASSWORD   required for TestFlight
  APPLE_ID                      defaults to ahmedmagdymohamedy@gmail.com
  PLAY_SERVICE_ACCOUNT_JSON     defaults to scripts/play-service-account.json
  ASC_PROVIDER                  only if your Apple ID has multiple teams
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --android-only) DO_IOS=0 ;;
    --ios-only)     DO_ANDROID=0 ;;
    --skip-build)   DO_BUILD=0 ;;
    --check)        CHECK_ONLY=1 ;;
    --track)        TRACK="${2:?--track needs a value}"; shift ;;
    --notes)        RELEASE_NOTES="${2:?--notes needs a value}"; shift ;;
    -h|--help)      usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

# ---------------------------------------------------------------- output ----
if [[ -t 1 ]]; then
  B=$'\033[1m'; R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'; C=$'\033[36m'; N=$'\033[0m'
else
  B=""; R=""; G=""; Y=""; C=""; N=""
fi
step() { echo; echo "${B}${C}==>${N} ${B}$*${N}"; }
info() { echo "    $*"; }
ok()   { echo "    ${G}✓${N} $*"; }
warn() { echo "    ${Y}!${N} $*" >&2; }
die()  { echo; echo "${R}✗ $*${N}" >&2; exit 1; }

START_TS=$(date +%s)

# ---------------------------------------------------------------- secrets ---
# All of these can be overridden by exporting them before running the script.
: "${APPLE_ID:=ahmedmagdymohamedy@gmail.com}"
: "${APPLE_APP_SPECIFIC_PASSWORD:=}"
: "${PLAY_SERVICE_ACCOUNT_JSON:=$ROOT/scripts/play-service-account.json}"
: "${ASC_PROVIDER:=}"

AAB="build/app/outputs/bundle/release/app-release.aab"
ANDROID_DONE=""

# --------------------------------------------------------------- preflight --
# Everything both platforms need is checked up front, so a missing iOS
# credential cannot surface only after the Android half has already shipped.
step "Preflight"

need() { command -v "$1" >/dev/null 2>&1 || die "'$1' is not installed. $2"; }
need flutter "Install Flutter and put it on PATH."

PKG=$(grep -Eo 'applicationId[[:space:]]*=[[:space:]]*"[^"]+"' android/app/build.gradle.kts \
      | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
[[ -n "$PKG" ]] || die "Could not read applicationId from android/app/build.gradle.kts"

if (( DO_ANDROID )); then
  need jq "brew install jq"
  need openssl "brew install openssl"
  need curl "curl ships with macOS; check your PATH."
  [[ -f "$PLAY_SERVICE_ACCOUNT_JSON" ]] || die \
    "Play service-account JSON not found at:
    $PLAY_SERVICE_ACCOUNT_JSON
  Create it by following scripts/README.md, or export PLAY_SERVICE_ACCOUNT_JSON=<path>"
  jq -e '.client_email and .private_key' "$PLAY_SERVICE_ACCOUNT_JSON" >/dev/null 2>&1 \
    || die "$PLAY_SERVICE_ACCOUNT_JSON is not a valid service-account key (no client_email/private_key)."
  [[ -f android/key.properties ]] || die \
    "android/key.properties missing — the AAB would be signed with debug keys and Play would reject it."
  ok "Play credentials present · package $PKG · track $TRACK"
fi

if (( DO_IOS )); then
  [[ "$(uname -s)" == "Darwin" ]] || die "iOS builds require macOS."
  need xcrun "Install Xcode and run: xcode-select --install"
  xcrun --find altool >/dev/null 2>&1 || die \
    "xcrun altool is unavailable in this Xcode. Upload manually with Transporter (App Store),
  or switch this script to: xcrun notarytool / iTMSTransporter"
  [[ -n "$APPLE_APP_SPECIFIC_PASSWORD" ]] || die \
    "APPLE_APP_SPECIFIC_PASSWORD is not exported in this shell.
  It lives in your shell profile — open a new terminal, or run:
      export APPLE_APP_SPECIFIC_PASSWORD='xxxx-xxxx-xxxx-xxxx'"
  [[ -f ios/ExportOptions.plist ]] || die "ios/ExportOptions.plist missing."
  # Plugins come from Swift Package Manager, so CocoaPods is not required.
  # The export DOES fail if ExportOptions names a team the project does not
  # sign with, and that failure surfaces only after the whole archive builds.
  exp_team=$(/usr/libexec/PlistBuddy -c 'Print :teamID' ios/ExportOptions.plist 2>/dev/null || true)
  proj_team=$(grep -m1 -oE 'DEVELOPMENT_TEAM = [A-Z0-9]+' ios/Runner.xcodeproj/project.pbxproj \
              | awk '{print $3}')
  if [[ -n "$proj_team" && -n "$exp_team" && "$exp_team" != "$proj_team" ]]; then
    die "Team ID mismatch — the archive would build and then fail to export.
    ios/ExportOptions.plist : $exp_team
    Runner.xcodeproj        : $proj_team
  Set them to the same team."
  fi
  ok "Apple credentials present · $APPLE_ID · team ${proj_team:-unknown}"
fi

# ----------------------------------------------------------------- version --
# Read only. Never written.
VERSION_LINE=$(grep -E '^version:' pubspec.yaml | head -1 | sed -E 's/^version:[[:space:]]*//')
[[ "$VERSION_LINE" == *+* ]] || die "pubspec.yaml version must look like 1.0.0+1 (found: $VERSION_LINE)"
VERSION_NAME="${VERSION_LINE%%+*}"
BUILD_NUMBER="${VERSION_LINE##*+}"

step "Version"
info "${B}${VERSION_NAME}+${BUILD_NUMBER}${N}  (taken from pubspec.yaml as-is)"

if (( CHECK_ONLY )); then
  echo
  echo "${G}Preflight passed.${N} Nothing was built and nothing was uploaded."
  exit 0
fi

if (( DO_BUILD )); then
  flutter pub get >/dev/null
fi

# ------------------------------------------------------------- Play helpers --
PLAY_API="https://androidpublisher.googleapis.com/androidpublisher/v3/applications/$PKG"
PLAY_UPLOAD="https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/$PKG"
API_BODY=""

b64url() { openssl base64 -e -A | tr '+/' '-_' | tr -d '='; }

api() { # method url [json-body] -> API_BODY; nonzero on HTTP error
  local method="$1" url="$2" data="${3-}" tmp code
  tmp=$(mktemp)
  local -a args=(-sS -o "$tmp" -w '%{http_code}' -X "$method"
                 -H "Authorization: Bearer $ACCESS_TOKEN")
  [[ -n "$data" ]] && args+=(-H "Content-Type: application/json" -d "$data")
  code=$(curl "${args[@]}" "$url") || { rm -f "$tmp"; API_BODY=""; return 1; }
  API_BODY=$(cat "$tmp"); rm -f "$tmp"
  [[ "$code" == 2* ]]
}

api_err() { jq -r '.error.message // .' <<<"${API_BODY:-}" 2>/dev/null | head -3; }

# =========================================================== ANDROID PHASE ===
# Built and shipped completely before iOS begins.
if (( DO_ANDROID )); then
  step "Android · build"
  if (( DO_BUILD )); then
    flutter build appbundle --release
  else
    info "skipped (--skip-build)"
  fi
  [[ -f "$AAB" ]] || die "Expected $AAB but it does not exist."
  ok "$AAB ($(du -h "$AAB" | cut -f1))"

  step "Android · Google Play → $TRACK"

  # --- OAuth2: sign a JWT with the service-account key, swap it for a token ---
  KEY_FILE=$(mktemp); chmod 600 "$KEY_FILE"
  trap 'rm -f "$KEY_FILE"' EXIT
  jq -r '.private_key' "$PLAY_SERVICE_ACCOUNT_JSON" > "$KEY_FILE"
  SA_EMAIL=$(jq -r '.client_email' "$PLAY_SERVICE_ACCOUNT_JSON")

  NOW=$(date +%s)
  JWT_HEADER=$(printf '%s' '{"alg":"RS256","typ":"JWT"}' | b64url)
  JWT_CLAIMS=$(jq -nc --arg iss "$SA_EMAIL" --argjson iat "$NOW" --argjson exp "$(( NOW + 3600 ))" \
      '{iss:$iss,
        scope:"https://www.googleapis.com/auth/androidpublisher",
        aud:"https://oauth2.googleapis.com/token",
        iat:$iat, exp:$exp}' | b64url)
  JWT_SIG=$(printf '%s.%s' "$JWT_HEADER" "$JWT_CLAIMS" \
            | openssl dgst -sha256 -sign "$KEY_FILE" -binary | b64url)
  rm -f "$KEY_FILE"; trap - EXIT

  TOKEN_JSON=$(curl -sS -X POST https://oauth2.googleapis.com/token \
    --data-urlencode "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer" \
    --data-urlencode "assertion=${JWT_HEADER}.${JWT_CLAIMS}.${JWT_SIG}")
  ACCESS_TOKEN=$(jq -r '.access_token // empty' <<<"$TOKEN_JSON")
  [[ -n "$ACCESS_TOKEN" ]] || die \
    "Google rejected the service-account key: $(jq -r '.error_description // .error // .' <<<"$TOKEN_JSON")
  Check that the Google Play Android Developer API is enabled for the key's project."
  ok "authenticated as $SA_EMAIL"

  # --- open an edit ---
  api POST "$PLAY_API/edits" || die "Could not open a Play edit: $(api_err)
  Most likely the service account has not been invited to this app in
  Play Console → Users and permissions (see scripts/README.md)."
  EDIT_ID=$(jq -r '.id' <<<"$API_BODY")
  info "edit $EDIT_ID"

  # --- upload the bundle (progress goes to stderr) ---
  info "uploading $(du -h "$AAB" | cut -f1) bundle…"
  UP_TMP=$(mktemp)
  UP_CODE=$(curl -# -o "$UP_TMP" -w '%{http_code}' -X POST \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/octet-stream" \
    --data-binary @"$AAB" \
    "$PLAY_UPLOAD/edits/$EDIT_ID/bundles?uploadType=media")
  UP_BODY=$(cat "$UP_TMP"); rm -f "$UP_TMP"
  [[ "$UP_CODE" == 2* ]] || die \
    "Bundle upload failed (HTTP $UP_CODE): $(jq -r '.error.message // .' <<<"$UP_BODY" | head -3)
  If it mentions a version code already in use: Play burns a code permanently
  once uploaded to any track. Raise the +N in pubspec.yaml and run again."
  VERSION_CODE=$(jq -r '.versionCode' <<<"$UP_BODY")
  ok "uploaded versionCode $VERSION_CODE"

  # --- assign it to the track ---
  TRACK_BODY=$(jq -nc --arg t "$TRACK" --arg vc "$VERSION_CODE" --arg notes "$RELEASE_NOTES" \
    '{track:$t, releases:[{versionCodes:[$vc], status:"completed",
       releaseNotes:[{language:"en-US", text:$notes}]}]}')
  api PUT "$PLAY_API/edits/$EDIT_ID/tracks/$TRACK" "$TRACK_BODY" \
    || die "Could not assign versionCode $VERSION_CODE to '$TRACK': $(api_err)"
  ok "assigned to $TRACK"

  # --- commit; retry unreviewed if the account lacks review rights ---
  if ! api POST "$PLAY_API/edits/$EDIT_ID:commit"; then
    warn "commit rejected ($(api_err)) — retrying with changesNotSentForReview=true"
    api POST "$PLAY_API/edits/$EDIT_ID:commit?changesNotSentForReview=true" \
      || die "Commit failed: $(api_err)"
  fi
  ok "committed — live on the $TRACK track shortly"
  ANDROID_DONE=1
fi

# =============================================================== iOS PHASE ===
if (( DO_IOS )); then
  step "iOS · build"
  if (( DO_BUILD )); then
    flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
  else
    info "skipped (--skip-build)"
  fi
  IPA=$(ls -t build/ios/ipa/*.ipa 2>/dev/null | head -1 || true)
  [[ -n "$IPA" ]] || die "No .ipa found in build/ios/ipa/ — run without --skip-build."
  ok "$(basename "$IPA") ($(du -h "$IPA" | cut -f1))"

  step "iOS · TestFlight"

  ALTOOL_ARGS=(--upload-app --type ios -f "$IPA"
               --username "$APPLE_ID" --password "$APPLE_APP_SPECIFIC_PASSWORD")
  [[ -n "$ASC_PROVIDER" ]] && ALTOOL_ARGS+=(--asc-provider "$ASC_PROVIDER")

  info "validating…"
  if ! xcrun altool --validate-app --type ios -f "$IPA" \
        --username "$APPLE_ID" --password "$APPLE_APP_SPECIFIC_PASSWORD" 2>&1 \
        | sed 's/^/      /'; then
    die "Validation failed — see the errors above. Nothing was uploaded to TestFlight.
  ${ANDROID_DONE:+The Android release already shipped; re-run with --ios-only once fixed.}"
  fi
  ok "validated"

  info "uploading (this is the slow part)…"
  xcrun altool "${ALTOOL_ARGS[@]}" 2>&1 | sed 's/^/      /'
  ok "delivered — Apple emails you when processing finishes"
fi

# ------------------------------------------------------------------ done ----
ELAPSED=$(( $(date +%s) - START_TS ))
echo
echo "${B}${G}Done${N} in $(( ELAPSED / 60 ))m $(( ELAPSED % 60 ))s — ${B}${VERSION_NAME}+${BUILD_NUMBER}${N}"
if (( DO_ANDROID )); then
  echo "  Play       https://play.google.com/console  →  Testing → Internal testing"
fi
if (( DO_IOS )); then
  echo "  TestFlight https://appstoreconnect.apple.com  →  My Apps → Coloro → TestFlight"
fi
echo
