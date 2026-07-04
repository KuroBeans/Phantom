# phantom

A GreyScript hacking toolkit for [Grey Hack](https://store.steampowered.com/app/605230/Grey_Hack/) — a custom shell that layers piping, variables, aliases, macros, an object stack, and a persistent exploit database on top of the game's scripting API, plus a large set of recon/exploitation commands for both local and remote targets.

Architecturally, each command is self-registering: a topic file (`ops.src`, `hack.src`, etc.) defines `CmdFoo = function(inp) ... end function` and immediately follows it with `CommandTable["foo"] = @CmdFoo`. Adding or finding a command is a one-file, one-location affair — there's no separate manifest to keep in sync.

## Requirements

- Grey Hack, with `metaxploit.so` and `crypto.so` available (either at `/lib/` or alongside phantom's own files).
- A computer with enough disk space for phantom's `.src` files plus whatever `db.txt`/`deadlibs.txt`/`aliases.txt` grow to over a session.

## Installation

GreyScript's `import_code` requires a literal path known when the script is loaded — it can't take a computed or relative path. Because of that, **phantom must live at `/root/ai/pt/`** on the machine you run it from, since that's the path hardcoded into `phantom.src`'s imports:

```
import_code("/root/ai/pt/macro.src")
import_code("/root/ai/pt/core.src")
import_code("/root/ai/pt/recon.src")
import_code("/root/ai/pt/hack.src")
import_code("/root/ai/pt/ops.src")
import_code("/root/ai/pt/remote.src")
import_code("/root/ai/pt/chainsaw.src")
import_code("/root/ai/pt/stack.src")
import_code("/root/ai/pt/vars.src")
import_code("/root/ai/pt/misc.src")
```

If you want to install somewhere else, edit those ten lines to match. (Note: a handful of comments elsewhere in the codebase reference `/root/ai/tp/` instead of `/root/ai/pt/` when suggesting `build` commands for payloads — that's just an inconsistency in the comment text, not a functional requirement. `build` takes whatever path you actually type, so use the same path you installed phantom at.)

**Steps:**

1. Copy every `.src` file at the repo root (`phantom.src`, `core.src`, `ops.src`, `hack.src`, `recon.src`, `remote.src`, `chainsaw.src`, `stack.src`, `vars.src`, `misc.src`, `macro.src`) into `/root/ai/pt/` on your Grey Hack machine.
2. Copy the `data/` folder (`pregens.src`, `samples.src`) alongside them — `chainsaw.src` loads these as ChainSaw's password wordlists, falling back to a smaller built-in list if they're missing.
3. Make sure `metaxploit.so` and `crypto.so` are reachable, either in `/lib/` or copied into `/root/ai/pt/` next to `phantom.src`.
4. Build `phantom.src` in-game (`build /root/ai/pt/phantom.src /root/ai/pt`) to produce the runnable `phantom` binary.
5. Copy the `payloads/` folder in too (`getlogs.src`, `libscan.src`, `netmap.src`, `slb.src`, `wsx.src`). These aren't imported at startup — they're separate scripts that get uploaded to remote targets on demand and only need building the first time each is actually used (phantom prints the exact `build` command to run if it can't find a compiled copy).

## First run

```
./phantom
```

On startup phantom loads `metaxploit.so`/`crypto.so`, auto-creates/loads `db.txt` (exploit database), `deadlibs.txt` (libs confirmed to have nothing exploitable), and `aliases.txt` (persisted command aliases) if present in the same folder, then drops you at a prompt. Type `help` for the current command list (`help -a` for everything, or `-l`/`-n`/`-h`/`-r` for local/network/hacking/remote subsets).

Headless mode: `phantom --rshell [port]` installs and starts an rshell daemon on the local machine instead of dropping into the interactive shell (defaults to port 1222).

## Core concepts

**Piping.** `scan pt 0 | grab pt 0` — pipe a command's result into the next. `cmd |> other` queues `other` to run as a separate stage afterward, once the first cmd completes (including anything it queued via macros/foreach).

**Clips (`@var`).** Store a result by ending a command with a bare `@name` (e.g. `randip @ip`), then reference it later with `@ip`. `@ip.len` gives its length (or comma-count for a list-like string). `@o key` reads any top-level custom-object index directly (not just clips). Clips persist across restarts via the game's custom object.

**Local vs. remote state.** `lObject`/`myShell`/`myComp` track what you're standing on locally; `object`/`remotePath` track a held remote shell/computer. Most commands are either local (`ls`, `cd`, `ps`) or remote (`rls`, `rcd`, `rps`), with the remote ones acting on whatever's currently held in `object`.

**The stack.** `push`/`pop`/`stack`/`swap` let you juggle multiple shell/computer objects at once — useful when a scan turns up several targets and you don't want to lose the earlier ones.

**Aliases.** `alias name cmd args...` defines a shortcut; `alias -d name` removes it. Persisted to `aliases.txt`.

**Macros.** `.bat`-style scripts stored under `mac`'s macro folder, supporting `if`/`while`/`for`/`switch`/`try`/`catch`/inline `func`/`endfunc` blocks, run via `mac <name>`.

**The exploit database (`db.txt`).** Every overflow attempt phantom makes — success or failure, from any command — gets recorded per exact lib+version+mem+val, so a repeat encounter with the same lib+version can skip straight to known-good candidates instead of re-scanning from scratch. `edb` inspects/manages it directly.

**Jumping and local modes.** `jump` copies phantom itself onto a held target and launches it there, giving you an independent phantom session physically running on that machine. Once you're there, `scanlan`/`netmap`/`lanenum` all accept `-l` to operate on that machine's own network directly instead of requiring a separately-held remote shell. Since jumped sessions are otherwise independent, `leave` (in one session) and `claim` (in another) hand things between them — e.g. root the target with `autoroot -l` inside the jumped session, then `claim` it from your original session to hold it there instead. This works because `get_custom_object()` is a persistent, player-scoped store shared by every phantom session you run, not tied to a single process. `leave -lib <name>` does the same for a lib, with one difference: a live lib handle can't survive the trip (confirmed — see `payloads/slb.src`'s notes on why it always loads a fresh handle instead of reusing one), so only the lib's *name* crosses over, and `claim` loads a fresh handle for it locally into `globals.activeLib`. `leave -mx [opt:path]` does the same for a `metaxploit.so` copy (into `globals.activeMx`) — useful since a different metaxploit.so binary (e.g. pulled from a specific target) can decode things your own local one can't. The path is optional; `leave -mx` alone defaults to phantom's own `metaxploit.so`. `uselib` is the first thing that actually consumes both: it scans with `globals.activeMx` if one's held (falling back to the default metaxploit otherwise) and attacks `globals.activeLib`. Plain `claim` auto-detects shell/lib/mx/result in that priority order, which only works cleanly if one thing is pending at a time — if you `leave` more than one kind before claiming any, whichever check comes first always wins and the rest silently never get reached. Pass an explicit `claim -shell` / `claim -lib` / `claim -mx` / `claim -result` to bypass that and grab exactly the one you mean.

**Relaying a lib scan between sessions.** `db.txt` is a per-machine *file*, not something `gco` shares the way a shell or lib name is — a scan recorded in one session's `db.txt` is invisible to another session running elsewhere. To relay a scan anyway: `leave -lib <name>` from session B, `claim -lib` from session A (loads it there), `uselib -s` on session A (scans + records to A's own `db.txt`), `leave -result` on session A (packages every `db.txt` entry for that lib+version into `gco.claimResult`), then `claim -result` back on session B (merges those entries into B's own `db.txt` via `EdbAdd`). Useful for leaning on a long-lived phantom install's accumulated exploit knowledge from a short-lived jumped session without needing to sync `db.txt` files by hand.

## Command reference

Run `help -a` in phantom for the live, always-current list. Grouped summary:

### Local
`ls`, `tree`, `cd`, `cat`, `cp`, `mv`, `rm`, `mkdir`, `touch`, `chmod`, `chown`, `chgrp`, `search`, `ps`, `kill`, `passwd`, `useradd`, `userdel`, `pwd`, `whoami`, `clear`, `decipher`, `cover`, `corlog`, `escalate`, `terminal`, `randip`, `drop`

### Network / recon
`nmap`, `ping`, `nslookup`, `whois`, `whoismail`, `ifconfig`, `set`, `unset`, `ssh`, `scp`, `routerdata`, `proxy`, `proxystatus`, `proxyclear`, `netmap` (`-l` for local), `hacklan`, `lanenum` (`-l` for local), `ipenum`

### Hacking
`edb`, `scan`, `scanlan` (scan/attack whatever's bound to an ip:port; `-l` to scan locally instead of via a held shell), `scanlib` (scan/attack a *named* lib on a held shell's target, with an optional LAN-ip inject), `grab`, `exploit` (interactive candidate picker), `getroot`, `autoroot` (ChainSaw password cracker; `-l` for local), `ar` (dictionary attack via rainbow table; `-l` for local), `enum`, `harvest`, `wifi`, `siphon`, `wstack`, `cascade`, `pwnlan`, `crack`, `buildrt`, `rtgen`, `jump`, `leave`/`claim` (hand a held shell/computer, a lib name, a metaxploit.so path, or db.txt scan results off between independent phantom sessions, e.g. across a `jump`), `plant`, `rshell`, `upgrade`, `updatelib`, `chainsaw` (Markov/pregen password cracker — `run`/`load`/`deploy`)

### Remote (act on the held object)
`rls`, `rtree`, `rcd`, `rcat`, `rcp`, `rmv`, `rrm`, `rmkdir`, `rtouch`, `rchmod`, `rchown`, `rchgrp`, `rsearch`, `rps`, `rkill`, `rpasswd`, `ruseradd`, `ruserdel`, `rcorlog`, `rterminal`, `rdecipher`, `rgrep`, `rfind`, `term`, `mail`, `b` (browser), `file` (file explorer)

### Stack
`push`, `pop`, `stack`, `swap`, `stackrun`, `stackpick`, `stackfor`, `stacktree`, `stacklog`, `stackgrep`, `stackfind`, `astack`, `autoharvest`, `harvestgrep`, `psgrep`, `treegrep`

### Variables, scripting & misc
`clip`, `inc`, `dec`, `math`, `alias`, `ask`, `echo`, `log`, `foreach`, `mac`, `call`/`macall`, `exec`, `code`, `plantstack`, `harveststack`, `corlogstack`, `siphon`, `rlan`, `rpub`, `ports`, `p`, `pre`, `sleep`, `pause`, `exit`/`quit`, `imap` (target info), `uselib` (try overflow with `globals.activeLib`, scanning with `globals.activeMx` if one's held — `-s` for recon-only: decode + record candidates to `db.txt` without attacking — see `claim`)

`./name` launches a local binary; `r./name` launches one on the held remote shell.

## Payload scripts (`payloads/`)

These get uploaded and run *on a target*, not imported at startup:

- **`slb.src`** — LAN-bounce scanner used by `scanlan` against LAN ips: nets into a target from inside its own segment, checks known db exploits first, then falls back to a full scan.
- **`libscan.src`** — used by `scanlib`: loads a named lib directly from wherever it's launched (no `net_use` needed), same known-db-first shortcut, with an optional LAN-ip inject to bounce onward.
- **`wsx.src`** — used by `wstack`'s remote mode: bounces a chosen (or default weak) lib against every LAN ip discovered from the target's perspective.
- **`netmap.src`** — pure recon LAN mapper (`netmap` command): open ports, kernel/firewall info per device, no attacking.
- **`getlogs.src`** — pulls readable log/credential data off a target.

## Persisted files (auto-created next to phantom's files)

| File | Purpose |
|---|---|
| `db.txt` | Exploit database — lib, version, mem, val, result type, user context for every attempt ever made. |
| `deadlibs.txt` | Lib+version combos confirmed to have zero exploitable vulnerabilities — skips the scan/decode pass next time. |
| `aliases.txt` | Persisted `alias` definitions. |

## Notes

- `wstack`/`slb`/`libscan`/`netmap` all upload a compiled binary to the target and leave it in `/home/guest` afterward for reuse — there's no cleanup command yet, so treat any pivoted-through host as "dirty."
- GreyScript's `import_code` can't take a dynamically computed path, which rules out a true drop-in plugin folder or a runtime `load <path>` command — every module has to be a literal `import_code(...)` line in `phantom.src`.
- Grey Hack caps a single script file at 160,000 characters. `ops.src` is already close to that ceiling (~151k) since it's where most commands have historically landed — new commands should go in a smaller topic file (`misc.src`, `vars.src`, `chainsaw.src`, etc.) unless they genuinely belong with something already in `ops.src`.
