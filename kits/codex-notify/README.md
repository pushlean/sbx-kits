# codex-notify

Forward Codex attention notifications from inside a sandbox to the host desktop
over the terminal stream — no host-side watcher process required.

The kit installs `~/.codex/notify-host`, sets Codex's native user-level
`notify` command to invoke it, and configures TUI notifications to always run,
including while the terminal is focused. The script emits an OSC escape sequence
wrapped in a tmux passthrough envelope; the host tmux (or terminal emulator)
turns it into a desktop notification.

```
ESC Ptmux; ESC ESC ]777;notify;<title>;<body> BEL ESC \
```

The adapter renders these events:

| Codex event | Notification body |
| --- | --- |
| `agent-turn-complete` | Codex's final message, or `Codex finished its turn` |
| `approval-request` | Codex's approval message, or `Codex needs your approval` |
| `plan-mode-prompt` | `Plan ready for your review` |

Unknown events are ignored.

## Notification title

The body describes why Codex needs attention; the title says which session it
came from, so concurrent sandboxes are distinguishable:

```
codex-sbx-kits [main]
└─ $SANDBOX_NAME    └─ git branch in Codex's session cwd
```

`$SANDBOX_NAME` is the sandbox name in sbx 0.39+. For compatibility with older
releases, the script falls back to the legacy `$SANDBOX_VM_ID`, then the
container hostname, and finally `Codex`. The bracketed branch is omitted outside
a repository or on a detached HEAD. Explicit arguments bypass title derivation.

## Install

```bash
sbx kit add <sandbox> kits/codex-notify/
```

The kit writes this user-level setting to `~/.codex/config.toml`:

```toml
notify = ["/home/agent/.codex/notify-host", "--codex"]

[tui]
notifications = true
notification_condition = "always"
```

Codex accepts one notification command. To avoid clobbering another notifier,
installation fails if `config.toml` already has a different top-level `notify`
setting. Merge the command yourself if you need to dispatch to both. The kit
sets its two `[tui]` notification values on installation and reinstallation.

Start a new Codex session after installation so it reloads the configuration.

## Usage

```bash
notify-host "Build finished" "42 tests passed"
notify-host --codex '{"type":"approval-request","cwd":"'$PWD'"}'
```

| Env | Meaning |
| --- | --- |
| `NOTIFY_OSC=777\|9` | Escape flavour (default `777`) |
| `NOTIFY_TTY=/dev/…` | Force the output terminal, skipping TTY resolution |

## Requirements

The passthrough envelope is always emitted, so the host tmux must enable it:

```tmux
set -g allow-passthrough on
```

The terminal emulator must also understand the escape. If OSC 777 does nothing,
try `NOTIFY_OSC=9`.

## Verifying

Test direct delivery:

```bash
~/.codex/notify-host "Codex" "test notification"
```

To inspect the attention path rather than send bytes to a terminal, force
stdout and pipe through `cat -v`:

```bash
NOTIFY_TTY=/dev/stdout ~/.codex/notify-host --codex \
  '{"type":"approval-request","cwd":"'"$PWD"'"}' | cat -v

NOTIFY_TTY=/dev/stdout ~/.codex/notify-host --codex \
  '{"type":"agent-turn-complete","cwd":"'"$PWD"'","last-assistant-message":"Done"}' | cat -v
```

Both commands print an OSC sequence.

# Test sbx
```
sbx create --name codex-notify-kit-test --profile developer --kit kits/codex-notify/ codex .
sbx exec codex-notify-kit-test codex
```
