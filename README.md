# STAMP: The Undo Button for Your Code

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/Bash-4.0%2B-green.svg)](https://www.gnu.org/software/bash/)
[![Size](https://img.shields.io/badge/Size-~300%20lines-orange.svg)](https://github.com/Curiouskite/STAMP)
[![Repo](https://img.shields.io/badge/GitHub-Curiouskite%2FSTAMP-black.svg)](https://github.com/Curiouskite/STAMP)

**A brutally simple directory time machine for developers who hate breaking their flow.**

You've been there: three hours into a refactor, hundreds of files changed, one bold experiment... and everything collapses. Git's a mess, your IDE's history won't cut it, and manually undoing is a nightmare. **stamp** gives you an instant rewind button for any folder, no commits required.

---

### Table of Contents

- [Why stamp?](#why-stamp)
- [Installation](#installation)
- [Core Concepts](#core-concepts)
- [Command Reference](#command-reference)
- [Real-World Workflows](#real-world-workflows)
- [How It Works](#how-it-works)
- [Comparison](#comparison)
- [Pro Tips](#pro-tips)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

---

## Why stamp?

Traditional tools are either too heavy or too limited:

- **Git commits** pollute history with broken experiments
- **Backups** take forever and capture your entire system
- **Manual copying** is slow and error-prone

**stamp** is different. It creates a perfect, lightweight snapshot of *exactly* where you are, right now. When disaster strikes, `stamp back` restores that folder—and *only* that folder—to its saved state in seconds. No network, no cloud, no waiting.

### What Makes It Special

- **Surgical precision**: Affects only the directory you snapshot
- **Instant operations**: Creates/restores in milliseconds for typical projects
- **Zero config**: Works out of the box, no setup files needed
- **Flow-aware**: Designed to keep you in the zone
- **Metadata-rich**: Stores timestamps, paths, and custom messages
- **Smart defaults**: Does the obvious thing without asking

---

## Installation

Drop it in your `~/bin` and make it executable:

```bash
wget https://raw.githubusercontent.com/Curiouskite/STAMP/main/stamp -O ~/bin/stamp
chmod +x ~/bin/stamp
```

Or clone and symlink:

```bash
git clone https://github.com/Curiouskite/STAMP.git
ln -s $(pwd)/STAMP/stamp ~/bin/stamp
```

**Requirements**: Bash 4.0+, standard Unix tools (`cp`, `rm`, `find`, `stat`, `du`).

---

## Core Concepts

### The Stamp Lifecycle

```bash
# 1. Create a snapshot
stamp "before-rewrite"

# 2. Go wild—break things fearlessly
rm -rf src/* && mv components/ src/

# 3. Instant rewind
stamp back
```

### Directory Context

**stamp** always operates on your **current working directory** (CWD). It creates a metaphorical "save point" you can return to later. Two modes exist:

- **Normal mode**: Snapshots the exact folder you're in
- **Root mode**: Snapshots the entire project (top-level directory from HOME)(nothing to do with real root its not root user tool)

---

## Command Reference

### `stamp [message]`

Create a snapshot of the current directory with an optional message.

```bash
# Quick save while debugging
stamp

# Save with context for later
stamp "working-state-before-api-change"
```

**Output:**
```
✓ Stamped: my-project/src → .stamps/2024-01-15/1src@working-state-before-api-change
```

### `stamp root [message]`

Snapshot your entire project from HOME root. Perfect for cross-directory refactors.

```bash
# Save whole project before sweeping changes
stamp root "pre-monorepo-migration"
```

**Output:**
```
✓ Stamped: projects/my-app → .stamps/2024-01-15/HOME@pre-monorepo-migration
```

### `stamp list`

Show all stamps for the current directory context.

```bash
cd ~/projects/frontend
stamp list
```

**Output:**
```
Stamps for 'frontend':
  1) frontend               2.3MB   3h ago
  2) 1frontend             2.1MB   Yesterday
  3) 2frontend@wip        2.5MB   5d ago  (@wip)
```

### `stamp peek [ref]`

Enter a stamped directory in a subshell to inspect it. Type `exit` to return.

```bash
# Peek at the most recent stamp
stamp peek

# Peek at stamp #2
stamp peek 2

# Search by message
stamp peek wip
```

**Output:**
```
→ Entering 2frontend@wip (type 'exit' to return)
---
((2frontend@wip)) $ ls -la
((2frontend@wip)) $ exit
← Back in frontend
```

### `stamp back [ref]`

**The magic button**. Restore your directory to a stamped state.

```bash
# Restore last stamp (no questions asked)
stamp back

# Restore specific stamp
stamp back 2

# Restore by message fragment
stamp back api-change
```

**Output:**
```
⚠ DESTRUCTIVE ACTION
  Will replace: /home/user/projects/frontend
  With:         2frontend@wip
  From:         5d ago

  Continue? (y/N): y
✓ Restored
```

### `stamp delete [ref|all]`

Permanently remove stamps.

```bash
# Delete last stamp
stamp delete

# Delete by reference number
stamp delete 3

# Nuclear option
stamp delete all
```

### `stamp undo`

Delete the *last created* stamp from the log. Your "oops, didn't mean to save that" button.

```bash
stamp "temp-debug"
stamp undo  # Removes it instantly
```

---

## Real-World Workflows

### The Experimental Refactor

```bash
cd ~/projects/auth-system
stamp "stable-v2.1"

# Start aggressive refactoring
mv lib/ src/ && find . -name "*.js" -exec sed -i 's/require/import/g' {} \;

# Tests fail catastrophically
stamp back  # Instantly back to stable
```

### The Cross-Directory Change

```bash
cd ~/projects/my-app
stamp root "all-green-tests"

# Modify across frontend/, backend/, shared/
# ...something breaks in another directory you forgot about...

# Restore everything at once
stamp root back
```

### The Debugging Time Capsule

```bash
cd ~/projects/api
stamp "bug-repro-payload"

# Add logging, breakpoints, print statements
# Mess up configuration files

# Clean slate for next attempt
stamp back && stamp "bug-repro-attempt-2"
```

### The Code Review Prep

```bash
# Save messy WIP state
stamp "wip-messy-experiments"

# Clean up for PR
git checkout -b feature/clean-version
# ...polish...

# Need to check something in the old version
stamp peek wip-messy  # Browse without restoring
```

---

## How It Works

### Storage Architecture

Stamps live in `~/.stamps/` organized by date:

```
~/.stamps/
├── 2024-01-15/
│   ├── frontend               # First stamp of the day
│   ├── 1frontend@api-fix      # Second stamp, with message
│   └── HOME@refactor          # Full project snapshot
└── 2024-01-16/
    └── 2frontend@wip          # Third stamp overall
```

Each stamp contains:
- Full directory copy (using `cp -r`)
- Metadata file (`.stamp_info`):
  ```
  timestamp=1705341234.567890
  source_path=/home/user/projects/frontend
  message=api-fix
  ```

### The Stamp Log

Recent stamps are tracked in `~/.stamps/.stamp_log` for quick undo operations. It's capped at 100 entries to prevent bloat.

### Performance Characteristics

- **Save**: `cp -r` speed—essentially disk copy performance
- **Restore**: `rm -rf && cp -r`—seconds for GB-scale directories
- **List**: Near-instant, metadata cached
- **Peek**: Zero-copy subshell, instant entry/exit

---

## Comparison

| Feature | stamp | Git | Backup Tools |
|---------|-------|-----|--------------|
| **Speed** | ⚡ Instant | ⚡ Fast | 🐌 Slow |
| **Scope** | Directory | Project | System |
| **History** | No pollution | Polluted | N/A |
| **Size** | Lightweight | Minimal | Heavy |
| **Use case** | Experimentation | Versioning | Disaster recovery |
| **Learning curve** | Zero | Moderate | High |

**When to use what:**

- **stamp**: Hourly experimentation, "what if" scenarios
- **Git**: Permanent changes, collaboration, code history
- **Backups**: Hardware failure, ransomware, system migration

---

## Pro Tips

### 1. Alias for Speed

```bash
alias s='stamp'
alias sb='stamp back'
alias sl='stamp list'
```

### 2. Pre-commit Hook Integration

```bash
# .git/hooks/pre-commit
stamp "pre-commit-safety-net"
```

### 3. Daily Workflow

```bash
# Start of day
cd ~/projects/my-app
stamp "morning-baseline"

# Every major change
stamp back && stamp "before-dependency-upgrade"
npm update react
# ...tests fail...
stamp back  # Back to safety
```

### 4. Message Conventions

Use `@tag` syntax for filtering:

```bash
stamp "experiment@redux"      # Group experiments
stamp "bug@auth"              # Tag by feature
stamp back redux              # Restore last redux experiment
```

### 5. Stamping HOME Safely

The script intelligently excludes `~/.stamps` when snapshotting HOME, preventing recursive storage explosions.

---

## Troubleshooting

### "Must be in HOME directory"

**stamp** only works within your home directory for security. Navigate to `~/projects`, not `/opt/projects`.

### Disk Space Warnings

Each stamp is a full copy, not a diff. Monitor `~/.stamps` size:

```bash
du -sh ~/.stamps
stamp delete all  # Clean house
```

### Accidental Restores

No built-in "undo restore" exists—by design. Create a stamp *before* restoring:

```bash
stamp "just-in-case"
stamp back 1      # Safe to experiment
```

### Permission Errors

If `stamp back` fails on system files, you may need to preserve permissions manually:

```bash
# Instead of stamp back:
sudo rm -rf /target/path && sudo cp -r ~/.stamps/... /target/path
```

---

## Contributing

stamp is ~300 lines of pure Bash. Contributions welcome:

```bash
git clone https://github.com/Curiouskite/STAMP.git
cd STAMP
# Make changes
./test.sh  # Run the test suite
```

Areas for improvement:
- Optional `rsync` backend for incremental copies
- Compression for long-term stamps
- Remote stamp storage via SSH

---

## License

MIT License. See [LICENSE](https://github.com/Curiouskite/STAMP/blob/main/LICENSE) file for details.

---

**Jump in. Break things. Stamp has your back.**

```bash
cd ~/projects && stamp "first-try"
# Your safety net is ready.
```
