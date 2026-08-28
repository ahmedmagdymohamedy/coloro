# marketing/

Everything campaign- and store-facing. Nothing here ships inside the app.

| Path | What it is |
|---|---|
| `playable/coloro_playable.html` | Self-contained HTML5 playable ad. One file, zero network requests — works as a Google Ads playable, a landing-page embed, or offline from disk. |
| `campaigns/google-ads-kit.md` | The Google Ads App campaign kit: the revenue arithmetic, campaign structure, all text assets, creative specs, and kill criteria. |
| `docs/facebook-app-events.md` | Meta App Events: what was set up, what is blocked, and the exact steps to finish it. |

Store listing copy and store art live in `aso/`, not here — they are
generated from the real game by `test/aso_generator_test.dart`.

## The playable

```sh
# preview it locally
python3 -m http.server 8777 --directory marketing
open http://localhost:8777/playable/coloro_playable.html
```

It plays the real mechanic — bottles drink the picture from its bottom edge
only — on a 12×12 heart, and takes about 25 seconds to clear. Two deliberate
differences from the game: it cannot be lost (tapping a docked bottle sends
it back to the tray), and a banner appears if every bottle is blocked. An ad
that dead-ends is a wasted impression.

For an ad network, zip the single file as `index.html`. The CTA already
tries `mraid.open`, `FbPlayableAd.onCTAClick` and `ExitApi.exit` before
falling back to a plain store link, so it works on most networks unchanged —
set `CTA_URL` near the bottom of the file for the plain-web case.

`window.__coloroQA` exposes `step()`, `tapTray()`, `tapSlot()`, `trayInfo()`
and `state()` so the creative can be verified without a browser that runs
`requestAnimationFrame` (ad containers and hidden tabs suspend it). That hook
is how this build was proven winnable: 20 bottles, no rescues, 0 cells left.
