#!/bin/bash

# Gaming Mode - Toggle DP-1 monitor position by 100 pixels
# This script moves the DP-1 monitor right/left each time it's triggered

STATE_FILE="/tmp/gaming_mode_state"

# Read current state (0 = normal, 1 = shifted)
if [ -f "$STATE_FILE" ]; then
    STATE=$(cat "$STATE_FILE")
else
    STATE=0
fi

# Get current monitor configurations
DP1_INFO=$(hyprctl monitors -j | jq -r '.[] | select(.name=="DP-1")')
DP1_WIDTH=$(echo "$DP1_INFO" | jq -r '.width')
DP1_HEIGHT=$(echo "$DP1_INFO" | jq -r '.height')
DP1_REFRESH=$(echo "$DP1_INFO" | jq -r '.refreshRate')
DP1_X=$(echo "$DP1_INFO" | jq -r '.x')
DP1_Y=$(echo "$DP1_INFO" | jq -r '.y')
DP1_SCALE=$(echo "$DP1_INFO" | jq -r '.scale')

# Toggle state and calculate new position
if [ "$STATE" -eq 0 ]; then
    # Shift right by 100
    NEW_X=$((DP1_X + 100))
    NEW_STATE=1
    MESSAGE="DP-1 shifted +100px right"
else
    # Shift back left by 100
    NEW_X=$((DP1_X - 100))
    NEW_STATE=0
    MESSAGE="DP-1 restored to original position"
fi

# Apply new monitor position
hyprctl keyword monitor "DP-1,${DP1_WIDTH}x${DP1_HEIGHT}@${DP1_REFRESH},${NEW_X}x${DP1_Y},${DP1_SCALE}"

# Save new state
echo "$NEW_STATE" > "$STATE_FILE"

# Notification (optional - requires dunst or similar)
notify-send "Gaming Mode" "$MESSAGE"
