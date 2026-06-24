#!/bin/bash

# Rofi Power Menu using your custom Monokai theme
THEME_PATH="$HOME/.config/awesome/rofi/Monokai.rasi"

option_shutdown="⏻ Shutdown"
option_reboot="⟳ Reboot"
option_lock=" Lock"
option_logout=" Logout"
option_suspend=" Suspend"

# Pass options to rofi with your custom theme
selected_option=$(echo -e "$option_shutdown\n$option_reboot\n$option_lock\n$option_logout\n$option_suspend" | rofi -dmenu -i -p "Power" -theme "$THEME_PATH")

# Perform action
case "$selected_option" in
    "$option_shutdown")
        systemctl poweroff
        ;;
    "$option_reboot")
        systemctl reboot
        ;;
    "$option_lock")
        slock || loginctl lock-session
        ;;
    "$option_logout")
        awesome-client 'awesome.quit()'
        ;;
    "$option_suspend")
        systemctl suspend
        ;;
esac
