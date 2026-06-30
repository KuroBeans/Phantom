# PHANTOM MACRO SYSTEM — Complete Reference

## Quick Start

```greyscript
mac list                    // List all macros in /root/ai/mac/
mac show pwn_lan            // Preview macro code
mac pwn_lan @target 0       // Run macro with arguments
macref                      // Show this reference
```

---

## Variables & Clipping

### Store & Retrieve
```greyscript
clip @myvar value           // Store a value
@myvar                      // Use in commands
@myvar.len                  // Get string length (e.g., "5")
```

### Auto-Clipping (outputs → variables)
```greyscript
nslookup example.com @ips   // Result auto-clipped to @ips
whoismail 8.8.8.8 @email   // Email auto-clipped to @email
ipenum 22 @ssh_hosts        // Open port IPs clipped to @ssh_hosts
```

### Macro Arguments
```greyscript
// In macro file /root/ai/mac/exploit.txt:
scan $1 $2
grab $1 $2 [mem] [val]

// Call it:
mac exploit 203.0.113.45 0
// $1 = 203.0.113.45, $2 = 0
```

---

## Pipes & Flow Control

### Pipe (|) — Stop on Fail
```greyscript
scan pt 0 | grab pt 0 [mem] [val]
// If scan fails, grab is skipped
```

### AND (&&) — Same as Pipe
```greyscript
scan pt 0 && grab pt 0 [mem] [val]
// Equivalent to pipe
```

### Semicolon (;) — Always Run Both
```greyscript
scan pt 0 ; grab pt 0 [mem] [val]
// Even if scan fails, grab runs (ignore fail)
```

---

## Conditionals

### Block Conditionals
```greyscript
if root then
  print "You are root"
end if

if shell then
  rls /
elif computer then
  ifconfig
else
  print "No object"
end if
```

### One-Liner Conditionals
```greyscript
if root then autoroot
if shell then rls /
if @target then scan @target 0
if failed then print "error"
```

### Supported Conditions
```
root            // Have root shell
guest           // Have guest shell (not root)
shell           // Holding any shell
computer        // Holding computer object
object          // Have any remote object
stack           // Stack is not empty
target          // Public target set
@var            // Variable is set and not empty
failed          // Previous command failed
true / false    // Literal boolean
```

### Comparisons
```greyscript
if stack > 5 then print "stack full"
if stack == 3 then pop
if @count <= 10 then repeat @count | scan pt 0
if root and shell then autoroot
if not root then print "need root"
```

**Operators**: `==`, `!=`, `<`, `>`, `<=`, `>=`, `and`, `or`, `not`

---

## Loops

### While Loop
```greyscript
while root max 10
  rls /
  print "still root"
endwhile
// Loops while root is true, max 10 iterations
```

### Until Loop
```greyscript
until failed max 5
  scan pt 0
enduntil
// Loops until failed becomes true
```

### Repeat Loop
```greyscript
repeat 5
  ping pt
endrepeat
// Loop exactly 5 times
```

### For..In Loop (Comma List)
```greyscript
clip @targets "203.0.113.1,203.0.113.2,203.0.113.3"
for @ip in @targets
  scan @ip 0
endfor
// Iterate each comma-separated value
```

### For..In Loop (Numeric Range)
```greyscript
for @n in range(1,10)
  ping 192.168.1.@n
endfor
// Loop from 1 to 10 inclusive
```

### Loop Control
```greyscript
while root max 100
  if failed then break      // Exit loop immediately
  if @attempt > 5 then continue  // Skip to next iteration
endwhile
```

---

## Switch/Case

```greyscript
switch @objecttype
case shell
  whoami
  rls /
case computer
  ifconfig
default
  print "no object"
endswitch
```

---

## Error Handling (Try/Catch)

### Basic Try/Catch
```greyscript
try
  scan pt 0
  grab pt 0 [mem] [val]
catch @err
  print "exploit failed: @err"
endtry
```

### Throwing Errors
```greyscript
try
  if not object then _throw "no shell"
  autoroot
catch @e
  print "error: @e"
endtry
```

### Nested Try/Catch
```greyscript
try
  try
    scan pt 0
  catch @e1
    print "scan failed"
  endtry
  grab pt 0 [mem] [val]
catch @e2
  print "grab failed"
endtry
```

---

## Inline Functions

### Define Function
```greyscript
func exploit_target(ip,port)
  scan @ip @port
  grab @ip @port [mem] [val]
  if root then autoroot
endfunc
```

### Call Function
```greyscript
call exploit_target 203.0.113.45 80
// Or with variables:
$(call exploit_target @target 0)
```

### Return Value
```greyscript
func get_shell_status
  if shell then _return "connected"
  if root then _return "root"
  _return "disconnected"
endfunc

call get_shell_status
// Result stored in pipeResult
```

---

## File-Based Macros

### Create Macro File
Save to `/root/ai/mac/your_macro.txt`:

```greyscript
// Single target pivot
// Usage: mac pivot [ip] [port]
clip @target $1
clip @port $2

scan @target @port
if failed then
  print "scan failed"
  _return "failed"
end if

grab @target @port [mem] [val]
if root then
  autoroot
  enum -r
end if
```

### Call It
```greyscript
mac pivot 203.0.113.45 0
```

---

## Foreach Iterator

```greyscript
clip @lanips "192.168.1.1,192.168.1.2,192.168.1.3"
foreach @lanips | scan @each 0
// Runs: scan 192.168.1.1 0
//       scan 192.168.1.2 0
//       scan 192.168.1.3 0
```

---

## Interactive Menus

```greyscript
menu "Choose your action"
  Scan Router | scan pt 0
  Grab Shell | grab pt 0 [mem] [val]
  Escalate | autoroot
  View Stack | stack
endmenu
```

User selects with number or label.

---

## Real-World Examples

### Example 1: Auto-Escalate Workflow
```greyscript
set @target
nmap @target
scan @target 0
if failed then print "no exploits found"
grab @target 0 [mem] [val]
if shell then
  autoroot
  enum -r
  push
else
  print "failed to get shell"
end if
```

### Example 2: LAN Sweep with Error Handling
Save as `/root/ai/mac/sweep.txt`:

```greyscript
// Usage: mac sweep [port]
clip @port $1
lanenum @lanips

for @ip in @lanips
  try
    scan @ip @port
    grab @ip @port [mem] [val]
    if root then
      print "[+] @ip ROOTED"
      push
    end if
  catch @err
    print "[-] @ip: @err"
  endtry
endfor

print "sweep complete"
stack
```

Call it: `mac sweep 22`

### Example 3: Retry Logic with Sleep
```greyscript
clip @attempts 0
while @attempts < 3 max 3
  print "attempt @attempts"
  scan pt 0
  if not failed then break
  sleep 2
  clip @attempts $(@attempts + 1)
endwhile

if failed then
  print "3 attempts failed"
else
  grab pt 0 [mem] [val]
end if
```

### Example 4: Multi-Target Dictionary Attack
```greyscript
buildrt 3 3 14              // Build bigger rainbow table
clip @targets "203.0.113.1,203.0.113.2,203.0.113.3"

for @ip in @targets
  try
    scan @ip 22
    grab @ip 22 [mem] [val]
    if shell then
      autoroot
      push
    end if
  catch @e
    print "[-] @ip failed"
  endtry
endfor

astack                      // Escalate all at once
```

---

## Variable Operations

### Implicit Math
```greyscript
clip @count 5
repeat @count | ping pt
// Converts @count to number automatically
```

### String Expansion
```greyscript
clip @base 192.168.1
clip @last 100
ping @base.@last
// Results in: ping 192.168.1.100
```

### List Length
```greyscript
clip @ips "1.1.1.1,2.2.2.2,3.3.3.3"
if @ips.len > 5 then
  print "too many targets"
end if
// @ips.len = "3"
```

---

## Tips & Tricks

### 1. Chain Commands Efficiently
```greyscript
randip 10 | ipenum 22 @ssh_hosts
// Generate 10 IPs → filter by port 22 → clip to @ssh_hosts
```

### 2. Reuse Variables Across Macros
```greyscript
clip @global_target 203.0.113.45
mac exploit @global_target     // Passed as $1
```

### 3. Conditional Piping
```greyscript
if shell then
  rls / | rgrep password @creds
else
  print "need shell first"
end if
```

### 4. Silent Macro Mode
Macros run non-interactively (no prompts), perfect for automation:
```greyscript
nmap pt              // Won't ask "Set as target?" when in macro
scan pt 0            // Runs silently
```

### 5. Break Out Early
```greyscript
while true max 100
  grab pt 0 [mem] [val]
  if shell then break
  sleep 1
endwhile
```

### 6. Nested Calls
```greyscript
func full_exploit(ip)
  scan @ip 0
  $(call grab_shell @ip 0)
endfunc

func grab_shell(ip, port)
  grab @ip @port [mem] [val]
  if root then autoroot
endfunc
```

---

## Common Patterns

### Pattern 1: Scan → Grab → Root
```greyscript
scan pt 0
grab pt 0 [mem] [val]
autoroot
enum -r
```

### Pattern 2: Iterate & Attack
```greyscript
for @ip in @lanips
  scan @ip 0
  grab @ip 0 [mem] [val]
endfor
astack
```

### Pattern 3: Resilient Loop
```greyscript
while true max 50
  try
    scan @ip 0
    grab @ip 0 [mem] [val]
    if shell then break
  catch @e
    print "retry..."
    sleep 2
  endtry
endwhile
```

### Pattern 4: Conditional Stack
```greyscript
if shell then push
if root then push
stack
if objectStack > 5 then astack
```

---

## Debugging

### Print Values
```greyscript
clip @myvar "test"
print @myvar            // Output: test
```

### Check Conditions
```greyscript
if root then print "root" else print "not root"
if shell then print "shell" else print "no shell"
if @var then print "@var set" else print "@var empty"
```

### Use Temporary Variables
```greyscript
clip @debug "starting exploit"
print @debug
// ... do stuff ...
clip @debug "exploit complete"
print @debug
```

---

## Macro File Locations

All macros stored in: `/root/ai/mac/`

Filename format: `name.txt` or just `name`

Example file: `/root/ai/mac/pwn_lan.txt`

Call it: `mac pwn_lan [args]`

---

## Summary

| Feature | Syntax | Example |
|---------|--------|---------|
| **Variables** | `clip @var value` | `clip @target 8.8.8.8` |
| **Expand** | `@varname` | `scan @target 0` |
| **Pipe** | `cmd1 \| cmd2` | `scan pt 0 \| grab pt 0 [m] [v]` |
| **If** | `if COND then CMD` | `if root then autoroot` |
| **While** | `while COND max N ... endwhile` | `while root max 10 ... endwhile` |
| **For** | `for @var in LIST ... endfor` | `for @ip in @lanips ... endfor` |
| **Try** | `try ... catch @e ... endtry` | `try scan pt 0 catch @err print @err endtry` |
| **Func** | `func name ... endfunc` | `func exploit(ip) scan @ip 0 endfunc` |
| **Menu** | `menu TITLE ... endmenu` | `menu "Pick" ... Scan \| scan pt 0 ... endmenu` |

---

**For more help**: Type `macref` in phantom to see this reference in-game.
