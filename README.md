# Islet

A Dynamic Island for the Mac notch. Islet stays the size of the notch and shows only the apps that are active right now: Spotify, Outlook and Claude Code. Click or tap an app beside the notch to open its own panel.

## The island

- **Idle:** with nothing active, Islet is just the notch.
- **Active apps:** each gets one 36pt slot beside the notch, and the whole slot is the click or touch target. The notch stays centred however many apps are showing.
  - **Spotify** (left): the album art, dimmed while paused. It stays for a few minutes after you pause.
  - **Claude Code** (right): a badge with the number of running sessions, a ✓ when they've finished, and an amber ! when one needs you.
  - **Outlook** (right): minutes until your next meeting, or a camera once it has started.
- **Hover:** highlights the app under the pointer. Nothing opens until you click or tap.
- **Panels:**
  - **Spotify:** artwork, a scrubber you can click to seek, shuffle, previous, play/pause, next and repeat.
  - **Claude Code:** the request that needs you, with the exact command and Answer in Claude, Deny or Allow once. Then every session and what it's doing ("Editing PlayerView.swift", "Running tests").
  - **Outlook:** the next meeting with a Join button for Teams, Zoom, Meet or Webex, then the rest of today.
- **Approval alert:** the one thing that opens on its own. When an agent asks for permission, the island expands with Deny and Allow for a few seconds, then shrinks back to the ! badge. ⌃⌘Y allows and ⌃⌘N denies while a request is waiting.
- Close a panel with ×, Esc, or a click anywhere else.

## Settings

- **Menu-bar panel:** a master switch, one switch per app (or Connect, when it isn't set up), whether to expand for approvals, and how early meetings appear.
- **Advanced settings window:** General, Island, Spotify, Claude Code, Outlook and About panes, for everything else.

## How each app connects

| App | How |
|---|---|
| Spotify | Spotify's AppleScript dictionary, refreshed on Spotify's own playback notification. Never launches Spotify by itself. |
| Outlook | macOS Calendar (EventKit). Add your Outlook account in System Settings › Internet Accounts; once it's there, only its calendars are shown. |
| Claude Code | Connect adds `curl` hooks to `~/.claude/settings.json` (backed up first, to `settings.json.islet-backup`). They post to Islet on `127.0.0.1:47823` with a private token. When Islet isn't running, each hook fails silently and Claude Code behaves as before. |

Islet holds a permission request for the time you set (1 minute by default). If you don't answer, it hands the request back to Claude's own prompt.

## Design

Same rules as Driftly: one place for every option, measured spacing in [`DesignSystem.swift`](Islet/DesignSystem.swift), stock grouped forms for settings, and VoiceOver labels on every icon-only button. The island is always dark, like the notch it extends; the menu-bar panel and settings window follow the system appearance.

## Requirements

- macOS 26 or later, Xcode 26 or later.

## Build and run

1. Open `Islet.xcodeproj`, choose your signing team, and run.
2. Or from the terminal: `xcodebuild -scheme Islet -derivedDataPath build CODE_SIGN_IDENTITY=- build && open build/Build/Products/Debug/Islet.app`

On first use macOS asks for Automation access to Spotify and for calendar access.

### Design review

Debug builds accept `-demo [compact|spotify|claude|outlook|alert|menu|settings]`, which fills Islet with sample data and opens one state, without touching Spotify, your calendar or Claude Code.
