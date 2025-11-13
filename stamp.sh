#!/bin/bash
# ==============================================================================
# stamp - Brutally simple directory time machine
# ==============================================================================

STAMP_BASE="$HOME/.stamps"
STAMP_LOG="$STAMP_BASE/.stamp_log"
STAMP_LOG_LIMIT=100

# ==============================================================================
# HELPERS
# =============================================================================

# Get relative time: "0s ago", "5m ago", "2h ago", etc.
_relative_time() {
    # Handle high-precision float (e.g., 123.456)
    local time_float="$1"
    # Get integer part of the stamp time
    local time_int=$(echo "$time_float" | cut -d'.' -f1)
    # Get integer part of the current time
    local current_time_int=$(date +%s)
    
    local diff=$((current_time_int - time_int))

    # Show seconds if less than a minute
    if [ $diff -lt 0 ]; then echo "0s ago" # Handle clock drift
    elif [ $diff -lt 60 ]; then echo "${diff}s ago"
    
    # Show minutes if less than an hour
    elif [ $diff -lt 3600 ]; then echo "$((diff / 60))m ago"
    
    # Original section
    elif [ $diff -lt 86400 ]; then echo "$((diff / 3600))h ago"
    elif [ $diff -lt 172800 ]; then echo "Yesterday"
    elif [ $diff -lt 604800 ]; then echo "$((diff / 86400))d ago"
    elif [ $diff -lt 2592000 ]; then echo "$((diff / 604800))w ago"
    else echo "$((diff / 2592000))mo ago"; fi
}

# Simple counter: count existing stamps and add 1
_next_name() {
    local base_name="$1"
    local dest_dir="$2"
    local message="$3"
    
    # Count existing stamps (including unnumbered base)
    local count=0
    [ -d "$dest_dir/$base_name" ] && count=1
    
    # Count numbered ones
    for existing in "$dest_dir"/[0-9]*"$base_name"*; do
        [ -e "$existing" ] || continue
        count=$((count + 1))
    done
    
    local num_prefix=""
    [ $count -gt 0 ] && num_prefix="${count}"
    
    echo "${num_prefix}${base_name}${message:+@$message}"
}

# Save metadata
_save_meta() {
    # Use nanoseconds for high-precision sorting
    echo "timestamp=$(date +%s.%N)" > "$1/.stamp_info"
    echo "source_path=$2" >> "$1/.stamp_info"
    echo "message=$3" >> "$1/.stamp_info"
}

# Load metadata
_load_meta() {
    if [ -f "$1/.stamp_info" ]; then
        source "$1/.stamp_info"
        echo "$timestamp|$source_path|$message"
    else
        local mtime=$(stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo "0")
        echo "$mtime|||"
    fi
}

# Remove from log
_remove_log() {
    grep -v -F -x "$1" "$STAMP_LOG" > "$STAMP_LOG.tmp" && mv "$STAMP_LOG.tmp" "$STAMP_LOG"
}

# Copy HOME contents, skipping .stamps
_copy_home_special() {
    local src_path="$1" final_path="$2"
    
    mkdir -p "$final_path"
    
    # Copy all visible files/dirs
    # 2>/null hides 'No such file' if dir is empty
    cp -r "$src_path"/* "$final_path/" 2>/dev/null
    
    # Copy all hidden files/dirs (except . and ..)
    # This will copy .stamps, but we clean it up next.
    cp -r "$src_path"/.[^.]* "$final_path/" 2>/dev/null
    
    # NOW we remove the .stamps dir from the destination
    rm -rf "$final_path/.stamps"
}

# --- NEW REFACTORED HELPERS ---

# Helper to determine the search name
_get_search_name() {
    local cwd="$1" full_path="$2"
    if [ "$cwd" = "$HOME" ]; then echo "HOME"
    elif [ "$full_path" = "true" ]; then echo "$(echo "${cwd#$HOME/}" | cut -d/ -f1)"
    else echo "$(basename "$cwd")"; fi
}

# Helper to get a time-sorted list of stamps
_get_sorted_stamps() {
    local name="$1"
    # Find dirs, get their real timestamp, sort by it, and print the path
    find "$STAMP_BASE" -maxdepth 2 -type d -iname "*${name}*" | while IFS= read -r dir; do
        local meta=$(_load_meta "$dir")
        local time=$(echo "$meta" | cut -d'|' -f1)
        echo "$time $dir"
    done | sort -n | cut -d' ' -f2-
}

# ==============================================================================
# ACTIONS
# =============================================================================

stamp_save() {
    local cwd="$1" full_path="$2"
    shift 2
    local msg="$*"
    
    local today=$(date +%Y-%m-%d)
    local today_dir="$STAMP_BASE/$today"
    mkdir -p "$today_dir"
    
    local src_path disp_name base_name
    
    if [ "$cwd" = "$HOME" ]; then
        src_path="$HOME"
        disp_name="HOME"
    elif [ "$full_path" = "true" ]; then
        src_path="$HOME/$(echo "${cwd#$HOME/}" | cut -d/ -f1)"
        disp_name="${src_path#$HOME/}"
    else
        src_path="$cwd"
        disp_name="${src_path#$HOME/}"
    fi
    
    base_name=$(basename "$src_path")
    
    # Generate next name
    local final_name=$(_next_name "$base_name" "$today_dir" "$msg")
    local final_path="$today_dir/$final_name"
    
    # Perform copy
    if [ "$src_path" = "$HOME" ]; then
        # Use special helper to copy HOME contents and exclude .stamps
        _copy_home_special "$src_path" "$final_path"
    else
        # Standard copy for all other directories
        cp -r "$src_path" "$final_path"
    fi
    
    # Save metadata
    _save_meta "$final_path" "$src_path" "$msg"
    
    echo "✓ Stamped: $disp_name → ${final_path#$HOME/}"
    echo "$final_path" >> "$STAMP_LOG"
    
    # Prune log
    if [ $(wc -l < "$STAMP_LOG") -gt "$STAMP_LOG_LIMIT" ]; then
        tail -n "$STAMP_LOG_LIMIT" "$STAMP_LOG" > "$STAMP_LOG.tmp"
        mv "$STAMP_LOG.tmp" "$STAMP_LOG"
    fi
}

stamp_list() {
    local cwd="$1" full_path="$2"
    
    local name=$(_get_search_name "$cwd" "$full_path")
    echo -e "\033[1mStamps for '$name':\033[0m"
    
    local -a stamps
    while IFS= read -r line; do stamps+=("$line"); done < <(_get_sorted_stamps "$name")
    
    [ ${#stamps[@]} -eq 0 ] && echo "  (none)" && return
    
    # Loop forward to show oldest as 1)
    for ((i=0; i<${#stamps[@]}; i++)); do
        local stamp_path="${stamps[$i]}"
        local meta=$(_load_meta "$stamp_path")
        local time=$(echo "$meta" | cut -d'|' -f1)
        local msg=$(echo "$meta" | cut -d'|' -f3)
        local size=$(du -sh "$stamp_path" 2>/dev/null | cut -f1)
        local ref_num=$((i + 1)) # 1-indexed
        
        printf "  %2d) %-25s %6s  %s" "$ref_num" "$(basename "$stamp_path")" "$size" "$(_relative_time "$time")"
        [ -n "$msg" ] && echo "  (@$msg)" || echo
    done
}

stamp_peek() {
    local cwd="$1" ref="$2" full_path="$3"
    
    local name=$(_get_search_name "$cwd" "$full_path")
    
    local -a stamps
    while IFS= read -r line; do stamps+=("$line"); done < <(_get_sorted_stamps "$name")
    [ ${#stamps[@]} -eq 0 ] && echo "✗ No stamps found" && return 1
    
    local target
    if [ -z "$ref" ]; then target="${stamps[-1]}" # Default: newest
    elif [[ "$ref" =~ ^[0-9]+$ ]]; then target="${stamps[$ref-1]}" # 1-indexed
    else
        # Search the already sorted list
        target=$(printf "%s\n" "${stamps[@]}" | grep -F "$ref" | tail -1)
    fi
    
    [ -z "$target" ] && echo "✗ Stamp not found" && return 1
    
    echo -e "→ Entering $(basename "$target") (type 'exit' to return)\n---"
    (cd "$target" && PS1="($(basename "$target")) \\$ " /bin/bash)
    echo -e "← Back in $(basename "$cwd")"
}

stamp_back() {
    local cwd="$1" ref="$2" full_path="$3"
    
    local name=$(_get_search_name "$cwd" "$full_path")
    local target_path
    if [ "$cwd" = "$HOME" ]; then target_path="$HOME"
    elif [ "$full_path" = "true" ]; then target_path="$HOME/$name"
    else target_path="$cwd"; fi
    
    local -a stamps
    while IFS= read -r line; do stamps+=("$line"); done < <(_get_sorted_stamps "$name")
    [ ${#stamps[@]} -eq 0 ] && echo "✗ No stamps found" && return 1
    
    local source
    if [ -z "$ref" ]; then source="${stamps[-1]}" # Default: newest
    elif [[ "$ref" =~ ^[0-9]+$ ]]; then source="${stamps[$ref-1]}" # 1-indexed
    else
        # Search the already sorted list
        source=$(printf "%s\n" "${stamps[@]}" | grep -F "$ref" | tail -1)
    fi
    
    [ -z "$source" ] && echo "✗ Stamp not found" && return 1
    
    local meta=$(_load_meta "$source")
    local time=$(echo "$meta" | cut -d'|' -f1)
    
    echo -e "\n\033[1;33m⚠ DESTRUCTIVE ACTION\033[0m"
    echo -e "  Will replace: \033[31m$target_path\033[0m"
    echo -e "  With:         \033[32m$(basename "$source")\033[0m"
    echo -e "  From:         $(_relative_time "$time")\n"
    
    local should_confirm=true
    # Confirm unless ref is the *last* one (newest)
    [ -n "$ref" ] && [ "$ref" -eq "${#stamps[@]}" ] && should_confirm=false
    
    if [ "$should_confirm" = true ]; then
        read -p "  Continue? (y/N): " confirm
        [[ ! "$confirm" =~ ^[yY]$ ]] && echo "Cancelled." && return 0
    fi
    
    if [ "$target_path" = "$HOME" ]; then
        cp -r "$source"/* "$source"/.* "$target_path/" 2>/dev/null
        rm -rf "$target_path/.stamps"
    else
        rm -rf "$target_path" && cp -r "$source" "$target_path"
    fi && echo "✓ Restored" || echo "✗ Failed"
}

stamp_undo() {
    [ ! -s "$STAMP_LOG" ] && echo "✗ Nothing to undo" && return 1
    
    local last=$(tail -1 "$STAMP_LOG")
    [ ! -d "$last" ] && sed '$d' "$STAMP_LOG" > "$STAMP_LOG.tmp" && mv "$STAMP_LOG.tmp" "$STAMP_LOG" && echo "⚠ Gone, log cleaned" && return 1
    
    local meta=$(_load_meta "$last")
    local time=$(echo "$meta" | cut -d'|' -f1)
    local msg=$(echo "$meta" | cut -d'|' -f3)
    
    echo "Last stamp: $(basename "$last") ($(_relative_time "$time"))"
    [ -n "$msg" ] && echo "Message: $msg"
    read -p "Delete permanently? (y/N): " confirm
    
    [[ "$confirm" =~ ^[yY]$ ]] && rm -rf "$last" && sed '$d' "$STAMP_LOG" > "$STAMP_LOG.tmp" && mv "$STAMP_LOG.tmp" "$STAMP_LOG" && echo "✓ Undone" || echo "Cancelled."
}

stamp_delete() {
    local cwd="$1"
    local ref="$2"
    local full_path="$3"
    
    local name=$(_get_search_name "$cwd" "$full_path")
    
    local -a stamps
    while IFS= read -r line; do stamps+=("$line"); done < <(_get_sorted_stamps "$name")
    [ ${#stamps[@]} -eq 0 ] && echo "✗ No stamps found" && return 1
    
    [ "$ref" = "all" ] && read -p "⚠ Delete ALL ${#stamps[@]} stamps? Type 'yes': " confirm && [ "$confirm" = "yes" ] && rm -rf "${stamps[@]}" && echo "✓ All deleted" && return 0
    
    local target
    if [[ "$ref" =~ ^[0-9]+$ ]]; then target="${stamps[$ref-1]}" # 1-indexed
    else
        # Search the already sorted list
        target=$(printf "%s\n" "${stamps[@]}" | grep -F "$ref" | tail -1)
    fi
    
    [ -z "$target" ] && echo "✗ Stamp not found" && return 1
    
    read -p "Delete $(basename "$target")? (y/N): " confirm
    [[ "$confirm" =~ ^[yY]$ ]] && rm -rf "$target" && _remove_log "$target" && echo "✓ Deleted" || echo "Cancelled."
}

# ==============================================================================
# MAIN
# =============================================================================

# Must be in HOME
if [[ "$(pwd)" != "$HOME"* ]]; then
    echo "✗ Must be in HOME directory"
    exit 1
fi

mkdir -p "$STAMP_BASE"

# Parse command
cmd="${1:-}"
[ -n "$cmd" ] && shift

case "$cmd" in
    list|peek|back|delete)
        root_mode=false
        [ "$1" = "root" ] && root_mode=true && shift
        "stamp_$cmd" "$(pwd)" "${1:-}" "$root_mode"
        ;;
    undo) stamp_undo ;;
    help|--help|-h)
        echo "stamp - Simple directory time machine"
        echo "Usage: stamp [command] [message]"
        echo ""
        echo "Commands:"
        echo "  [message]    Save current dir"
        echo "  root [msg]   Save entire project"
        echo "  list         Show stamps"
        echo "  peek [n|msg] Browse stamp"
        echo "  back [n|msg] Restore stamp"
        echo "  delete [n|msg|all] Delete stamp(s)"
        echo "  undo         Undo last save"
        ;;
    root)
        subcmd="${1:-}"
        if [ -z "$subcmd" ]; then
            stamp_save "$(pwd)" "true" ""
        elif [[ "$subcmd" =~ ^(list|peek|back|delete)$ ]]; then
            shift
            "stamp_$subcmd" "$(pwd)" "${1:-}" "true"
        else
            stamp_save "$(pwd)" "true" "$subcmd"
        fi
        ;;
    "") stamp_save "$(pwd)" "false" "" ;;
    *) stamp_save "$(pwd)" "false" "$cmd" ;;
esac
