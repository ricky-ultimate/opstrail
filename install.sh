#!/usr/bin/env bash
# OpsTrail Shell Integration Installer for Bash/Zsh

set -e

# Detect shell
SHELL_NAME=$(basename "$SHELL")
SHELL_RC=""

case "$SHELL_NAME" in
    bash)
        SHELL_RC="$HOME/.bashrc"
        ;;
    zsh)
        SHELL_RC="$HOME/.zshrc"
        ;;
    *)
        echo "Unsupported shell: $SHELL_NAME"
        echo "Supported shells: bash, zsh"
        exit 1
        ;;
esac

echo "Detected shell: $SHELL_NAME"
echo "Profile: $SHELL_RC"
echo ""

# OpsTrail integration code
OPSTRAIL_INTEGRATION='
# OpsTrail - Terminal Activity Tracker Integration
export OPSTRAIL_SESSION_STARTED=0

# Start session on shell startup
if [ "$OPSTRAIL_SESSION_STARTED" -eq 0 ]; then
    trail log --session-start 2>/dev/null || true
    export OPSTRAIL_SESSION_STARTED=1
fi

# Log commands before execution
opstrail_preexec() {
    local cmd="$1"

    # Skip trail commands to avoid recursion
    case "$cmd" in
        trail*|opstrail*|opstrail_*) return ;;
    esac

    # Log the command
    trail log --cmd "$cmd" --cwd "$PWD" 2>/dev/null || true
}

# Bash: Use DEBUG trap
if [ -n "$BASH_VERSION" ]; then
    opstrail_last_cmd=""

    trap '\''opstrail_last_cmd="$BASH_COMMAND"'\'' DEBUG

    opstrail_log_last() {
        if [ -n "$opstrail_last_cmd" ]; then
            opstrail_preexec "$opstrail_last_cmd"
            opstrail_last_cmd=""
        fi
    }

    PROMPT_COMMAND="opstrail_log_last${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
fi

# Zsh: Use preexec hook
if [ -n "$ZSH_VERSION" ]; then
    autoload -U add-zsh-hook
    add-zsh-hook preexec opstrail_preexec
fi

# Session end on exit
opstrail_exit() {
    trail log --session-end 2>/dev/null || true
}

trap opstrail_exit EXIT

# Helper function: Jump back in time
trail-back() {
    local when="${1:-30m}"
    local path

    path=$(trail back "$when" 2>/dev/null)

    if [ $? -eq 0 ] && [ -n "$path" ] && [ -d "$path" ]; then
        cd "$path" || return 1
        echo "Jumped back to: $path"
    else
        echo "No activity found for that time" >&2
        return 1
    fi
}

# Helper function: Resume last session
trail-resume() {
    local output
    local path
    local response

    output=$(trail resume 2>&1)
    echo "$output"

    # Extract path from output
    path=$(echo "$output" | grep -oP "Path:\s*\K.+$" | head -1 | xargs)

    if [ -n "$path" ] && [ -d "$path" ]; then
        echo ""
        read -p "Jump to this location? (y/n) " -n 1 -r response
        echo ""

        if [[ $response =~ ^[Yy]$ ]]; then
            cd "$path" || return 1
            echo "✅ Resumed at: $path"
        fi
    fi
}

# Override trail command for auto-cd on back/resume
trail() {
    local subcommand="$1"
    shift

    case "$subcommand" in
        back)
            if [ $# -gt 0 ]; then
                local when="$1"
                local path

                path=$(command trail back "$when" 2>/dev/null)

                if [ $? -eq 0 ] && [ -n "$path" ] && [ -d "$path" ]; then
                    cd "$path" || return 1
                    echo "Jumped back $when to: $path"
                else
                    echo "No activity found for '\''$when'\''" >&2
                    return 1
                fi
            else
                command trail back "$@"
            fi
            ;;
        resume)
            local output
            local path
            local response

            output=$(command trail resume 2>&1)
            echo "$output"

            path=$(echo "$output" | grep -oP "Path:\s*\K.+$" | head -1 | xargs)

            if [ -n "$path" ] && [ -d "$path" ]; then
                echo ""
                read -p "Jump to this location? (y/n) " -n 1 -r response
                echo ""

                if [[ $response =~ ^[Yy]$ ]]; then
                    cd "$path" || return 1
                    echo "Resumed at: $path"
                fi
            fi
            ;;
        *)
            command trail "$subcommand" "$@"
            ;;
    esac
}

echo "✅ OpsTrail tracking enabled"
'

# Check if already installed
if grep -q "OpsTrail - Terminal Activity Tracker" "$SHELL_RC" 2>/dev/null; then
    echo "OpsTrail integration is already installed!"
    read -p "Do you want to reinstall? (y/N) " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi

    # Remove old integration
    echo "Removing old integration..."
    sed -i.bak '/# OpsTrail - Terminal Activity Tracker/,/echo "✅ OpsTrail tracking enabled"/d' "$SHELL_RC"
fi

# Add integration
echo "Installing OpsTrail integration..."
echo "" >> "$SHELL_RC"
echo "$OPSTRAIL_INTEGRATION" >> "$SHELL_RC"

echo ""
echo "OpsTrail $SHELL_NAME integration installed!"
echo ""
echo "Reload your shell profile to activate:"
echo "   source $SHELL_RC"
echo ""
echo "Useful commands:"
echo "   trail today          - Today's summary"
echo "   trail timeline       - View activity timeline"
echo "   trail stats          - Activity statistics"
echo "   trail search <term>  - Search your history"
echo "   trail back 1h        - Jump back 1 hour (auto-cd)"
echo "   trail resume         - Resume last session (with prompt)"
echo "   trail note <text>    - Add a note"
echo ""
echo "Happy tracking!"
