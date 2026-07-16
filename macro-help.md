# Writing phantom macros

A macro is a plain-text script — think a `.bat` file — that runs a sequence of phantom commands with variables, conditionals, loops, and functions. This doc covers how to write one; run `macref` in phantom any time for a terse in-game cheat sheet of the same syntax.

## Where they live

Macros are files in `/root/ai/mac/` on the machine phantom is running on. The filename (minus `.txt`) is the name you invoke it by:

```
/root/ai/mac/hunt.txt      ->  mac hunt
/root/ai/mac/rootall.txt   ->  mac rootall
```

The `.txt` extension is a convention, not a hard requirement — `mac`/`call` will also find a file with no extension if `<name>.txt` doesn't exist.

## Creating one

1. Open the in-game code editor and create a text file at `/root/ai/mac/<name>.txt`.
2. Write one phantom command per line (see syntax below).
3. Save it — no build step needed, macros are read and compiled fresh every time you run them.

```
mac list                 # see every macro currently in /root/ai/mac/
mac show <name>           # preview a macro's lines without running it
mac <name> [args]         # run it
mac trace <name> [args]   # run it, printing each compiled line right before it executes
```

`mac trace` is for debugging a macro that isn't doing what you expect — it prints the *compiled* line, not just your source text, so you'll see the internal sentinels a `for`/`if`/`while`/etc. actually compiles down to (e.g. `__for__...`) as they run, one at a time. Useful for confirming a loop is iterating the values you think it is, or that a conditional is actually taking the branch you expect.

## Arguments

Whatever you pass after the macro name shows up inside the macro as `$1` through `$9`:

```
// /root/ai/mac/hunt.txt
// usage: mac hunt <port>
netmap -l
scan pt $1
grab pt $1
```

```
mac hunt 80
```

If a macro references `$4` but you only passed 3 args, phantom prints a warning and leaves it blank rather than failing silently.

**Piped input becomes `$1`.** `randip | mac hunt` hands the generated ip in as the macro's first arg, without needing an explicit `@clip` round-trip first — same as any other command consuming a pipe. Any args you also type after the macro name shift down to fill `$2`, `$3`, etc.:

```
randip | mac hunt 80
// $1 = the piped ip, $2 = "80"
```

## Comments

A line starting with `//` is ignored entirely (not even shown to the parser) — same convention as the rest of the codebase.

## Flow between commands

These work on a single line, no block needed:

| Syntax | Meaning |
|---|---|
| `cmd1 \| cmd2` | pipe — stop the line if `cmd1` fails |
| `cmd1 && cmd2` | AND — stop if `cmd1` fails |
| `cmd1 ; cmd2` | always run both, regardless of failure |

## Conditionals

One-liner:
```
if <cond> then <cmd>
if <cond> | <cmd>          // same thing, | instead of then
```

Block form:
```
if <cond>
    ...
elif <cond>
    ...
else
    ...
endif
```

**Conditions:**
| Condition | True when |
|---|---|
| `root` | holding a shell **and** it has root |
| `guest` | holding a shell and it doesn't have root |
| `shell` | held object is a shell |
| `computer` | held object is a computer |
| `object` | anything at all is held |
| `stack` | the object stack has at least one entry |
| `target` (or `pt`) | a public target is set |
| `failed` (or `pipefailed`) | the last pipeline step failed |
| `@var` | the clip is set and non-empty |
| `true` / `false` | constants |

Prefix any condition with `not` (or `no`) to negate it. Conditions also support comparisons: `stack >= 3`, `shell == root`, `object == null`, `@count == 5`, etc.

Combine with `and`/`or` (no parentheses, evaluated left to right by whichever operator appears first):
```
if root and stack >= 1 then autoharvest
```

## Loops

```
while <cond> [max N]
    ...
endwhile

until <cond> [max N]        // inverse of while
    ...
enduntil

repeat N
    ...
endrepeat

for @var in @list           // iterates a comma-separated clip
    ...                      // reference the current item as @var
endfor

for @var in range(5,10)      // iterates 5..10
    ...
endfor
```

`max N` on `while`/`until` caps iterations as a safety net (default cap is effectively unlimited). `break`/`continue` work inside any loop.

**A failed pipe stage inside a loop body skips to the next iteration, not the whole macro.** If a line like `scan @x 80 | grab @x 80` fails partway (e.g. `scan` finds nothing on that particular item), the loop moves on to the next item instead of aborting — same recovery behavior for `for`/`for @x in @objlist`/`while`/`until`/`repeat` alike. This includes a failure on a loop's *last* item — anything you write after `endfor`/`endwhile` still runs, it doesn't get silently dropped just because the final iteration happened to fail.

**Not the same as `foreach`:** `foreach @list | cmd @each` is a separate, prompt-level construct (works outside macros too, straight at the interactive phantom prompt) — it queues one pipeline run per list item, substituting `@each`. The `for ... endfor` block above is macro-only and lets you name the loop variable yourself.

**Iterating live objects, not just strings:** if `@list` is an object-list clip (from `stack | clip @b` — see the README's "Object-list clips" section) rather than a normal string clip, `for @x in @b ... endfor` behaves differently: it can't substitute a live shell/computer into `@x` as text, so instead it sets the active `object` to the current item for the duration of each iteration's body. Write the body the same way you would for `stackfor` — reference the held target implicitly (`harvest`, `scan pt 80`, etc.), not via `@x`.

```
// example: harvest every object wstack found
stack | clip @b
for @x in @b
    harvest
endfor
```

## Switch

```
switch @var
case value1
    ...
case value2
    ...
default
    ...
endswitch
```

## Error handling

```
try
    ...
    _throw "something went wrong"
catch @err
    echo @err
endtry
```

`catch` without a variable name (`catch` alone, no `@err`) still catches, it just doesn't capture the message.

## Functions

Inline functions, defined and callable within the same macro (or from another macro, since `call` looks up both):

```
func escalate_and_grab(ip, port)
    scan $1 $2
    grab $1 $2
    if root then echo "got root on $1"
endfunc

call escalate_and_grab 1.2.3.4 80
```

`_return <value>` inside a func sets the value `call`/`macall` gets back. `call`/`macall` also runs a *file* macro by name (not just an inline `func`) — same command either way, it checks inline funcs first, then `/root/ai/mac/`.

## Menus

Interactive choice prompt, pauses the macro until you pick one:

```
menu Pick a target
1 | scan pt 80
2 | scan pt 8080
q | exit
endmenu
```

Each line is `<label> | <command>` — typing the label at the prompt runs that command and resumes the macro.

## Misc

```
sleep 5     // wait 5 seconds
pause       // wait for Enter
```

## A complete example

```
// /root/ai/mac/rootall.txt
// usage: mac rootall
echo "mapping local network..."
netmap -l
lanenum -l @targets

for @ip in @targets
    scan @ip 80
    if root then
        echo "rooted @ip"
    else
        scan @ip 8080
        if root then echo "rooted @ip via 8080"
    endif
endfor

echo "done"
```
