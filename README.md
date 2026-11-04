# Islet

A native macOS app that lives in the notch. It shows what Spotify is playing, your next Outlook meeting, and what your Claude Code sessions are doing, and lets you approve their requests without leaving what you're in.

## Features

- **Closed notch:** stays the size of the hardware notch until something is live. Album art and a moving equaliser appear while Spotify plays, a count while agents run, and it widens with a pulsing "*project* needs you" when an agent is waiting on you.
- **Home:** three cards of one height.
  - **Spotify:** artwork, track, a progress bar you can click to seek, shuffle, previous, play/pause, next and repeat.
  - **Outlook:** your next meeting with a countdown, the two after it, and a Join button for Teams, Zoom, Meet or Webex links.
  - **Claude Code:** every session with its status, and a button to review requests.
- **Agents:** waiting requests on top with the exact command, then Deny, Answer in Claude or Allow once. Running, idle and finished sessions below, with what each is doing ("Editing PlayerView.swift", "Running tests").
- **Calendar:** this month with busy days marked, and the chosen day's meetings.
- **Settings:** sources (Spotify, Outlook, Claude Code, how long to hold approvals) and notch behaviour (open on hover, widen for agents, open at login).

## How each source works

| Source | How |
|---|---|
| Spotify | Spotify's AppleScript dictionary, refreshed on Spotify's own playback notification. Never launches Spotify by itself. |
| Outlook | macOS Calendar (EventKit). Add your Outlook account in System Settings › Internet Accounts; when one exists, only its calendars are shown. |
| Claude Code | Settings › Connect adds `curl` hooks to `~/.claude/settings.json` (backed up first, to `settings.json.islet-backup`). They post to Islet on `127.0.0.1:47823` with a private token. When Islet isn't running, each hook fails silently and Claude Code behaves as before. |

Approvals: Islet holds a permission request for the time you set (1 minute by default). If you don't answer, it hands the request back to Claude's own prompt.

## Design

Same rules as Driftly: one place for every option, measured spacing (8pt grid, 16pt edges, 14pt card padding, 18pt card radius) in [`DesignSystem.swift`](Islet/DesignSystem.swift), and VoiceOver labels on every icon button.

## Requirements

- macOS 26 or later, Xcode 26 or later.

## Build and run

1. Open `Islet.xcodeproj`, choose your signing team, and run.
2. Or from the terminal: `xcodebuild -scheme Islet -derivedDataPath build CODE_SIGN_IDENTITY=- build && open build/Build/Products/Debug/Islet.app`

On first use macOS asks for Automation access to Spotify and for calendar access.
