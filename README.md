# OpsTrail

**Your Terminal Activity Time-Machine**

OpsTrail is a local-first, privacy-focused terminal activity tracker that records everything you do in your shell and lets you search, analyze, and time-travel through your work history.

## Features

- **Automatic Activity Tracking** - Every command, directory change, and session
- **Time Travel** - Jump back to where you were working hours or days ago
- **Analytics** - See your most-used commands, active projects, and productivity patterns
- **Context Notes** - Attach notes to your timeline for future reference
- **Session Management** - Tracks terminal sessions and idle time
- **Project Awareness** - Integrates with [projwarp](https://github.com/ricky-ultimate/projwarp) for smart project tracking
- **Private & Local** - All data stays on your machine
- **Blazing Fast** - Built with Rust for maximum performance

## Installation

### Quick Install

Choose your preferred package manager:

```powershell
# Chocolatey (Windows) - Includes PowerShell integration
choco install opstrail

# Cargo (Cross-platform)
cargo install opstrail
```

### Build from Source

```bash
git clone https://github.com/ricky-ultimate/opstrail.git
cd opstrail
cargo build --release

# Copy binary to PATH
cp target/release/trail ~/.local/bin/  # Unix
# or
copy target\release\trail.exe C:\Users\YourName\.local\bin\  # Windows
```

### Shell Integration

#### **PowerShell (Windows)**

If you didn't install via Chocolatey, set up PowerShell integration:

```powershell
# Run the installer script
.\install.ps1

# Reload your profile
. $PROFILE
```

#### **Bash/Zsh (Unix)**

Set up shell integration:

```bash
# Run the installer script
chmod +x install.sh
./install.sh

# Reload your shell
source ~/.bashrc  # or ~/.zshrc
```

---

## Quick Start

Once installed, OpsTrail automatically tracks your terminal activity. Try these commands:

### **See What You've Been Up To**
```bash
# Today's summary
trail today

# View your activity timeline
trail timeline

# This week's statistics
trail stats
```

### **Search Your History**
```bash
# Find all git commands
trail search "git"

# Search today's activity
trail search "cargo" --today

# Search within a specific project
trail search "build" --project myproject
```

### **Time Travel**
```bash
# Jump back to where you were 1 hour ago (auto-cd)
trail back 1h

# Jump back to 30 minutes ago
trail back 30m

# Go back to yesterday
trail back yesterday

# Alternative helper function (Unix/PowerShell)
trail-back 2h
```

### **Resume Your Work**
```bash
# See your last session with interactive prompt
trail resume

# Alternative helper function (Unix/PowerShell)
trail-resume
```

### **Leave Breadcrumbs**
```bash
# Add a note to your timeline
trail note "Fixed the recursive parser bug in main.rs:145"

# Search your notes later
trail search "parser"
```

### **Track Projects**
```bash
# See all project activity
trail projects

# View all your sessions
trail sessions
```

---

## Real-World Use Cases

### **1. "Where was I working?"**
You switched contexts hours ago and forgot where you were:

```bash
# Jump back to where you were 2 hours ago
trail back 2h

# Output:
#   Jumped back 2h to: /home/user/projects/myapp
```

### **2. "What did I do today?"**
End-of-day review:

```bash
trail today

# Output:
# Today's Summary
#
#   Events: 89
#   Commands: 45
#   Projects: 3
#
#   Active Projects:
#     • opstrail (58 activities)
#     • projwarp (23 activities)
#     • website (8 activities)
```

### **3. "Resume my work after a break"**
Came back after lunch:

```bash
trail resume

# Output shows last active project with interactive prompt:
# Last Active Session:
#
#   Project: opstrail
#   Path: /home/user/projects/opstrail
#   Time: 2025-11-14 11:23:45
#   Last command: cargo test
#
# Jump to this location? (y/n)
```

### **4. "Find that command I ran last week"**
Can't remember the exact docker command:

```bash
trail search "docker compose"

# Shows all matching commands with timestamps
```

### **5. "Track my productivity patterns"**
Weekly review:

```bash
trail stats

# Output:
# Activity Statistics
#
# Most Active Projects:
#   1. opstrail (234 activities)
#   2. projwarp (128 activities)
#   3. website (89 activities)
#
# Most Used Commands:
#   1. cargo (127)
#   2. git (89)
#   3. code (45)
```

### **6. "Leave context for future me"**
While debugging:

```bash
trail note "The async trait issue is in main.rs:145, related to lifetime bounds"

# Two weeks later:
trail search "async trait"
# Finds your note instantly
```

---

## What Gets Tracked

OpsTrail automatically logs:

| Event Type | Description | Example |
|------------|-------------|---------|
| **Commands** | Every command you execute | `cargo build`, `git commit` |
| **Directory Changes** | When you `cd` anywhere | `cd /home/user/projects` |
| **Session Start** | When you open a terminal | New shell session |
| **Session End** | When you close a terminal | Shell exit |
| **Idle Time** | Detects when you're away (10+ min) | Inactivity detection |
| **Projects** | Which project you're in (via projwarp) | `[opstrail]`, `[website]` |
| **Notes** | Manual context you add | `trail note "Bug fixed"` |

---

## ProjWarp Integration

OpsTrail works beautifully with [projwarp](https://github.com/ricky-ultimate/projwarp):

### **What is ProjWarp?**
A fast project navigation tool that lets you jump between projects instantly:
```bash
proj add myproject          # Register current project
proj myproject              # Jump to a project
proj myproject -code        # Open in VS Code
```

### **How They Work Together**

**ProjWarp** = Where your projects exist
**OpsTrail** = What you're doing inside them

When both are installed:

**Automatic project detection** - OpsTrail reads your projwarp config
**Cleaner logs** - Shows `[myproject]` instead of long paths
**Project-based stats** - Time tracking per project
**Smart search** - Search by project alias

Example log output:
```
12:45:23 [opstrail] ⚡ cargo test
12:46:15 [opstrail] ⚡ git commit -m "Add tests"
12:50:30 [website] ⚡ npm run dev
```

**Install both:**
```powershell
# Windows - Chocolatey
choco install projwarp
choco install opstrail

# Cross-platform - Cargo
cargo install projwarp
cargo install opstrail
```

---

## Commands Reference

### **Automatic Logging** (via shell integration)
These run automatically - no action needed:
- `trail log --cmd <cmd> --cwd <path>` - Logs commands
- `trail log --session-start` - On terminal open
- `trail log --session-end` - On terminal close

### **Query Commands**

| Command | Description | Example |
|---------|-------------|---------|
| `trail today` | Today's activity summary | `trail today` |
| `trail timeline` | View activity timeline | `trail timeline --today` |
| `trail stats` | Activity statistics | `trail stats` |
| `trail search <q>` | Search your history | `trail search "git" --today` |
| `trail back <time>` | Time travel (auto-cd) | `trail back 1h` |
| `trail resume` | Show last session (interactive) | `trail resume` |
| `trail note <text>` | Add a note | `trail note "Fixed bug"` |
| `trail sessions` | List all sessions | `trail sessions` |
| `trail projects` | Show project activity | `trail projects` |

### **Time Travel Formats**

| Format | Example | Description |
|--------|---------|-------------|
| Minutes | `30m` | Go back 30 minutes |
| Hours | `1h`, `2h` | Go back N hours |
| Days | `1d`, `2d` | Go back N days |
| Weeks | `1w`, `2w` | Go back N weeks |
| Keywords | `yesterday` | Go to yesterday |
| | `today` | Start of today |
| | `last-session` | Previous session |

### **Shell Helper Functions**

Available in both PowerShell and Bash/Zsh after installation:

| Function | Description |
|----------|-------------|
| `trail-back <time>` | Jump back in time and `cd` there |
| `trail-resume` | Interactive resume with prompt |

**Note:** `trail back` and `trail resume` now include auto-cd functionality built-in!

---

## Data Storage

All data is stored locally in your home directory:

```
~/.opstrail/
├── timeline.jsonl    # Activity log (JSON Lines format)
├── state.json        # Current session state
└── config.json       # Configuration
```

### **Timeline Format (JSONL)**

Each line is a JSON event:

```json
{
  "timestamp": "2025-11-14T01:33:24.243Z",
  "event_type": {"type": "command", "cmd": "cargo run"},
  "cwd": "/home/user/projects/opstrail",
  "project": "opstrail",
  "session_id": "session_1731545604"
}
```

**Why JSONL?**
- Fast append-only writes
- Easy to parse line-by-line
- Human-readable
- No database required
- Easy backups (just copy the file)

---

## Configuration

Edit `~/.opstrail/config.json`:

```json
{
  "idle_timeout_minutes": 10,
  "enable_projwarp_integration": true
}
```

| Setting | Default | Description |
|---------|---------|-------------|
| `idle_timeout_minutes` | `10` | Minutes of inactivity to mark as idle |
| `enable_projwarp_integration` | `true` | Auto-detect projects from projwarp |

---

## 🛠️ Shell Integration Details

### **PowerShell (Windows)**

The PowerShell integration (`install.ps1`):

Logs every command using PowerShell history
Tracks session start/end automatically
Provides helper functions (`trail-back`, `trail-resume`)
Auto-cd support for `trail back` and `trail resume`
Handles UTF-8 encoding properly

### **Bash/Zsh (Unix)**

The Unix shell integration (`install.sh`):

Logs commands using `preexec` hooks
Tracks session start/end automatically
Provides helper functions (`trail-back`, `trail-resume`)
Auto-cd support for `trail back` and `trail resume`
Compatible with both Bash and Zsh

---

## Example Daily Workflow

```bash
# Morning - Start fresh terminal
# OpsTrail automatically logs session start

# Check what you did yesterday
trail timeline --date 2025-11-13

# Resume yesterday's work
trail resume
# Shows info and prompts: Jump to this location? (y/n)
# → Type 'y' to jump to /home/user/projects/opstrail

# Work on the project
cargo build
cargo test
git commit -m "Add feature"

# Leave a note for context
trail note "Implemented time-travel navigation, needs testing on edge cases"

# Switch to different project
proj website
npm run dev

# Lunch break (OpsTrail detects 10+ min idle)

# Back to work - check progress
trail today
# Shows: 2 projects, 23 commands, 2h 15m tracked

# Find that git command from last week
trail search "git rebase" --project opstrail

# Jump back to where you were this morning
trail back 3h

# End of day review
trail stats
```

## Contributing

Contributions are welcome! Here's how you can help:

1. **Report bugs** - Open an issue on GitHub
2. **Suggest features** - Share your ideas
3. **Submit PRs** - Improve the code
4. **Write documentation** - Help others use OpsTrail
5. **Share feedback** - Tell us what you think

### **Development Setup**

```bash
# Clone the repo
git clone https://github.com/ricky-ultimate/opstrail.git
cd opstrail

# Build
cargo build

# Run tests
cargo test

# Run locally
cargo run -- today
```

---

## Inspiration

Inspired by:
- `zoxide` / `autojump` - Smart directory jumping
- Shell history - But much more powerful
- VSCode timeline - But for your terminal
- RescueTime - But local and privacy-focused
- Git commit history - But for all your work

---

## Why OpsTrail?

**Ever wondered:**
- "Where was I working on that feature?"
- "What command did I run to fix that issue?"
- "How much time did I actually spend on this project?"
- "What was I doing before I got distracted?"

**OpsTrail answers all of these** - automatically, privately, and locally.

It's like having a DVR for your terminal. Rewind, replay, and review your development workflow.

---

## Related Projects

- **[ProjWarp](https://github.com/ricky-ultimate/projwarp)** - Project navigation tool (pairs perfectly with OpsTrail)

---

## Support

- **Issues:** [GitHub Issues](https://github.com/ricky-ultimate/opstrail/issues)
- **Discussions:** [GitHub Discussions](https://github.com/ricky-ultimate/opstrail/discussions)

---

**Made with ❤️ by リッキー**

*Track your journey, boost your productivity* 🚀
