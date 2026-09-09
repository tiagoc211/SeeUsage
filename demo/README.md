# SeeUsage demo production

This directory keeps video tooling separate from the Swift application. It uses
Remotion and React only; the application UI must come from native macOS captures.

## Repository findings

- `Package.swift` defines a macOS 14+ Swift executable with no package dependencies.
- `scripts/build_app.sh` builds and packages `dist/SeeUsage.app`; launch it with
  `open dist/SeeUsage.app`.
- `SeeUsageApp.swift` owns the native menu bar item and SwiftUI popover.
- `UsageStore.swift` polls configured Codex profiles and Antigravity concurrently,
  retains last-known quotas on errors, and shares a local cache with the CLI.
- `CodexClient.swift` queries each profile through `codex app-server --stdio`.
  `AntigravityClient.swift` parses the installed `agy /usage` command's output.
- `Views.swift` provides quotas, reset times, refresh, command copying, and settings.
  Settings cover profiles, themes, menu bar modes, notifications, executables, and sync.
- `CLIHandler.swift` and `WatchDashboard.swift` provide terminal output, JSON,
  prompt integration, and an interactive dashboard with refresh/theme hotkeys.
- `Theme.swift` defines ten palettes. The running application uses Iris:
  background `#0e0d18`, surface `#181528`, accent `#a855f7`, text `#f5f0ff`.
- Tests cover parsing, processes, themes, menu bar modes, notifications, and CLI/TUI.

## Edit and source

The 13-second composition shows the real menu bar popover throughout the main
sequence, followed by a brief SeeUsage / Open Source end frame:

- 0–2.3s: introduce SeeUsage alongside the real Codex quota panel.
- 2.3–5.9s: compare profiles and refresh their 5-hour and weekly quotas.
- 5.9–11.7s: scroll to actual Gemini and Claude balances and reset times.
- 11.7–13s: minimal end frame.

`assets/captures/quota-flow.mov` is the original 12-second native screen recording.
`capture.json` records provenance. Quotas and profile names are captured as displayed;
no credentials or private paths are shown. Numbers represent that recording, not
current balances. There is no reconstructed UI, substituted data, or application code
change. The rounded crop removes desktop pixels at the popover corners. The small
editorial cursor indicates the refresh performed in the recording.

Native macOS accessibility and screen recording permissions are needed. Playwright
cannot interact with this SwiftUI app. The requested Playwright and Remotion MCPs
were not exposed in the production session; consult the official Remotion docs:

- https://www.remotion.dev/docs/cli/render
- https://www.remotion.dev/docs/img
- https://www.remotion.dev/docs/interpolate
- https://www.remotion.dev/docs/offthreadvideo

## Setup

```sh
cd demo
npm ci
npm run studio
npm run render
```

Rendering uses Remotion's browser and bundled FFmpeg. To reuse an installed Chrome
instead of downloading a renderer browser, set `REMOTION_BROWSER_EXECUTABLE`:

```sh
REMOTION_BROWSER_EXECUTABLE='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' npm run render
```

Outputs are `assets/seeusage-demo.mp4` (1200×800, 30 fps, H.264, silent) and
`assets/seeusage-demo.gif` (900×600, 12 fps, looping, 128-color palette). The GIF uses
no dithering and rectangle difference processing to preserve flat backgrounds and
keep its README footprint small. Temporary media goes in ignored `assets/.work/`. No separate FFmpeg install,
font downloads, animation library, or production dependency is required.

## Recapture on macOS

Launch the packaged SeeUsage application, let live quotas load, then run:

```sh
npm run capture
```

Keep the desktop idle during the 12-second capture. The script opens the panel,
finds its native accessibility bounds, refreshes, and scrolls down. It overwrites
the source recording; review the new capture before rendering and adjust the
editorial cursor timing in `src/index.jsx` if polling or recording latency changes.
Use the same 370×460-point panel and Iris theme for this composition. Capture does
not change preferences, credentials, or the application's implementation.

## Review

Inspect the MP4 and GIF at README size, including the refresh, scroll, transition,
and end frame. Confirm the whole panel fits, text is legible, desktop corners are
excluded, no account paths or credentials are visible, and GIF duration matches the
MP4. Temporary review frames can be extracted with `npx remotion ffmpeg`.
