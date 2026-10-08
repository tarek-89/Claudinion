<p align="center">
  <img src="docs/icon.png" width="128" alt="Claudinion icon">
</p>

<h1 align="center">Claudinion</h1>

<p align="center">
  <b>A tiny pixel minion that lives on your Mac desktop and acts out what Claude Code is doing.</b><br>
  It types when Claude runs commands, hammers when it edits files, jumps up and down when Claude needs you,<br>
  and when Claude is idle it walks, dances, juggles, showers, naps… 29 things in all.
</p>

<p align="center">
  <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-black?logo=apple">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-single%20file-F05138?logo=swift&logoColor=white">
  <img alt="Apple silicon and Intel" src="https://img.shields.io/badge/Apple%20silicon%20%2B%20Intel-universal-555">
  <img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-blue">
</p>

> [!NOTE]
> Claudinion is an unofficial fan project. It is not made by, affiliated with, or endorsed by Anthropic.
> "Claude" and "Claude Code" are trademarks of Anthropic.

---

## Contents

- [What it does](#what-it-does)
- [Install](#install)
- [Connect it to Claude Code](#connect-it-to-claude-code)
- [Using it](#using-it)
- [All actions](#all-actions)
- [How it works](#how-it-works)
- [Troubleshooting](#troubleshooting)
- [Uninstall](#uninstall)
- [Development](#development)
- [License](#license)

## What it does

- 🧡 **Lives on your desktop.** It walks along the bottom of your screen (or an area you choose), stays on top of other windows and shows up on every Space.
- 🤖 **Reacts to Claude Code in real time.** It uses [Claude Code hooks](https://code.claude.com/docs/en/hooks), so it works in the terminal and in the Claude desktop app's Code tab.
- 🎲 **Has 29 idle actions** in 6 categories, and you choose which ones it may do.
- 🎛️ **Is easy to adjust.** Change its size, pick light or dark style (or follow macOS), set where it walks, and hide it from the menu bar.
- 🪶 **Is tiny and private.** It's a single Swift file with no dependencies and no network access. It only ever sees the *names* of Claude's events and tools.

<p align="center">
  <img src="docs/actions.png" alt="All 29 idle actions">
</p>

## Install

You'll need **macOS 14 (Sonoma) or later** and the **Xcode Command Line Tools**. If you don't have the Command Line Tools yet, run:

```bash
xcode-select --install
```

Then build and install:

```bash
git clone https://github.com/tarek-89/Claudinion.git
cd Claudinion
./build.sh --install
```

This builds a universal app (Apple silicon and Intel), copies it to `~/Applications/Claudinion.app` and starts it. Your minion pops up at the bottom of the screen, and a small pixel icon appears in the menu bar.

> [!TIP]
> To start Claudinion every time you log in, add it under **System Settings → General → Login Items**.

If you only want to build it without installing, run `./build.sh` and the app appears in `build/Claudinion.app`.

## Connect it to Claude Code

Claudinion plays on its own straight away. To make it react to Claude:

1. Click the Claudinion icon in the menu bar (or right-click the minion).
2. Choose **Connect to Claude…** and confirm.
3. Start a **new** Claude Code session. Sessions that are already open won't send events.

**What Connect does:**
- It adds a small hook entry to `~/.claude/settings.json` for each event listed under [How it works](#how-it-works).
- It saves your previous settings as `~/.claude/settings.json.before-claudinion` first.
- It doesn't touch any hooks you already have.

To undo it, choose **Disconnect from Claude…**. That removes only Claudinion's hooks.

<details>
<summary>Prefer to edit the settings by hand?</summary>

Add this to the `hooks` section of `~/.claude/settings.json`. Repeat it for each event name listed in [How it works](#how-it-works):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$HOME/Applications/Claudinion.app/Contents/MacOS/Claudinion\" --hook",
            "async": true
          }
        ]
      }
    ]
  }
}
```

`async: true` means Claude never waits for the minion.
</details>

## Using it

| You do | Claudinion does |
|---|---|
| **Click** it | Hops, with a heart |
| **Double-click** it | Backflip |
| **Drag** it | Dangles from your cursor; drop it anywhere, for example on top of a window |
| **Right-click** it, or click the **menu bar icon** | Opens the menu |

**The menu:**

| Item | What it's for |
|---|---|
| **Hide / Show** | Hides the minion without quitting it |
| **Play ▸** | Starts any action now, including previews of every Claude reaction |
| **Stay in Place** | It still animates, but stops walking around |
| **Walking Area ▸** | **Anywhere** (the bottom of the screen), or **Draw New Area…**: drag a rectangle and it walks along that rectangle's bottom edge |
| **React to Claude** | Pauses or resumes Claude reactions |
| **Connect / Disconnect from Claude…** | Adds or removes the hooks |
| **Settings…** | Size, appearance, walking area, and which actions it does on its own |

Your settings are saved and survive restarts.

## All actions

### Idle actions

These are what it does when Claude isn't busy. In **Settings…**, untick the ones you don't want. If you leave just five ticked, it rotates between those five.

| Category | Actions |
|---|---|
| **Moving** | Walk · Run · Hop · Roll · Spin · Backflip · Chase a Butterfly |
| **Fun** | Dance · Wave · Sing · Play Ball · Juggle · Eat a Cookie · Play Dead |
| **Sports** | Lift Weights · Jumping Jacks · Boxing · Use a Whip · Use a Blaster |
| **Chill** | Sit · Look Around · Stretch & Yawn · Read a Book · Meditate · Shower · Sleep |
| **Work** | Coding |
| **Moods** | Cry · Feel Down |

### Claude reactions

These play automatically while Claude works, and they always take priority over idle actions.

<p align="center">
  <img src="docs/reactions.png" alt="Claude reactions">
</p>

| When Claude… | Claudinion… |
|---|---|
| starts a session | wakes up, stretches and hops |
| gets your message | perks up with a **!** |
| is thinking | paces with **…** thought dots |
| reads or searches files | walks around with a magnifying glass |
| runs shell commands | types on a little laptop |
| edits or writes files | hammers a brick, with sparks |
| uses the web | holds up a spinning globe |
| needs your permission or an answer | jumps and waves with a flashing **!** |
| has a tool fail | shakes, sad and sweaty |
| runs subagents | gets mini helper clones walking beside it |
| compacts its context | gets squished flat, then pops back up |
| completes a task | shows a ✓ |
| changes folder | runs off one edge and comes back from the other |
| finishes its turn | celebrates with a ✓ and confetti |
| hits an API error (rate limit, overload…) | falls over dizzy |
| ends the session | waves goodbye and goes to sleep |

## How it works

```
Claude Code ──hook──▶ Claudinion --hook ──append──▶ ~/.claude/claudinion/events.jsonl ──watch──▶ Claudinion (on screen)
```

- **Two modes, one binary.** When Claude Code fires a hook, it runs the same app binary in a short-lived `--hook` mode. That process reads the hook's JSON from stdin and appends one line to `~/.claude/claudinion/events.jsonl`. The line holds only the event name, the tool name, the notification type, the session id and a timestamp.
- **Watching the file.** The running minion reads new lines from that file a few times per second and switches animation.
- **Never slows Claude down.** The hooks are `async`, so Claude doesn't wait for them, and the event file is trimmed automatically when it grows past 512 KB.
- **Safety timeout.** If Claude goes quiet for 10 minutes in the middle of a task (for example, a session was closed), the minion goes back to playing.

**Hook events used:** `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `PermissionRequest`, `Notification`, `SubagentStart`, `SubagentStop`, `Stop`, `StopFailure`, `PreCompact`, `PostCompact`, `TaskCompleted`, `CwdChanged`, `SessionEnd`.

## Troubleshooting

<details>
<summary><b>It doesn't react to Claude</b></summary>

- Make sure the menu says **Disconnect from Claude…**. If it says Connect, it isn't connected yet.
- Start a **new** Claude Code session after connecting.
- Check that **React to Claude** is ticked.
- Run `tail -f ~/.claude/claudinion/events.jsonl` while you use Claude. New lines should appear.
- Cloud sessions run on remote machines, so they can't reach the minion on your Mac. Local sessions in the terminal and the desktop app's Code tab work.
- If you moved the app after connecting, choose **Disconnect** and then **Connect** again, so the hooks point to the new location.
</details>

<details>
<summary><b>I can't find the menu bar icon</b></summary>

On a crowded menu bar, macOS may hide new icons behind the notch. Quit a few menu bar apps, or use a menu bar manager. You can always right-click the minion itself.
</details>

<details>
<summary><b>macOS says the app is damaged or from an unidentified developer</b></summary>

This happens to prebuilt copies that were downloaded rather than built locally. Either build it yourself with `./build.sh`, or clear the quarantine flag:

```bash
xattr -dr com.apple.quarantine ~/Applications/Claudinion.app
```
</details>

## Uninstall

1. From the menu, choose **Disconnect from Claude…**, then **Quit**.
2. Remove the app, its event file and its saved settings:

```bash
rm -rf ~/Applications/Claudinion.app ~/.claude/claudinion && defaults delete io.github.tarek-89.claudinion
```

## Development

The whole app is one file, [`Sources/Claudinion/main.swift`](Sources/Claudinion/main.swift), built with plain `swiftc`. There's no Xcode project or package manager. The file is organised in this order:

| Section | What's in it |
|---|---|
| Hook mode | The `--hook` entry point that Claude Code runs |
| Look | Colours, light/dark themes, and pixel-art props drawn as small strings |
| Pose and Actions | `render(act, tick, facing)` returns the pose and props for every frame of every action |
| Drawing | The body, eyes and props, drawn on a pixel grid |
| Walking area picker | The overlay for drawing the walking area |
| Pet | The window, menus, settings, Claude event handling and the animation loop (12 fps) |

### Adding an action

1. Add a case to `enum Act`, and put it in a category in `Act.categories`.
2. Give it a `title` and a `duration()`.
3. Add a `case` in `render(_:_:_:)` that sets the pose (`p`) and adds props with `add(...)` or `addF(...)`. `addF` mirrors the prop when the minion faces left.
4. To check the art, run `./build.sh` and then:

```bash
build/Claudinion.app/Contents/MacOS/Claudinion --gallery /tmp/actions.png
```

That draws one frame of every action. Use `--gallery /tmp/r.png reactions` for the Claude reactions, and `--sheet /tmp/s.png` for several frames per action.

Pull requests with new actions are very welcome.

## License

[MIT](LICENSE)
