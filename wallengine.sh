#!/bin/bash

# Set some variables
wall_dir="${HOME}/Pictures/Walls/"
cache_dir="${HOME}/.cache/wallpaper_thumbs"
rofi_config_path="${HOME}/.config/rofi/themes/rofi-wallpaper-sel.rasi "
rofi_command="rofi -dmenu -config ${rofi_config_path} -theme-str ${rofi_override}"

# Start swww if not running
pgrep -x swww-daemon >/dev/null || swww init

# Create cache dir if not exists
if [ ! -d "${cache_dir}" ] ; then
        mkdir -p "${cache_dir}"
fi

# Convert images in directory and save to cache dir
for imagen in "$wall_dir"/*.{jpg,jpeg,png,webp}; do
	if [ -f "$imagen" ]; then
		filename=$(basename "$imagen")
			if [ ! -f "${cache_dir}/${filename}" ] ; then
				convert -strip "$imagen" -thumbnail 500x500^ -gravity center -extent 500x500 "${cache_dir}/${filename}"
			fi
    fi
done

# Select a picture with rofi
wall_selection=$(ls "${wall_dir}" -t | while read -r A ; do  echo -en "$A\x00icon\x1f""${cache_dir}"/"$A\n" ; done | $rofi_command)

# Set the wallpaper with waypaper
[[ -n "$wall_selection" ]] || exit 1
waypaper --wallpaper ${wall_dir}${wall_selection}

# Reload Rofi theme with new colors
if [ -f "$HOME/.cache/wal/colors-rofi-dark.rasi" ]; then
    cp "$HOME/.cache/wal/colors-rofi-dark.rasi" "$HOME/.config/rofi/colors.rasi"
fi

# Reload Walcord
walcord -i ${wall_dir}${wall_selection}

# Reload waybar (Hyprland / sway users)
pkill -SIGUSR2 waybar 2>/dev/null

