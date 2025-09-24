#!/bin/sh

chosen=$(printf "⏻ Wyłącz komputer\n💤 Uśpij\n👤 Przełącz użytkownika\n🔓 Wyloguj" | wofi --show=dmenu --prompt="Wybierz:")

case "$chosen" in
    "⏻ Wyłącz komputer")
        systemctl poweroff
        ;;
    "💤 Uśpij")
        systemctl suspend
        ;;
    "👤 Przełącz użytkownika")
        gdmflexiserver --switch-to-greeter
        ;;
    "🔓 Wyloguj")
        loginctl terminate-user "$USER"
        ;;
esac

