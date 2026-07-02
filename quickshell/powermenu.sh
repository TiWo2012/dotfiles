#!/bin/bash
selected=$(printf "  Shutdown\n  Sleep\n  Hibernate\n  Restart\n󰅶  Toggle Sleep" | walker --dmenu)
case "$selected" in
    "  Shutdown") systemctl poweroff ;;
    "  Sleep") systemctl suspend ;;
    "  Hibernate") systemctl hibernate ;;
    "  Restart") systemctl reboot ;;
    "󰅶  Toggle Sleep")
        if systemctl is-enabled sleep.target 2>/dev/null | grep -q masked; then
            sudo systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
        else
            sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
        fi
        ;;
esac
