# Create the script
cat > ~/.config/quickshell/dms/matugen-trigger.sh << 'EOF'
#!/bin/bash

# Matugen Wallpaper Theme Script for DankMaterialShell
# This script is triggered by the WallpaperWatcherDaemon plugin

WALLPAPER="$1"
LOG_FILE="$HOME/.local/share/DankMaterialShell/matugen.log"

# Create log directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Check if wallpaper path is provided
if [ -z "$WALLPAPER" ]; then
    log "ERROR: No wallpaper path provided"
    exit 1
fi

# Check if wallpaper file exists
if [ ! -f "$WALLPAPER" ]; then
    log "ERROR: Wallpaper file not found: $WALLPAPER"
    exit 1
fi

# Check if matugen is installed
if ! command -v matugen &> /dev/null; then
    log "ERROR: matugen is not installed"
    exit 1
fi

log "Processing wallpaper: $WALLPAPER"

# Run matugen with dark mode and scheme-content modifiers
if matugen image "$WALLPAPER" --mode dark --type scheme-content 2>&1 | tee -a "$LOG_FILE"; then
    log "SUCCESS: Theme updated with matugen"
    exit 0
else
    log "ERROR: matugen failed to update theme"
    exit 1
fi
EOF

# Make it executable
chmod +x ~/.config/quickshell/dms/matugen-trigger.sh
