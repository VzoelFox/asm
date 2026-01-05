#!/bin/bash
# Morph Memory Daemon Cleaner
# Automatically cleans up old snapshots and sandboxes

# Configuration
FLOODWAIT_TIMEOUT=30        # seconds
SNAPSHOT_TTL=300            # 5 minutes
SANDBOX_TTL=60              # 1 minute
CHECK_INTERVAL=10           # check every 10 seconds
LOG_FILE="/var/log/morph_cleaner.log"

# Shared memory paths
SWAP_MONITOR_DIR="/tmp/morph_swaps"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

get_timestamp() {
    date +%s
}

clean_snapshots() {
    local now=$(get_timestamp)
    local cleaned=0

    if [ ! -d "$SWAP_MONITOR_DIR" ]; then
        return
    fi

    for snapshot_file in "$SWAP_MONITOR_DIR"/snapshot_*; do
        [ -f "$snapshot_file" ] || continue

        local ts=$(cat "$snapshot_file" 2>/dev/null)
        [ -z "$ts" ] && continue

        local age=$((now - ts))

        if [ $age -gt $SNAPSHOT_TTL ]; then
            log "Cleaning old snapshot: $snapshot_file (age: ${age}s)"
            
            local pid=$(basename "$snapshot_file" | cut -d'_' -f2)
            if kill -0 "$pid" 2>/dev/null; then
                kill -USR1 "$pid" 2>/dev/null
            else
                rm -f "$snapshot_file"
            fi
            
            ((cleaned++))
        fi
    done

    [ $cleaned -gt 0 ] && log "Cleaned $cleaned old snapshots"
}

clean_sandboxes() {
    local now=$(get_timestamp)
    local cleaned=0

    if [ ! -d "$SWAP_MONITOR_DIR" ]; then
        return
    fi

    for sandbox_file in "$SWAP_MONITOR_DIR"/sandbox_*; do
        [ -f "$sandbox_file" ] || continue

        local ts=$(cat "$sandbox_file" 2>/dev/null)
        [ -z "$ts" ] && continue

        local age=$((now - ts))

        if [ $age -gt $SANDBOX_TTL ]; then
            log "Cleaning old sandbox: $sandbox_file (age: ${age}s)"
            
            local pid=$(basename "$sandbox_file" | cut -d'_' -f2)
            if kill -0 "$pid" 2>/dev/null; then
                kill -USR2 "$pid" 2>/dev/null
            else
                rm -f "$sandbox_file"
            fi
            
            ((cleaned++))
        fi
    done

    [ $cleaned -gt 0 ] && log "Cleaned $cleaned old sandboxes"
}

clean_page_cache() {
    if [ "$EUID" -eq 0 ]; then
        log "Syncing and dropping caches..."
        sync
        echo 3 > /proc/sys/vm/drop_caches 2>/dev/null
        log "Cache cleaned"
    fi
}

monitor_memory() {
    local mem_info=$(free -m | grep Mem)
    local total=$(echo "$mem_info" | awk '{print $2}')
    local used=$(echo "$mem_info" | awk '{print $3}')
    local percent=$((used * 100 / total))

    log "Memory: ${used}MB / ${total}MB (${percent}%)"

    if [ $percent -gt 80 ]; then
        log "⚠️  High memory usage detected! Starting aggressive cleanup..."
        clean_snapshots
        clean_sandboxes
        clean_page_cache
    fi
}

track_floodwait() {
    local request_log="/tmp/morph_requests.log"
    local now=$(get_timestamp)
    
    local count=$(awk -v cutoff=$((now - FLOODWAIT_TIMEOUT)) '$1 > cutoff' "$request_log" 2>/dev/null | wc -l)
    
    if [ $count -gt 20 ]; then
        log "⚠️  Flood detected: $count requests in ${FLOODWAIT_TIMEOUT}s"
        sleep 5
    fi
}

main() {
    log "Morph Cleaner Daemon started"
    log "Config: SNAPSHOT_TTL=${SNAPSHOT_TTL}s, SANDBOX_TTL=${SANDBOX_TTL}s"
    
    mkdir -p "$SWAP_MONITOR_DIR"
    
    while true; do
        clean_snapshots
        clean_sandboxes
        monitor_memory
        track_floodwait
        
        sleep $CHECK_INTERVAL
    done
}

trap 'log "Daemon stopped"; exit 0' SIGTERM SIGINT

if [ "$1" == "start" ]; then
    log "Starting daemon..."
    main &
    echo $! > /var/run/morph_cleaner.pid
    log "Daemon PID: $(cat /var/run/morph_cleaner.pid)"
elif [ "$1" == "stop" ]; then
    if [ -f /var/run/morph_cleaner.pid ]; then
        kill $(cat /var/run/morph_cleaner.pid) 2>/dev/null
        rm -f /var/run/morph_cleaner.pid
        log "Daemon stopped"
    fi
elif [ "$1" == "status" ]; then
    if [ -f /var/run/morph_cleaner.pid ]; then
        local pid=$(cat /var/run/morph_cleaner.pid)
        if kill -0 "$pid" 2>/dev/null; then
            echo "Daemon running (PID: $pid)"
            monitor_memory
        else
            echo "Daemon not running (stale PID file)"
        fi
    else
        echo "Daemon not running"
    fi
else
    echo "Usage: $0 {start|stop|status}"
    exit 1
fi
