#!/bin/bash

# Skrypt do kontroli Bluetooth przez wofi i wyświetlania statusu w Waybar.
# Wersja 3.0: Poprawiona logika połączeń, dodana opcja "Zapomnij".
#
# Zależności: bluez-utils (bluetoothctl), wofi, libnotify (notify-send)

# --- Tłumaczenia (PL) ---
TOOLTIP_CONNECTED="Połączono z:"
TOOLTIP_ON="Bluetooth włączony"
TOOLTIP_OFF="Bluetooth wyłączony"
TOOLTIP_SERVICE_OFF="Usługa Bluetooth jest wyłączona"

MENU_PROMPT="Menu Bluetooth"
MENU_TURN_ON="Włącz Bluetooth"
MENU_TURN_OFF="Wyłącz Bluetooth"
MENU_CONNECT_TO="Połącz z"
MENU_DISCONNECT_FROM="Rozłącz z"
MENU_FORGET="Usuń (Zapomnij)" # Dodane nowe tłumaczenie

NOTIFY_TITLE="Bluetooth"
NOTIFY_ON="Włączono Bluetooth."
NOTIFY_OFF="Wyłączono Bluetooth."
NOTIFY_CONNECTING="Łączenie z"
NOTIFY_DISCONNECTING="Rozłączanie z"
NOTIFY_FORGETTING="Usuwanie urządzenia" # Dodane nowe tłumaczenie

# --- Logika Skryptu ---

# Funkcja do wyświetlania powiadomień
notify() {
    notify-send "$NOTIFY_TITLE" "$1"
}

# Sprawdź, czy usługa bluetooth jest aktywna
if ! systemctl is-active --quiet bluetooth.service; then
    echo '{"text": "", "alt": "off", "class": "off", "tooltip": "'"$TOOLTIP_SERVICE_OFF"'"}'
    exit 0
fi

# Sprawdź, czy kontroler bluetooth jest włączony
if ! bluetoothctl show | grep -q "Powered: yes"; then
    if [ "$1" == "menu" ]; then
        if echo "$MENU_TURN_ON" | wofi -d -i -p "$MENU_PROMPT" | grep -q "$MENU_TURN_ON"; then
            bluetoothctl power on && notify "$NOTIFY_ON"
        fi
    else
        echo '{"text": "", "alt": "off", "class": "off", "tooltip": "'"$TOOLTIP_OFF"'"}'
    fi
    exit 0
fi

# --- Główna logika (gdy Bluetooth jest WŁĄCZONY) ---

# --- Tryb Menu Wofi ---
if [ "$1" == "menu" ]; then
    # ZMIANA 1: Poprawiony i niezawodny sposób sprawdzania połączonego urządzenia
    connected_mac=$(bluetoothctl devices Connected | awk '{print $2}' | head -n 1)
    
    # ZMIANA 2: Przebudowa logiki menu, aby oferować więcej opcji
    menu_full="turn_off\t$MENU_TURN_OFF\n"
    mapfile -t paired_devices < <(bluetoothctl devices Paired | grep -E "([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}")

    for device in "${paired_devices[@]}"; do
        mac=$(echo "$device" | awk '{print $2}')
        name=$(echo "$device" | cut -d ' ' -f 3-)

        if [ "$mac" == "$connected_mac" ]; then
            # Opcje dla połączonego urządzenia
            menu_full+="disconnect $mac\t$MENU_DISCONNECT_FROM $name\n"
            menu_full+="remove $mac\t$MENU_FORGET $name\n"
        else
            # Opcje dla sparowanego, ale niepołączonego urządzenia
            menu_full+="connect $mac\t$MENU_CONNECT_TO $name\n"
            menu_full+="remove $mac\t$MENU_FORGET $name\n"
        fi
    done

    menu_display=$(echo -e "$menu_full" | cut -f2 -d$'\t')
    choice_display=$(echo -e "$menu_display" | wofi -d -i -p "$MENU_PROMPT")

    if [ -z "$choice_display" ]; then
        exit 0
    fi
    
    choice_full=$(echo -e "$menu_full" | grep -F "$choice_display")

    # ZMIANA 3: Nowy, prostszy sposób odczytywania akcji i MAC adresu
    command_part=$(echo "$choice_full" | cut -f1 -d$'\t')
    action=$(echo "$command_part" | awk '{print $1}')
    target_mac=$(echo "$command_part" | awk '{print $2}')
    target_name=$(echo "$choice_display" | cut -d' ' -f 3-)


    case "$action" in
        "turn_off")
            bluetoothctl power off && notify "$NOTIFY_OFF"
            ;;
        "connect")
            bluetoothctl connect "$target_mac" && notify "$NOTIFY_CONNECTING $target_name..."
            ;;
        "disconnect")
            bluetoothctl disconnect "$target_mac" && notify "$NOTIFY_DISCONNECTING $target_name..."
            ;;
        "remove")
            bluetoothctl remove "$target_mac" && notify "$NOTIFY_FORGETTING $target_name..."
            ;;
    esac
    sleep 1

# --- Tryb Wyświetlania w Waybar ---
else
    connected_device_info=$(bluetoothctl devices Connected | head -n 1)
    if [ -n "$connected_device_info" ]; then
        connected_name=$(echo "$connected_device_info" | cut -d ' ' -f 3-)
        echo '{"text": "'"$connected_name"'", "alt": "connected", "class": "connected", "tooltip": "'"$TOOLTIP_CONNECTED"' '"$connected_name"'"}'
    else
        echo '{"text": "", "alt": "on", "class": "on", "tooltip": "'"$TOOLTIP_ON"'"}'
    fi
fi
