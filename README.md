# phantom v1.2

A comprehensive multi-file exploitation and automation framework for Grey Hack. Phantom provides integrated network reconnaissance, vulnerability scanning, privilege escalation, and post-exploitation tools in a unified command-line environment.

## Features

- **Network Reconnaissance**: LAN enumeration, port scanning, IP enumeration with port filtering
- **Vulnerability Scanning**: Metaxploit integration for library scanning and exploit discovery
- **Exploitation**: Automated shell and computer object acquisition via known and discovered exploits
- **Privilege Escalation**: ChainSaw integration for automatic root shell acquisition; dictionary-based escalation via `ar`
- **Password Cracking**: Markov chain-based password generation with rainbow table support
- **Remote Operations**: Full file system access (ls, cat, cp, mv, rm, etc.) on compromised targets
- **Stack Management**: Multi-object juggling with push/pop/swap operations
- **Post-Exploitation**: Log corruption, user management, process killing, file enumeration
- **Macro System**: Extensible command macros for automation workflows

## Installation

### Requirements

- Grey Hack (game)... Just incase you didn't know.

### Quick Start

1. **Create phantom directory** on your local machine:
   ```
   /root/ai/pt
   ```

2. **Download or copy phantom modules** to this directory:
    **Mark all src files as importable when compiling to /root/ai/pt**
   - `phantom.src` (main entry point)
   - 
   - `macro.src` (macro system)
   - `macrosys.src` (macro dispatch)
   - `ops.src` (file operations, reconnaissance, exploitation)
   - `hack.src` (hacking primitives)
   - `recon.src` (network reconnaissance)
   - `chainsaw.src` (Chainsaw)
   - `commands.src` (Command dispatcher)
   - `stack.src`(for the... sstack)
   - `var.src`(more macro shit)

4. **Launch phantom**:
   ```
   i. make another dir /root/ai/tp
   ii. compile ar, ls, wb, and phantom into the tp folder
   
   ```

## Usage

### Basic Commands

#### Local File System
```
ls [opt:-l -a] [opt:path]     # List directory
cd [path]                      # Change directory
cat [file]                     # Read file
cp [src] [dst]                 # Copy
mv [src] [dst]                 # Move
rm [opt:-r] [path]             # Delete
mkdir [path]                   # Create directory
chmod [opt:-R] [perms] [path]  # Change permissions
```

#### Network Reconnaissance
```
nmap [ip/pt/lt]                # Network map (show open ports)
ping [ip/pt/lt/bt]             # Test connectivity
whois [public-ip]              # Get IP info
ifconfig                       # Show local network config
set [ip] [opt:-b]              # Set target (public/local/bounce)
```

#### Hacking Workflow

1. **Scan for vulnerabilities**:
   ```
   scan [ip] [port]
   ```
   This scans a target's exposed library for buffer overflow vulnerabilities.

2. **Grab a shell** (if vulnerabilities found):
   ```
   grab [ip] [port] [mem] [val]
   or keep it simple and if you want a shell just type
   grab [ip] [port] 
   ```
   Exploits a discovered vulnerability to obtain shell/computer object.

3. **Escalate to root** (if you have guest shell):
   ```
   autoroot
   ```
   Uses ChainSaw framework to automatically escalate to root.
   ```
    ar
   ```
   Uses Dictonary Attack(recommend using chainsaw though)

5. **Enumerate compromised system**:
   ```
   enum [-l] [-r]
   ```
   Dumps filesystem and creates local archive of target.

6. **Sweep LAN** (from root shell):
   ```
   wstack
   ```
   Bounces across local network, discovers & pushes all devices to stack.

### Object Stack

Manage multiple shells/computers:
```
push                  # Push current object onto stack
pop                   # Pop and set as active
stack                 # List all stacked objects
swap [opt:index]      # Swap active with stack entry
drop [-l] [-r]        # Drop active/local object
```

### Password Cracking

Build a Markov chain-based rainbow table:
```
buildrt [order] [minLen] [maxLen]   # Build in memory (default: 3 3 12)
rtgen [order] [minLen] [maxLen]     # Build and write to ~/phantom/rt/
crack [hash]                         # Crack a hash using table
```
(work in progress)

### Macros

Define and run automated command sequences:
```
mac list                    # List all available macros
mac show [name]             # Show macro code
mac [name]                  # Run macro from /root/ai/mac/
macref                      # Show a quick ref on how to make macros
```

### Remote Operations

When holding a remote shell, use `r` prefix:
```
rls [path]                  # Remote ls
rcat [file]                 # Remote cat
rcp [src] [dst]             # Remote copy
rmv [src] [dst]             # Remote move
rrm [opt:-r] [path]         # Remote delete
rsearch [keyword]           # Remote search
rgrep [pattern] [path]      # Remote grep
rfind [pattern] [path]      # Remote find
```

### Help

```
help                  # Quick reference
help -l               # Local commands
help -n               # Network commands
help -h               # Hacking commands
help -r               # Remote commands
help -a               # All commands
```

## Workflow Examples

### Single Target Exploitation

```
set 203.0.113.45           # Set public target
nmap pt                    # Scan for open ports
scan pt 80                 # Scan port 80 for vulns
grab pt 80 [mem] [val]     # Exploit vulnerability
whoami                     # Check current user (guest)
autoroota                   # Escalate to root
enum -r                    # Dump filesystem
```

### LAN Pivot & Sweep

```
grab pt 80 [mem] [val]     # Get router shell
wstack                     # Sweep LAN, push all devices to stack
ar                         # Escalate first stack entry to root
astack                     # Escalate all shells on stack to root
stackgrep [pattern]        # Search all compromised systems
```

### Anonymous Proxy Chain

```
proxy 3                    # Build 3-hop proxy chain
scan pt 0                  # Scan target through chain
grab pt 0 [mem] [val]      # Exploit through chain
proxyclear                 # Drop chain + cleanup
```

## Exploit Database

Phantom auto-populates `db.txt` with successful exploits as they're discovered:

```
libname|version|memory_address|value
libhttp.so|1.0|0x40000000|0xdeadbeef
```

When you run `grab` without mem/val arguments, phantom checks this database first for known exploits.

## Configuration

### Custom Wordlists

Place `.txt` or `.lst` files in the phantom folder. They'll be automatically imported when building a rainbow table:

```
passwords.txt           # One password per line or space-separated
common-words.lst
leaked-db.txt
```

### Metaxploit Library

Ensure `metaxploit.so` is available:
- Copy from Grey Hack's `/lib/metaxploit.so`
- Or symlink: `ln -s /lib/metaxploit.so ~/phantom/metaxploit.so`

## Troubleshooting

**"metaxploit.so not available"**
- Ensure the library is in `/lib/` or in the phantom folder

**"no vulnerabilities found" after scan**
- Target library may be patched
- Try other ports or targets
- Check if db.txt has entries for this lib version

**"autoroot failed"**
- Ensure you have a guest shell (not root yet)
- Verify rainbow table is built: `buildrt` or `buildrt 3 3 14` for larger set
- Check that `ar` binary exists in phantom folder

**Connection refused / "no net session"**
- Verify target IP is correct: `ping [ip]`
- Confirm port is open: `nmap [ip]`
- Check if target is behind firewall

## Tips & Tricks

- **Use variables**: `nslookup example.com @target_ip` clips result to `@target_ip` for reuse
- **Pipe results**: `randip 5 | ipenum 22 @ssh_ips` generates 5 IPs, filters by SSH port
- **Stack juggling**: Push multiple rooted shells, then `astack` to escalate all at once
- **Silent mode**: Use `nmap` in a macro to disable interactive prompts
- **Log cleanup**: `corlog` corrupts `system.log` after successful exploitation
- **Grep across stack**: `stackgrep password /home` searches all compromised systems at once

## Performance Notes

- **Rainbow table generation** scales with order and length; default (order=3, min=3, max=12) generates ~48k passwords
- **LAN enumeration** uses recursive router traversal; large networks may take time
- **Stack operations** are fast; phantom can handle 20+ objects
- **Macro resolution** supports nested `$(call ...)` syntax for composition

## License

## Author

KuroBeans

---

**Version**: 1.2  
**Last Updated**: 2024  
**Requires**: Grey Hack, GreyScript interpreter
