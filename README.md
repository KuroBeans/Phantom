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
import_code("/root/ai/pt/hack.src")
import_code("/root/ai/pt/ops.src")
import_code("/root/ai/pt/remote.src")
import_code("/root/ai/pt/chainsaw.src")
import_code("/root/ai/pt/stack.src")
```

If you want to install somewhere else, edit those six lines to match. (Note: a handful of comments elsewhere in the codebase reference `/root/ai/tp/` instead of `/root/ai/pt/` when suggesting `build` commands for payloads — that's just an inconsistency in the comment text, not a functional requirement. `build` takes whatever path you actually type, so use the same path you installed phantom at.)

**Steps:**

1. Copy every `.src` file at the repo root (`phantom.src`, `ops.src`, `hack.src`, `remote.src`, `chainsaw.src`, `stack.src`, `macro.src`) into `/root/ai/pt/` on your Grey Hack machine. (`hack.src` now also holds what used to be `core.src`; `macro.src` also holds former `misc.src`; `stack.src` also holds former `vars.src`; `recon.src` was dropped entirely — its content was already fully duplicated inside `remote.src`.)
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

**Object-list clips.** `stack | clip @b` captures the *live* shell/computer objects currently on the stack into `@b` — a separate store from normal string clips, since a shell reference can't be joined into text. Iterate them with `foreach @b | <cmd>` at the prompt (each iteration sets the active `object` to the next one, same engine `stackfor` uses) or `for @x in @b ... endfor` inside a macro. Useful after something like `wstack`, which populates the stack with several targets at once — capture them, then run a command against every one.

**Local vs. remote state.** `lObject`/`myShell`/`myComp` track what you're standing on locally; `object`/`remotePath` track a held remote shell/computer. Most commands are either local (`ls`, `cd`, `ps`) or remote (`rls`, `rcd`, `rps`), with the remote ones acting on whatever's currently held in `object`.

**The stack.** `push`/`pop`/`stack`/`swap` let you juggle multiple shell/computer objects at once — useful when a scan turns up several targets and you don't want to lose the earlier ones.

**Aliases.** `alias name cmd args...` defines a shortcut; `alias -d name` removes it. Persisted to `aliases.txt`.

**Macros.** `.bat`-style scripts stored under `mac`'s macro folder, supporting `if`/`while`/`for`/`switch`/`try`/`catch`/inline `func`/`endfunc` blocks, run via `mac <name>`. `mac trace <name>` runs it the same way but prints each compiled line right before it executes — including the internal control-flow sentinels a `for`/`if`/etc. compiles down to, not just the source text — for tracking down exactly where a misbehaving macro goes wrong. Piping into `mac` feeds the result in as `$1` — e.g. `randip | mac t1` hands the generated ip to the macro as its first arg, with any explicitly typed args shifting to `$2`, `$3`, etc. See [MACROS.md](MACROS.md) for the full syntax guide and how to write one.

**The exploit database (`db.txt`).** Every overflow attempt phantom makes — success or failure, from any command — gets recorded per exact lib+version+mem+val, so a repeat encounter with the same lib+version can skip straight to known-good candidates instead of re-scanning from scratch. `edb` inspects/manages it directly.

**Jumping and local modes.** `jump` copies phantom itself onto a held target and launches it there, giving you an independent phantom session physically running on that machine. `jump -b`/`--bin` uploads just the compiled `phantom` binary instead of the whole toolkit folder, for a quicker round trip when all you need over there is a lib to load and bring back — `jumpbin` does the identical thing with no flag parsing at all, and is the more reliable of the two (added after `-b` proved flaky to detect in testing; if `jump -b` misbehaves, use `jumpbin` instead). Once you're there, `scanlan`/`netmap`/`lanenum` all accept `-l` to operate on that machine's own network directly instead of requiring a separately-held remote shell.

Whatever's held in `globals.activeLib`/`globals.activeMx` when you `jump` automatically carries into the nested session, and automatically comes back when you `exit`/`quit` out of it — no `leave`/`claim` needed for that round trip. This is carried via `gco.local`: `Propagate` stashes both before launching, `phantom.src`'s startup reads and clears it, `exit`/`quit` writes the (possibly updated) current values back, and `Propagate` reads them again the instant `comp.launch()` returns. Contrary to earlier assumptions, a *live* lib/mx handle does survive an `object.launch()` boundary via `gco` (confirmed with `payloads/test_libsurvival_parent.src`/`test_libsurvival_child.src` — a standalone pair of throwaway test scripts, not part of phantom proper), which is what makes carrying the live handle directly workable instead of just a name. `loadlib <name>` loads a lib that's already sitting in the current machine's own `/lib` straight into `globals.activeLib` with no `leave`/`claim` indirection — the natural way to populate it right before a `jump`/`quit` round trip. `libvers` lists every lib in the current machine's `/lib` with its version, and `activelib`/`libdebug` are small debug commands for inspecting what's currently held in `globals.activeLib`/`gco.claimLib`.

`leave`/`claim` are for a different case: handing something to an *independent* phantom session you're not directly jumping into/out of (e.g. two sessions on separate machines that only overlap via `gco`) — e.g. root a target with `autoroot -l` inside a jumped session, then `claim` it from your original session to hold it there instead. This works because `get_custom_object()` is a persistent, player-scoped store shared by every phantom session you run, not tied to a single process. `leave -lib <name> [opt:port]` does the same for a lib: it stores the name (plus, if you're holding a shell at the time, that shell's host ip and the given port), and `claim` first tries loading a fresh handle for it locally from `/lib`, falling back to redialing that ip:port and `dump_lib`-ing it if the name isn't on disk here (e.g. it was pulled off a remote target rather than existing as a real file). Watch out for a same-named-but-different-version local file shadowing the intended remote one, since local load is tried first and doesn't check version. `leave -mx [opt:path]` does the same for a `metaxploit.so` copy (into `globals.activeMx`) — useful since a different metaxploit.so binary (e.g. pulled from a specific target) can decode things your own local one can't. The path is optional; `leave -mx` alone defaults to phantom's own `metaxploit.so`. `uselib` is the first thing that actually consumes both: it scans with `globals.activeMx` if one's held (falling back to the default metaxploit otherwise) and attacks `globals.activeLib`, printing which lib+version it's using before it starts. `uselib -l <lanip>` (or a bare positional inject arg, same thing) bounces onto a LAN device via the overflow's 3rd arg, same trick `scanlib`/`LibScan` use. Plain `claim` auto-detects shell/lib/mx/result in that priority order, which only works cleanly if one thing is pending at a time — if you `leave` more than one kind before claiming any, whichever check comes first always wins and the rest silently never get reached. Pass an explicit `claim -shell` / `claim -lib` / `claim -mx` / `claim -result` to bypass that and grab exactly the one you mean.

**Relaying a lib scan between sessions.** `db.txt` is a per-machine *file*, not something `gco` shares the way a shell or lib name is — a scan recorded in one session's `db.txt` is invisible to another session running elsewhere. To relay a scan anyway: `leave -lib <name>` from session B, `claim -lib` from session A (loads it there), `uselib -s` on session A (scans + records to A's own `db.txt`), `leave -result` on session A (packages every `db.txt` entry for that lib+version into `gco.claimResult`), then `claim -result` back on session B (merges those entries into B's own `db.txt` via `EdbAdd`). Useful for leaning on a long-lived phantom install's accumulated exploit knowledge from a short-lived jumped session without needing to sync `db.txt` files by hand.

## Command reference

Run `help -a` in phantom for the live, always-current list. Grouped summary:

### Local
`ls`, `tree`, `cd`, `cat`, `cp`, `mv`, `rm`, `mkdir`, `touch`, `chmod`, `chown`, `chgrp`, `search`, `ps`, `kill`, `passwd`, `useradd`, `userdel`, `pwd`, `whoami`, `clear`, `decipher`, `cover`, `corlog`, `escalate`, `terminal`, `randip`, `drop`

### Network / recon
`nmap`, `ping`, `nslookup`, `whois`, `whoismail`, `ifconfig`, `set`, `unset`, `ssh`, `scp`, `routerdata`, `proxy`, `proxystatus`, `proxyclear`, `netmap` (`-l` for local), `hacklan`, `lanenum` (`-l` for local), `ipenum`

### Hacking
`edb`, `scan` (`scan ip port lanip -lib libname` delegates to `scanlib`'s db.txt-known-first logic instead of guessing; add `mem val` after the lib name to force an exact pair instead of auto-detecting), `scanlan` (scan/attack whatever's bound to an ip:port; `-l` to scan locally instead of via a held shell), `scanlib` (scan/attack a *named* lib on a held shell's target, with an optional LAN-ip inject), `grab`, `exploit` (interactive candidate picker), `report` (full exploit report — `report [ip] [port]` tries *every* candidate for the bound lib+version live instead of stopping at the first hit like scan/grab, printing a `Hooked: <user> <type>` line for each one that produces something and logging everything to db.txt; known candidates skip the scan/decode step entirely, only a genuinely new lib+version pays for a full scan. Bare `report` or `report [libname] [version]` instead prints the same report straight from db.txt with zero live scanning — just whatever's already known for the most-recently-recorded lib+version, or a specific one you name. Add `-v` to any form for a `MEMORY VULNER TYPE USER` column-aligned table instead of the live per-candidate prints, with requirement text shown under whichever rows have it), `getroot`, `autoroot` (ChainSaw password cracker; `-l` for local), `ar` (dictionary attack via rainbow table; `-l` for local), `enum`, `harvest` (cracked user:pass pairs clip via `harvest | clip @b`), `wifi`, `sniff [opt:-e]` (passively captures SSH/FTP credentials passing through whatever device phantom is physically running on — `jump` onto a router first to snoop its traffic; wraps the game's own `metaxploit.sniffer()`, matching the official in-game sniffer tool exactly. Blocks until it catches a connection, and catching one closes the current terminal session as a side effect — confirmed, no known workaround, so only run it from a session you're OK losing), `smtplist <ip> <port>` (lists every username + email registered on a mail service via `crypto.so`'s `smtp_user_list` — turns a password attack into guessing just the password against confirmed-real accounts instead of both username and password blind), `siphon`, `wstack`, `cascade`, `pwnlan`, `crack`, `buildrt`, `rtgen` (any hash `CrackHash` cracks via the slow official decipher — i.e. one the rainbow table didn't already have — gets learned into `<phantom>/learned.txt`, so it's picked up by every future `buildrt`/`rtgen`'s wordlist-import step instead of being deciphered again from scratch), `jump` (`-b`/`--bin` for a binary-only upload; `jumpbin` does the same with no flag parsing), `leave`/`claim` (hand a held shell/computer, a lib name, a metaxploit.so path, or db.txt scan results off between independent phantom sessions, e.g. across a `jump` — `leave -result`/`claim -result` specifically relays db.txt exploit knowledge for whichever lib is held in `globals.activeLib`), `loadlib` (load a local lib by name straight into `globals.activeLib`), `libvers` (list local `/lib` libs + versions), `activelib`/`libdebug` (debug: inspect `globals.activeLib`/`gco.claimLib`), `plant` (uploads weaklib(s) from `/root/InsecureLibs` — `plant -l lib1 -l lib2 -d /lib` for the held shell, or add `--stack` to sweep every root shell on the object stack instead; no `-l` defaults to `init.so`+`libhttp.so`), `getlogs <sitelistfile> [destfolder]` (bulk site-list auto-exploiter: nslookups + roots whatever's bound to port 80 on each host in the file using phantom's own db.txt-known exploits first, full scan/decode fallback, then downloads `/var/system.log` from every one it roots into `destfolder`, default `/root/Downloads`), `rshell`, `upgrade`, `updatelib`, `chainsaw` (Markov/pregen password cracker — `run`/`load`/`deploy`), `cachereset` (clears the in-session `scanlan`/`report` result caches, which otherwise just grow for the life of the phantom process with nothing pruning them — does *not* touch the rainbow table or your clips/aliases, those aren't disposable cache)

### Remote (act on the held object)
`rls`, `rtree`, `rcd`, `rcat`, `rcp`, `rmv`, `rrm`, `rmkdir`, `rtouch`, `rchmod`, `rchown`, `rchgrp`, `rsearch`, `rps`, `rkill`, `rpasswd`, `ruseradd`, `ruserdel`, `rcorlog`, `rterminal`, `rdecipher`, `rgrep`, `rfind`, `profile [opt:-w] [opt:-p <path>]` (writes a plain-text recon profile for the held target — hostname/ip, access level, cached lib+vuln info if scanned via `scanlan`, key file permissions; prints always, `-w` also saves it to `reports/<hostname>.txt`, `-p <path>` for a custom path), `term`, `mail`, `b` (browser), `file` (file explorer)

### Stack
`push`, `pop`, `stack`, `swap`, `stackrun`, `stackpick`, `stackfor`, `stacktree`, `stacklog`, `stackgrep`, `stackfind`, `astack`, `autoharvest`, `harvestgrep`, `psgrep`, `treegrep`

### Variables, scripting & misc
`clip`, `inc`, `dec`, `math`, `alias`, `ask`, `echo`, `log`, `write` (appends the pipe's result to a file, one entry per line, e.g. `foreach @b | harvest | write creds.txt`; `-l` instead prints the file back numbered, no write), `append` (replaces one specific line — by the number `write <file> -l` showed you — e.g. `append creds.txt -l 3 -t user:realpass`; `-t`'s text can be a clip like `@fix` too), `foreach`, `mac`, `call`/`macall`, `exec`, `code`, `plantstack` (thin alias for `plant --stack` — kept for backward compatibility), `harveststack`, `corlogstack`, `loot [opt:-c] [opt:-p]` (runs `harveststack` across the whole object stack; `-c` also runs `corlogstack` — destructive, off by default — and `-p` also runs `plantstack`, off by default since it only does anything on shell-type objects), `siphon`, `rlan`, `rpub`, `ports` (checks a port list against one ip, or every ip in a comma list — e.g. straight from `randip 10`), `p`, `pre`, `sleep`, `pause`, `exit`/`quit`, `imap` (target info), `uselib` (try overflow with `globals.activeLib`, scanning with `globals.activeMx` if one's held, printing which lib+version it's using — `-s` for recon-only: decode + record candidates to `db.txt` without attacking; `-l lanip` to bounce onto a LAN device — see `claim`)

`./name` launches a local binary; `r./name` launches one on the held remote shell.

## Payload scripts (`payloads/`)

These get uploaded and run *on a target*, not imported at startup:

- **`slb.src`** — LAN-bounce scanner used by `scanlan` against LAN ips: nets into a target from inside its own segment, checks known db exploits first, then falls back to a full scan.
- **`libscan.src`** — used by `scanlib`: loads a named lib directly from wherever it's launched (no `net_use` needed), same known-db-first shortcut, with an optional LAN-ip inject to bounce onward.
- **`wsx.src`** — used by `wstack`'s remote mode: bounces a chosen (or default weak) lib against every LAN ip discovered from the target's perspective.
- **`netmap.src`** — pure recon LAN mapper (`netmap` command): open ports, kernel/firewall info per device, no attacking.
- **`getlogs.src`** — the *original*, standalone site-list log-puller. Not wired to any command and depends on an external `/root/ja/db/remote_service` exploit list this codebase doesn't provide — kept around for reference, but superseded by the `getlogs` command below, which needs no upload/build step and runs entirely off phantom's own `db.txt`.

## Persisted files (auto-created next to phantom's files)

| File | Purpose |
|---|---|
| `db.txt` | Exploit database — lib, version, mem, val, result type, user context for every attempt ever made. |
| `deadlibs.txt` | Lib+version combos confirmed to have zero exploitable vulnerabilities — skips the scan/decode pass next time. |
| `aliases.txt` | Persisted `alias` definitions. |

## Notes

- `wstack`/`slb`/`libscan`/`netmap` all upload a compiled binary to the target and leave it in `/home/guest` afterward for reuse — there's no cleanup command yet, so treat any pivoted-through host as "dirty."
- GreyScript's `import_code` can't take a dynamically computed path, which rules out a true drop-in plugin folder or a runtime `load <path>` command — every module has to be a literal `import_code(...)` line in `phantom.src`.
- Grey Hack caps a single script file at 160,000 characters. `ops.src` had grown close to that ceiling since most commands historically landed there; as of 2026-07-10 its `r*` remote-object commands (`rls`/`rcd`/`rcat`/etc.) moved to `remote.src` to free headroom (`ops.src` ~147k, `remote.src` ~56k). New commands should go in `chainsaw.src` (still the smallest topic file by far, ~8k) unless they genuinely belong with something already in `ops.src`. `hack.src`/`macro.src`/`stack.src` absorbed former `core.src`/`misc.src`/`vars.src` respectively to shrink the install down to fewer files, so they have less spare headroom than their size alone suggests — check current size (`wc -c`) before adding non-trivial code to any of them.
