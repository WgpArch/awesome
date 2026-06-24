#!/bin/bash

# Create screenshot directory if it doesn't exist
mkdir -p /home/wgparch/Pictures/Screenshots/awesome

# Get timestamp
TIMESTAMP=$(date +%Y-%m-%d_%H:%M:%S)

# Take screenshot
scrot /home/wgparch/Pictures/Screenshots/awesome/screenshot_$TIMESTAMP.png

# Show notification
notify-send "Screenshot saved!" "Saved to ~/Pictures/Screenshots/awesome/"
