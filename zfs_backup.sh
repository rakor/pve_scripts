#!/bin/bash
#
# Title: zfs_backup.sh
# Version 0.4
# Date: 12.01.2025

# Default max number of snapshots to keep.
DEFAULT_MAX_SNAPSHOTS=365

# Current timestamp for snapshot naming.
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

# Log file location.
LOG_FILE="/var/log/zfs_backup.log"

# Function to log messages.
log() {
    local message="[$(date +"%Y-%m-%d %H:%M:%S")] $1"
    echo "$message" | tee -a "$LOG_FILE"
}

# Function to log error-messages.
errorlog() {
    local message="[$(date +"%Y-%m-%d %H:%M:%S")] ERROR: $1"
    echo "$message" >> "$LOG_FILE"
    echo "$message" >&2
}

# Funktion zum Überprüfen, ob ein ZFS-Pool existiert
check_pool_exists() {
  zfs list "$1" &>/dev/null
  return $?
}

# Function to clean up old snapshots.
cleanup_snapshots() {
    local pool=$1
    
    # Iterate over each dataset in the pool.
    local datasets=$(zfs list -H -o name -r "$pool")
    for dataset in $datasets; do
        log "Cleaning up snapshots for dataset: $dataset"
        local snapshots=( $(zfs list -t snapshot -o name -s creation | grep "^${dataset}@${SNAPSHOTPREFIX}" | head -n -$MAX_SNAPSHOTS) )
        
        for snapshot in "${snapshots[@]}"; do
            log "Removing old snapshot: $snapshot"
            zfs destroy "$snapshot"
        done
    done
}

# Ensure that script is called with required arguments.
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 MAX_SNAPSHOTS DEST_POOL SOURCE_POOL1 [SOURCE_POOL2 ... SOURCE_POOLn]"
    exit 1
fi

# Parse command-line arguments.
if [[ "$1" =~ ^[0-9]+$ ]]; then
    MAX_SNAPSHOTS=$1
    shift
else
    MAX_SNAPSHOTS=$DEFAULT_MAX_SNAPSHOTS
fi

DEST_POOL=$1
SNAPSHOTPREFIX="backup_${DEST_POOL}_"
shift
SOURCE_POOLS=("$@")

# Iterate over all source pools.
log "### Starting new backup-job ###"
# Check if pools are existent
log "Check if all pools are available"
all_pools=("${SOURCE_POOLS[@]}" "$DEST_POOL")
for pool in "${all_pools[@]}"; do
  if ! check_pool_exists "$pool"; then
    errorlog "ZFS-Pool '$pool' does not exist!"
    exit 1
  else
    log "ZFS-Pool '$pool' found."
  fi
done

for pool in "${SOURCE_POOLS[@]}"; do
    log "Starting backup for pool: $pool"

    # Create a new snapshot for the entire pool with recursion.
    snapshot_name="$pool@${SNAPSHOTPREFIX}$TIMESTAMP"
    log "Creating snapshot: $snapshot_name"
    zfs snapshot -r "$snapshot_name"

    # Define destination dataset.
    dest_dataset="$DEST_POOL/$pool"

    # Check if the destination dataset exists.
    if ! zfs list "$dest_dataset" > /dev/null 2>&1; then
        log "Destination dataset $dest_dataset does not exist. Creating it."
        zfs create -o mountpoint=none -p "$dest_dataset"
    fi

    # Get the most recent previous snapshot from the destination pool.
    prev_snapshot=$(zfs list -t snapshot -o name -s creation | grep "^${DEST_POOL}/${pool}@${SNAPSHOTPREFIX}" | tail -n 1)

    if [ -n "$prev_snapshot" ]; then
        # Check if the previous snapshot exists on the source pool.
        source_snapshot="${pool}@${prev_snapshot##*@}"
        if zfs list -t snapshot -o name | grep -q "^$source_snapshot$"; then
            log "Performing incremental send from $source_snapshot to $snapshot_name"
            zfs send -R -i "$source_snapshot" "$snapshot_name" | zfs receive -F "$DEST_POOL/${pool}"
        else
            errorlog "Error: Previous snapshot $source_snapshot not found on source pool $pool. Aborting backup for this pool."
            continue
        fi
    else
        log "No previous snapshot found. Performing full send for $snapshot_name"
        zfs send -R "$snapshot_name" | zfs receive -F "$DEST_POOL/${pool}"
    fi

    # Cleanup old snapshots.
    cleanup_snapshots "$pool"

done

log "### Backup process completed. ###"
