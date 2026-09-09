# SeeUsage

A lightweight macOS menu bar app and CLI for tracking AI coding quotas across Codex profiles and Antigravity.

<p align="center">
  <img src="./assets/seeusage-demo.gif" alt="SeeUsage demo" width="850">
</p>

## What is SeeUsage?

SeeUsage monitors your remaining AI coding allowances across local CLI accounts in a single, glanceable interface. It tracks 5-hour session limits and 7-day weekly quotas for both Codex (including multiple isolated profiles) and Antigravity. Live countdowns display exactly when limits reset, helping you balance work across accounts without hitting unexpected rate limits mid-task.

## Features

- **Codex multi-profile tracking**: Simultaneously queries quotas across `~/.codex` and `~/.codex-profiles/*` without switching active accounts or reading credentials.
- **Antigravity quota monitoring**: Reads active `agy` rate limits across model families (Gemini, Claude, GPT).
- **Customizable menu bar**: Choose between Lowest Quota (`⚡ 47%`), Dual Quotas (`cx: 92% · ag: 81%`), Mini Gauge, or Icon Only, with color-coded quota health.
- **Interactive watch dashboard (`seeusage watch`)**: Real-time terminal TUI with second-by-second countdowns to quota resets and theme switching.
- **Native system notifications**: Custom alerts when any quota drops below a configurable threshold and when limits reset back to 100%.
- **Fast shell prompt integration**: Instant cached one-liner (`seeusage --mini --cached`) for Starship, Zsh, and tmux prompts, plus JSON output (`--json`).
- **Local and private**: Runs entirely on your machine. Never stores, reads, or transmits tokens or authentication secrets.

## Installation

Clone the repository and run the installation script:

```bash
git clone https://github.com/tiagoc211/SeeUsage.git
cd SeeUsage
./scripts/install.sh
```

This compiles the release binary, installs `SeeUsage.app` into `~/Applications`, and links the `seeusage` CLI command to `~/.local/bin/seeusage`.

To start the menu bar app:

```bash
open ~/Applications/SeeUsage.app
```

## Requirements

- macOS 14.0 (Sonoma) or newer
- Swift 5.9+ or Xcode Command Line Tools
- [Codex CLI](https://github.com/openai/codex) (`codex`) installed and authenticated (optional, for Codex tracking)
- [Antigravity CLI](https://github.com/google/antigravity) (`agy`) installed and authenticated (optional, for Antigravity tracking)

## CLI Usage

```bash
seeusage                     # Display formatted quota table for all accounts
seeusage watch               # Live interactive TUI with real-time countdown to reset
seeusage settings            # Open macOS preferences window
seeusage themes              # List available terminal themes
seeusage theme ocean         # Apply a terminal theme (e.g. emerald, ocean, tokyo-night)
seeusage mode dual           # Set menu bar style (percent, dual, gauge, iconOnly)
seeusage notify test         # Send an instant test notification
seeusage notify 15           # Set low-quota notification threshold to 15%
seeusage --mini --cached     # Fast one-liner for shell prompts (reads local cache)
seeusage --json              # Output quota data as JSON
seeusage --export <profile>  # Print export CODEX_HOME=... command for shell switching
```

## How It Works

SeeUsage communicates with official CLI tools already authenticated on your system:

- **Codex**: Spawns an isolated `codex app-server --stdio` process for each configured profile path and requests rate limits via JSON-RPC (`account/rateLimits/read`). It never accesses `auth.json` directly.
- **Antigravity**: Runs `agy -p "/usage" --output-format text` to read active quota metrics and reset timestamps without consuming inference tokens.
- **Caching**: Aggregated metrics are stored in `~/.config/seeusage/cache.json` for zero-latency prompt queries and instant popover rendering.

## Development

```bash
# Build debug executable
swift build

# Run the CLI directly
swift run SeeUsage

# Run the interactive watch dashboard
swift run SeeUsage watch

# Package the release macOS application bundle (dist/SeeUsage.app)
./scripts/build_app.sh
```

## Project Structure

```text
Sources/
  SeeUsage/
    SeeUsageApp.swift         # Menu bar status item, popover lifecycle, and entry point
    Views.swift               # SwiftUI menu bar popover and preferences window
    UsageStore.swift          # Quota polling, aggregation, and caching
    CodexClient.swift         # JSON-RPC client for codex app-server
    AntigravityClient.swift   # Parser for agy usage output
    CLIHandler.swift          # Terminal output, shell integration, and subcommands
    WatchDashboard.swift      # Interactive terminal TUI dashboard (seeusage watch)
    NotificationManager.swift # Threshold-based notifications and reset alerts
    Theme.swift               # Color palettes for UI and terminal rendering
scripts/
  build_app.sh                # Compiles and bundles dist/SeeUsage.app
  install.sh                  # Builds and installs to ~/Applications and ~/.local/bin
assets/                       # Demo media and screen recordings
```

## Contributing

Contributions, bug reports, and feature suggestions are welcome. Feel free to open an issue or submit a pull request.

## License

This repository does not currently contain a license file. See [Issues](https://github.com/tiagoc211/SeeUsage/issues) to inquire about licensing.
