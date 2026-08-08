# tmux-notify

Forward Claude Code `Notification` events from inside a sandbox to the host
desktop over the terminal stream — no host-side watcher process required.

The kit installs `~/.claude/notify-host` and registers a `Notification` hook that
runs `notify-host --hook`. The script emits an OSC escape sequence wrapped in a
tmux passthrough envelope; the host's tmux (or terminal emulator) turns it into a
desktop notification.

```
ESC Ptmux; ESC ESC ]777;notify;<title>;<body> BEL ESC \
```

## Notification title

The body is Claude's own message; the title says *which session* it came from,
so concurrent sandboxes are told apart without hunting through tmux windows:

```
claude-sbx-kits [main]
└─ $SANDBOX_VM_ID   └─ git branch in the session's cwd
```

`$SANDBOX_VM_ID` is the `sbx` sandbox name, falling back to the container
hostname and then to `Claude Code`. The bracketed branch is dropped entirely on
a detached HEAD or outside a repository. Calling `notify-host` with explicit
arguments bypasses all of this and uses the title you pass.

## Install

Add the kit **after** the sandbox is created — `claude` clobbers
`~/.claude/settings.json` when it first initializes:

```bash
sbx kit add <sandbox> kits/tmux-notify/
```

## Usage

```bash
notify-host "Build finished" "42 tests passed"
notify-host --hook            # reads Claude Code hook JSON on stdin
```

| Env | Meaning |
| --- | --- |
| `NOTIFY_OSC=777\|9` | escape flavour (default `777`) |
| `NOTIFY_TTY=/dev/…` | force the output terminal, skipping tty resolution |

## Requirements

The envelope is always emitted — this kit assumes the host runs tmux. That tmux
must allow passthrough, otherwise the envelope is stripped and nothing fires:

```tmux
set -g allow-passthrough on
```

The terminal emulator must also understand the escape. If OSC 777 does nothing,
try `NOTIFY_OSC=9`.

## Caveats

### Claude Code's Bash tool sandbox blocks delivery

`notify-host` works by writing bytes to the pty that `claude` is attached to. When
Claude Code's own Bash tool sandbox is **enabled**, commands run in an isolated
PID/mount namespace where `/dev/pts` is empty and the `claude` process is not
visible. The script's tty resolution has nothing to find and bails out:

```
notify-host: no terminal found; notification not delivered
```

No amount of parent-chain walking fixes this — the pty is not in the namespace at
all. The only in-sandbox workarounds are a hardcoded `NOTIFY_TTY` or a separate
transport.

**This should not come up in practice.** Inside an `sbx` sandbox running yolo mode
(`claude --dangerously-skip-permissions`, i.e. `bypassPermissions`), the container
*is* the isolation boundary, so the Bash tool sandbox is redundant overhead —
disable it.

Toggle it for the session:

```
/sandbox
```

Or persist it in `~/.claude/settings.json`:

```json
{
  "sandbox": { "enabled": false }
}
```

Ad-hoc, a single call can opt out via the Bash tool's `dangerouslyDisableSandbox`
parameter, but flipping the setting off is the right move in a sandbox.

### Launching Claude via `sbx exec`

How you start `claude` decides whether it has a *controlling* terminal, which
changes how `notify-host` finds the pty.

```bash
sbx exec -it <sandbox> claude          # pty on stdio, NO controlling tty
sbx exec -it <sandbox> /bin/bash       # then run `claude` — controlling tty set up
```

With the direct form, `sbx exec` hands `claude` the pty on its stdio without
making it the session's controlling terminal. `/dev/tty` fails and `ps -o tty=`
reports `?` at every rung of the parent chain, because that column only reports a
*controlling* terminal — even though the pty is sitting right there on fd 0/1/2.

`notify-host` handles this: after the `ps` check it also reads
`/proc/<pid>/fd/{0,1,2}` looking for a writable `/dev/pts/*`. Going through a
shell first was the original workaround and still works, but is no longer
required.

If resolution still fails, pin the target explicitly — find the pty with
`ps -eo pid,tty,args | grep claude`:

```bash
NOTIFY_TTY=/dev/pts/2 notify-host "test" "hello"
```

## Verifying

```bash
~/.claude/notify-host "Claude Code" "test notification"
```

Exit status is `0` either way; the signal is the absence of the
`no terminal found` warning on stderr. That only confirms the bytes reached a
pty — whether a notification actually pops depends on the host tmux and terminal.

To exercise the hook path and its derived title, feed it a payload and force the
output to stdout so the escape sequence is inspectable instead of delivered:

```bash
echo '{"message":"test","cwd":"'"$PWD"'"}' |
  NOTIFY_TTY=/dev/stdout ~/.claude/notify-host --hook | cat -v
```
