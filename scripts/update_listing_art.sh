#!/usr/bin/env bash
# Replace Coloro's Play listing art (feature graphic + phone screenshots)
# via the Android Publisher API, using the repo's service account.
set -euo pipefail

ROOT="/Users/megz/dev/flutter/megz/coloro"
SA_JSON="$ROOT/scripts/play-service-account.json"
PKG="com.megz.coloro"
LANG_CODE="en-US"
API="https://androidpublisher.googleapis.com/androidpublisher/v3/applications/$PKG"
UPLOAD="https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/$PKG"

b64url() { openssl base64 -e -A | tr '+/' '-_' | tr -d '='; }

KEY_FILE=$(mktemp); chmod 600 "$KEY_FILE"
trap 'rm -f "$KEY_FILE"' EXIT
jq -r '.private_key' "$SA_JSON" > "$KEY_FILE"
SA_EMAIL=$(jq -r '.client_email' "$SA_JSON")

NOW=$(date +%s)
H=$(printf '%s' '{"alg":"RS256","typ":"JWT"}' | b64url)
C=$(jq -nc --arg iss "$SA_EMAIL" --argjson iat "$NOW" --argjson exp "$(( NOW + 3600 ))" \
    '{iss:$iss,scope:"https://www.googleapis.com/auth/androidpublisher",aud:"https://oauth2.googleapis.com/token",iat:$iat,exp:$exp}' | b64url)
S=$(printf '%s.%s' "$H" "$C" | openssl dgst -sha256 -sign "$KEY_FILE" -binary | b64url)
ACCESS_TOKEN=$(curl -sS -X POST https://oauth2.googleapis.com/token \
  --data-urlencode "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer" \
  --data-urlencode "assertion=${H}.${C}.${S}" | jq -r '.access_token // empty')
[[ -n "$ACCESS_TOKEN" ]] || { echo "AUTH FAILED"; exit 1; }
echo "authenticated as $SA_EMAIL"

auth=(-H "Authorization: Bearer $ACCESS_TOKEN")

EDIT_ID=$(curl -sS -X POST "${auth[@]}" "$API/edits" | jq -r '.id // empty')
[[ -n "$EDIT_ID" ]] || { echo "EDIT OPEN FAILED"; exit 1; }
echo "edit $EDIT_ID"

echo "--- current images ---"
for t in featureGraphic phoneScreenshots; do
  echo "$t:"; curl -sS "${auth[@]}" "$API/edits/$EDIT_ID/listings/$LANG_CODE/$t" | jq -c '.images // [] | length'
done

echo "--- deleteall ---"
for t in featureGraphic phoneScreenshots; do
  code=$(curl -sS -o /dev/null -w '%{http_code}' -X DELETE "${auth[@]}" "$API/edits/$EDIT_ID/listings/$LANG_CODE/$t")
  echo "deleteall $t -> HTTP $code"
  [[ "$code" == 2* ]] || { echo "DELETE FAILED"; exit 1; }
done

up() { # imageType file
  local t="$1" f="$2" out
  out=$(curl -sS -X POST "${auth[@]}" -H "Content-Type: image/png" \
    --data-binary @"$f" "$UPLOAD/edits/$EDIT_ID/listings/$LANG_CODE/$t?uploadType=media")
  local id sha
  id=$(jq -r '.image.id // empty' <<<"$out")
  [[ -n "$id" ]] || { echo "UPLOAD FAILED for $f: $out"; exit 1; }
  echo "uploaded $(basename "$f") -> $t ($id)"
}

up featureGraphic "$ROOT/aso/feature_graphic.png"
for i in 1 2 3 4 5; do
  up phoneScreenshots "$ROOT/aso/screenshot_$i.png"
done

echo "--- commit ---"
# changesNotSentForReview must NOT be set for this app — the API rejects it
# ("Changes are sent for review automatically"), so a plain commit is the only path.
body=$(curl -sS -o /tmp/commit_out.json -w '%{http_code}' -X POST "${auth[@]}" "$API/edits/$EDIT_ID:commit")
if [[ "$body" != 2* ]]; then
  echo "COMMIT FAILED HTTP $body: $(jq -r '.error.message // .' /tmp/commit_out.json)"
  if [[ "$body" == "403" ]]; then
    echo "403 here means $SA_EMAIL lacks the 'Manage store presence' app permission."
    echo "Fix: Play Console -> Users and permissions -> $SA_EMAIL -> App permissions (Coloro)"
    echo "     -> tick 'Manage store presence' -> Save, then re-run this script."
  fi
  exit 1
fi
echo "committed edit $EDIT_ID — listing art replaced (live after Google's listing review)"
