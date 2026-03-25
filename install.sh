#!/usr/bin/env bash

set -e

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

OPSTRAIL_INTEGRATION='
# OpsTrail - Terminal Activity Tracker Integration
export OPSTRAIL_SESSION_STARTED=0
export OPSTRAIL_TRAIL_PATH=""

if command -v trail >/dev/null 2>&1; then
    OPSTRAIL_TRAIL_PATH=$(command -v trail)
fi

if [ "$OPSTRAIL_SESSION_STARTED" -eq 0 ]; then
    if [ -n "$OPSTRAIL_TRAIL_PATH" ]; then
        "$OPSTRAIL_TRAIL_PATH" log --session-start 2>/dev/null || true
    else
        trail log --session-start 2>/dev/null || true
    fi
    export OPSTRAIL_SESSION_STARTED=1
fi

opstrail_preexec() {
    local cmd="$1"
    case "$cmd" in
        trail*|opstrail*|opstrail_*) return ;;
    esac
    if [ -n "$OPSTRAIL_TRAIL_PATH" ] && [ -x "$OPSTRAIL_TRAIL_PATH" ]; then
        "$OPSTRAIL_TRAIL_PATH" log --cmd "$cmd" --cwd "$PWD" 2>/dev/null || true
    else
        trail log --cmd "$cmd" --cwd "$PWD" 2>/dev/null || true
    fi
}

if [ -n "$BASH_VERSION" ]; then
    _opstrail_preexec_done=0
    _opstrail_last_hist=""

    opstrail_precmd() {
        local current_hist
        current_hist=$(HISTFORMAT="%s|%R"; history 1 2>/dev/null | sed "s/^[ ]*[0-9]*[ ]*//")
        if [ "$current_hist" != "$_opstrail_last_hist" ] && [ -n "$current_hist" ]; then
            local cmd="${current_hist#*|}"
            _opstrail_last_hist="$current_hist"
            opstrail_preexec "$cmd"
        fi
    }

    PROMPT_COMMAND="opstrail_precmd${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
fi

if [ -n "$ZSH_VERSION" ]; then
    autoload -U add-zsh-hook
    add-zsh-hook preexec opstrail_preexec
fi

opstrail_exit() {
    if [ -n "$OPSTRAIL_TRAIL_PATH" ] && [ -x "$OPSTRAIL_TRAIL_PATH" ]; then
        "$OPSTRAIL_TRAIL_PATH" log --session-end 2>/dev/null || true
    elif command -v trail >/dev/null 2>&1; then
        trail log --session-end 2>/dev/null || true
    fi
}

trap opstrail_exit EXIT

_opstrail_check_auto_cd() {
    local feature="$1"
    local config_file="$HOME/.opstrail/config.json"

    if [ ! -f "$config_file" ]; then
        echo "true"
        return
    fi

    if command -v jq >/dev/null 2>&1; then
        local result
        result=$(jq -r ".auto_cd.$feature // true" "$config_file" 2>/dev/null)
        echo "${result:-true}"
    elif command -v python3 >/dev/null 2>&1; then
        local result
        result=$(python3 -c "import json; print(json.load(open(\"$config_file\")).get(\"auto_cd\", {}).get(\"$feature\", True))" 2>/dev/null | tr "[:upper:]" "[:lower:]")
        echo "${result:-true}"
    else
        if grep -q "\"$feature\".*:.*false" "$config_file" 2>/dev/null; then
            echo "false"
        else
            echo "true"
        fi
    fi
}

trail() {
    local subcommand="$1"
    shift

    case "$subcommand" in
        back)
            if [ $# -gt 0 ]; then
                local when="$1"
                local auto_cd_enabled
                auto_cd_enabled=$(_opstrail_check_auto_cd "back")

                if [ "$auto_cd_enabled" = "true" ]; then
                    local raw_output
                    raw_output=$(command trail back "$when" 2>/dev/null)
                    local exit_code=$?
                    local path
                    path=$(echo "$raw_output" | tail -1)

                    if [ $exit_code -eq 0 ] && [ -n "$path" ] && [ -d "$path" ]; then
                        cd "$path" || return 1
                        echo "Jumped back $when to: $path"
                    else
                        echo "No activity found for '$when'" >&2
                        return 1
                    fi
                else
                    command trail back "$when"
                fi
            else
                command trail back "$@"
            fi
            ;;
        resume)
            local auto_cd_enabled
            auto_cd_enabled=$(_opstrail_check_auto_cd "resume")

            if [ "$auto_cd_enabled" = "true" ]; then
                local full_output
                full_output=$(command trail resume 2>&1)
                local path
                path=$(echo "$full_output" | tail -1)
                local info
                info=$(echo "$full_output" | head -n -1)

                echo "$info"

                if [ -n "$path" ] && [ -d "$path" ]; then
                    echo ""
                    read -p "Jump to this location? (y/n) " -n 1 -r response
                    echo ""
                    if [[ $response =~ ^[Yy]$ ]]; then
                        cd "$path" || return 1
                        echo "Resumed at: $path"
                    fi
                fi
            else
                command trail resume
            fi
            ;;
        *)
            command trail "$subcommand" "$@"
            ;;
    esac
}

echo "OpsTrail tracking enabled"
'

if grep -q "OpsTrail - Terminal Activity Tracker" "$SHELL_RC" 2>/dev/null; then
    echo "OpsTrail integration is already installed!"
    read -p "Do you want to reinstall? (y/N) " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi

    echo "Removing old integration..."
    sed -i.bak '/# OpsTrail - Terminal Activity Tracker/,/echo.*OpsTrail tracking enabled/d' "$SHELL_RC"
fi

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
echo "   trail stats --week   - This week"
echo "   trail stats --month  - This month"
echo "   trail search <term>  - Search your history"
echo "   trail back 1h        - Jump back 1 hour"
echo "   trail resume         - Resume last session"
echo "   trail note <text>    - Add a note"
echo "   trail config show    - View configuration"
echo "   trail config set <key> <value>"
echo "   trail prune          - Remove events older than 90 days"
echo "   trail prune --dry-run"
echo ""
