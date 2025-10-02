#!/usr/bin/env bash

# Wofi drun mode, but filter to only these apps
apps=("Gemini" "ChatGPT")

# Build menu entries from desktop files
declare -A desktop_files
declare -A app_names
declare -A app_icons

for app in "${apps[@]}"; do
    # Find all .desktop files matching the app name
    while IFS= read -r desktop; do
        [ -z "$desktop" ] && continue
        
        # Parse desktop file for Name, Icon, and Exec
        name=$(grep "^Name=" "$desktop" | head -n1 | cut -d'=' -f2-)
        icon=$(grep "^Icon=" "$desktop" | head -n1 | cut -d'=' -f2-)
        exec=$(grep "^Exec=" "$desktop" | head -n1 | cut -d'=' -f2-)
        
        # Skip if Exec is invalid (doesn't exist or is just a relative path)
        if [[ "$exec" =~ ^/ ]] && [ ! -x "$exec" ]; then
            continue
        fi
        
        # Only use exact name matches
        if [ "$name" = "$app" ]; then
            desktop_files["$name"]="$exec"
            app_names["$name"]="$name"
            app_icons["$name"]="$icon"
            break
        fi
    done < <(find ~/.local/share/applications /usr/share/applications \
        -name "*.desktop" -exec grep -l "Name=$app" {} + 2>/dev/null)
done

# Create menu with icons
menu=""
for name in "${!app_names[@]}"; do
    icon="${app_icons[$name]}"
    if [ -n "$icon" ]; then
        menu+="img:${icon}:text:${name}\n"
    else
        menu+="${name}\n"
    fi
done

# Show menu and get selection
selected=$(echo -e "$menu" | wofi --dmenu --allow-images --parse-search)

# Extract the app name from selection (remove img: prefix if present)
if [[ "$selected" =~ img:.*:text:(.*) ]]; then
    selected="${BASH_REMATCH[1]}"
fi

# Launch the selected app
if [ -n "$selected" ] && [ -n "${desktop_files[$selected]}" ]; then
    # Remove field codes like %U, %F, etc. from Exec line
    exec_cmd="${desktop_files[$selected]}"
    exec_cmd=$(echo "$exec_cmd" | sed 's/%[a-zA-Z]//g')
    eval "$exec_cmd" &
fi

