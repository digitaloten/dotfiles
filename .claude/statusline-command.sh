#!/bin/sh
input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)
# Session-cumulative input/output tokens, parsed from the transcript.
# Each assistant turn's usage is duplicated once per content block, so dedup by
# message.id (take first per id) before summing. Input is billed-style: fresh
# input + cache writes (excludes cache reads); output is generated tokens.
transcript=$(echo "$input" | jq -r '.transcript_path // empty')
input_tokens=""
output_tokens=""
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
    session_tokens=$(jq -rs '
        [ .[] | select(.message.usage and .message.id) ]
        | group_by(.message.id) | map(.[0].message.usage) as $u
        | { i: ([ $u[] | (.input_tokens + (.cache_creation_input_tokens // 0)) ] | add // 0),
            o: ([ $u[].output_tokens ] | add // 0) }
        | "\(.i) \(.o)"' "$transcript" 2>/dev/null)
    if [ -n "$session_tokens" ]; then
        in_tok=${session_tokens%% *}
        out_tok=${session_tokens##* }
        [ "$in_tok" != "0" ] && input_tokens="$in_tok"
        [ "$out_tok" != "0" ] && output_tokens="$out_tok"
    fi
fi
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
model_name=$(echo "$input" | jq -r '.model.display_name // empty')
effort=$(jq -r '.effortLevel // empty' "$HOME/.claude/settings.json" 2>/dev/null)

# Shorten home directory
home_short=$(basename "$cwd")

# Format number with k/m/b suffix
fmt_num() {
    n=$1
    if [ "$n" -ge 1000000000 ]; then
        echo "$n 1000000000 b" | awk '{v=$1/$2; if(v==int(v)) printf "%db\n",v; else printf "%.1fb\n",v}'
    elif [ "$n" -ge 1000000 ]; then
        echo "$n 1000000 m" | awk '{v=$1/$2; if(v==int(v)) printf "%dm\n",v; else printf "%.1fm\n",v}'
    elif [ "$n" -ge 1000 ]; then
        echo "$n 1000 k" | awk '{v=$1/$2; if(v==int(v)) printf "%dk\n",v; else printf "%.1fk\n",v}'
    else printf "%d" "$n"; fi
}

# Foreground colors (bright)
FG_BLUE="\e[38;5;75m"      # bright blue    — dir segment
FG_PURPLE="\e[38;5;141m"   # bright purple  — git branch segment
FG_CYAN="\e[38;5;117m"     # bright cyan    — input tokens
FG_PINK="\e[38;5;213m"     # bright pink    — output tokens
FG_RED="\e[38;5;204m"      # bright coral red — effort segment
FG_DARKGREEN="\e[38;5;83m" # bright green   — model/effort segment
SEP="\e[38;5;244m"         # mid separator
RESET="\e[0m"

# Nerd Font icons — vim/lualine style
DIR_ICON=    #  file (buffer icon)
BRANCH_ICON= #  git branch
UP_ICON=     #  arrow-up (in tokens)
DOWN_ICON=   #  arrow-down (out tokens)
MODEL_ICON=  #  android (model)
EFFORT_ICON= #  bolt (effort)
BONE_ICON=🦴   # bone
BAR=" | "

# Build left segments
left=""

left="${left}${FG_BLUE}${DIR_ICON} ${home_short}"

if [ -n "$branch" ]; then
    left="${left}${SEP}${BAR}${FG_PURPLE}${BRANCH_ICON} ${branch}"
fi

caveman_flag="$HOME/.claude/.caveman-active"
if [ -f "$caveman_flag" ]; then
    caveman_mode=$(cat "$caveman_flag" 2>/dev/null)
    caveman_mode=${caveman_mode:-full}
    left="${left}${SEP}${BAR}\e[38;5;172m${BONE_ICON} ${caveman_mode}"
fi

if [ -n "$input_tokens" ]; then
    left="${left}${SEP}${BAR}${FG_CYAN}${UP_ICON} $(fmt_num "$input_tokens")"
fi

if [ -n "$output_tokens" ]; then
    left="${left}${SEP}${BAR}${FG_PINK}${DOWN_ICON} $(fmt_num "$output_tokens")"
fi

ctx_size=$(echo "$input" | jq -r '((.context_window.current_usage.input_tokens // 0) + (.context_window.current_usage.cache_read_input_tokens // 0) + (.context_window.current_usage.cache_creation_input_tokens // 0)) | select(. > 0)')
if [ -n "$ctx_size" ]; then
    max_ctx=$(echo "$input" | jq -r '.context_window.context_window_size // empty')
    max_fmt=$(fmt_num "${max_ctx:-0}")
    ctx_text=" $(fmt_num "$ctx_size") of ${max_fmt} "
    ctx_len=${#ctx_text}
    used_int=${used_pct:-0}
    filled=$(((used_int * (ctx_len + 1) + 50) / 100))
    BG_FILLED="\e[48;5;30m\e[38;5;255m"
    BG_EMPTY="\e[48;5;236m\e[38;5;250m"
    ctx_bar=""
    i=0
    while [ $i -lt $ctx_len ]; do
        ch=$(printf '%s' "$ctx_text" | cut -c$((i + 1)))
        if [ $((i + 1)) -lt $filled ]; then ctx_bar="${ctx_bar}${BG_FILLED}${ch}"; else ctx_bar="${ctx_bar}${BG_EMPTY}${ch}"; fi
        i=$((i + 1))
    done
    left="${left}${SEP}${BAR}${ctx_bar}\e[0m"
fi

if [ -n "$model_name" ]; then
    left="${left}${SEP}${BAR}${FG_DARKGREEN}${MODEL_ICON} ${model_name}"
fi

if [ -n "$effort" ]; then
    left="${left}${SEP}${BAR}${FG_RED}${EFFORT_ICON} ${effort}"
fi

# Format seconds as "5d 4h 3m"
fmt_duration() {
    secs=$1
    if [ "$secs" -le 0 ]; then printf "now"; return; fi
    d=$((secs / 86400))
    h=$(( (secs % 86400) / 3600 ))
    m=$(( (secs % 3600) / 60 ))
    out=""
    if [ "$d" -gt 0 ]; then out="${d}d"; fi
    if [ "$h" -gt 0 ]; then
        if [ -n "$out" ]; then out="${out} ${h}h"; else out="${h}h"; fi
    fi
    if [ "$m" -gt 0 ]; then
        if [ -n "$out" ]; then out="${out} ${m}m"; else out="${m}m"; fi
    fi
    if [ -z "$out" ]; then out="< 1m"; fi
    printf "%s" "$out"
}

# Parse reset_at (Unix timestamp or ISO-8601) → Unix seconds
parse_reset_at() {
    val=$1
    case "$val" in
        [0-9]*) printf "%s" "$val" ;;
        *) date -d "$val" +%s 2>/dev/null || printf "0" ;;
    esac
}

# Context-style bg-fill bar: " label | time_remaining "
rate_bar() {
    pct=$1
    label=$2
    reset_at=$3
    now=$4
    if [ "$reset_at" -gt 0 ]; then
        remaining_secs=$(( reset_at - now ))
        remaining=$(fmt_duration "$remaining_secs")
    else
        remaining="${pct}%"
    fi
    text=" ${label} (${pct}%) "
    text_len=${#text}
    filled=$(( (pct * (text_len + 1) + 50) / 100 ))
    if [ "$pct" -ge 90 ]; then
        BG_RATE_FILLED="\e[48;5;160m\e[38;5;255m"
    elif [ "$pct" -ge 75 ]; then
        BG_RATE_FILLED="\e[48;5;136m\e[38;5;255m"
    else
        BG_RATE_FILLED="\e[48;5;30m\e[38;5;255m"
    fi
    BG_RATE_EMPTY="\e[48;5;236m\e[38;5;250m"
    bar=""
    i=0
    while [ $i -lt $text_len ]; do
        ch=$(printf '%s' "$text" | cut -c$((i + 1)))
        if [ $((i + 1)) -lt $filled ]; then bar="${bar}${BG_RATE_FILLED}${ch}"; else bar="${bar}${BG_RATE_EMPTY}${ch}"; fi
        i=$((i + 1))
    done
    printf "%s\e[0m \e[38;5;244m%s\e[0m" "$bar" "$remaining"
}

five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
week_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
five_reset_raw=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
week_reset_raw=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')
now_ts=$(date +%s)
if [ -n "$five_pct" ] || [ -n "$week_pct" ]; then
    rate_str=""
    if [ -n "$five_pct" ]; then
        five_int=$(printf '%.0f' "$five_pct")
        five_reset=0
        if [ -n "$five_reset_raw" ]; then five_reset=$(parse_reset_at "$five_reset_raw"); fi
        rate_str="$(rate_bar "$five_int" "5h" "$five_reset" "$now_ts")"
    fi
    if [ -n "$week_pct" ]; then
        week_int=$(printf '%.0f' "$week_pct")
        week_reset=0
        if [ -n "$week_reset_raw" ]; then week_reset=$(parse_reset_at "$week_reset_raw"); fi
        if [ -n "$rate_str" ]; then rate_str="${rate_str}${SEP}${BAR}"; fi
        rate_str="${rate_str}$(rate_bar "$week_int" "7d" "$week_reset" "$now_ts")"
    fi
    if [ -n "$rate_str" ]; then
        left="${left}${SEP}${BAR}${rate_str}"
    fi
fi

printf "%b\n" "${left}${RESET}"
