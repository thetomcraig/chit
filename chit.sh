#!/usr/bin/env bash

# Paths and metadata used later on
INSTALL_DIR=$(brew info chit | head -4 | tail -n 1 | awk '{ print $1 }')
VERSION=$(brew info --json chit | grep "\"version\":" | awk '{ print $2 }' | tr -d \" | tr -d ,)
CONFIG_DIR="${HOME}/.config/chit"
CONFIG_THEME_DIR="${CONFIG_DIR}/theme_definitions"
SHARE_DIR="${INSTALL_DIR}/share"
TMUX_LINES_PATH="${CONFIG_DIR}/tmux_lines.conf"

# This is the file kitty will source to apply colors
# Chit will cp other files to this path when changing themes
# Must have the follwing line in your kitty.conf:
#  include ./theme.conf
KITTY_THEME_CONF_PATH="${HOME}/.config/kitty/theme.conf"


getSavedSetting() {
  setting_file_name="${1}"

  saved_setting=""

  setting_file="${setting_file_name}"
  # If setting file is present, read the first line
  if [ -f "${setting_file}" ]; then
    saved_setting=$(sed -n 1p "${setting_file}")
  fi

  echo "${saved_setting}"
}

setSavedSetting() {
  setting_file_name="${1}"
  setting_value="${2}"

  echo "${setting_value}" > "${setting_file_name}"
}


getTerminalEmulator() {
  # Name of the current terminal emulator application
  terminal_emulator=$(osascript -e 'tell application "System Events"' \
                                -e 'set frontApp to name of first application process whose frontmost is true' \
                                -e 'end tell')
  echo "${terminal_emulator}"
}

kittyThemeIsApplied() {
  # Check the colors being used in the kitty session
  # If they do not match the theme set by chit, reurn false
  # Used to manually set kitty colors on shell start
  desired_theme_path=$1

  theme_colors=(
  background
  foreground
  color0
  # Other colors could be checked, but takes too much time
  )

  for color in "${theme_colors[@]}"; do
    desired_theme_color=$(eval grep -w "${color}" "${desired_theme_path}" | sed 's/ //g' | tr '[:upper:]' '[:lower:]')
    current_theme_color=$(eval kitty @ get-colors | grep -w "${color}" | sed 's/ //g'| tr '[:upper:]' '[:lower:]')
    if [[ "${desired_theme_color}" != "${current_theme_color}" ]]; then
      return 1 # False
    fi
  done

 return 0 # True
}


getiTermEscapeSequence() {
  # iTerm lets you dynamically change the sessions color preset,
  # by echoing an escape sequence
  # Construct the line that needs to run to do that, then echo it
  # This allow us to pass the line around and execute it where necessary
  scheme=$(getThemeVariable "${1}" "CHIT_ITERM_SCHEME")
  echo "echo -e \"\\033]1337;SetColors=preset=${scheme}\\a\""
}

setiTermTheme() {
  full_path_to_theme_conf=${1}

  scheme=$(getThemeVariable "${full_path_to_theme_conf}" "CHIT_ITERM_SCHEME")
  if [ -n "$TMUX" ]; then
    # If inside tmux, need to use the applescript to
    # Set all the colors
    osascript "${SHARE_DIR}/iterm/change_iterm_session.scpt" "${scheme}"
  else
    # Otherwise, we can use the iTerm escape sequence
    sequence=$(getiTermEscapeSequence "${full_path_to_theme_conf}")
    eval "${sequence}"
  fi
}

setTerminalTheme() {
  # Set the colors of the current Terminal Emulator
  full_path_to_theme_conf="${1}"

  emulator=$(getTerminalEmulator)
  case $emulator in
    iTerm2)
      setiTermTheme "${full_path_to_theme_conf}"
    ;;
    kitty)
      setKittyTheme "${full_path_to_theme_conf}"
    ;;
  esac
}

setKittyTheme() {
# For kitty, the kitty.conf file sources a file called "theme.conf"
# This checks if the theme file is present, and if it has been applied.
# If not, the new theme conf file is copied to "theme.conf" to kitty to use at next load
# Also, the correct colors are then set for the current session
kitty_conf=$(getThemeVariable "${1}" "CHIT_KITTY_THEME_CONF_FILE_PATH")
if [ "${kitty_conf}" ]; then
  # The string is not empty
  eval ls ${kitty_conf} > /dev/null 2>&1
  if [[ $? == 0 ]]; then
    # There is a file with this path on disk
    if ! $(kittyThemeIsApplied "${kitty_conf}"); then
      # The colors from that file are not set for kitty currently
      # So...
      # Copy this theme file to the one sourced in kitty
      # This means it will be set properly by kitty on next start
      eval cp "${kitty_conf}" "${KITTY_THEME_CONF_PATH}"
      # Then, manually set the colors to the correct ones
      eval kitty @ set-colors "${kitty_conf}"
    fi
  fi
fi
}

exitIfFileDoesNotExist() {
  # Given the name of a theme, construct the string for it's full path on disk
  # If no file exists at that location, throw an error and exit
  full_path_string="${CONFIG_DIR}/theme_definitions/${1}.conf"
  if ! [[ -f "${full_path_string}" ]]; then
    >&2 echo "There is no chit theme with the name: '${theme_name}'"
    exit 1
  fi
}

getFullPathToThemeFile() {
  echo "${CONFIG_DIR}/theme_definitions/${1}.conf"
}

getThemeVariable() {
  # Given a variable, read the .conf file for the current theme
  # Return the value for the variable passed in
  full_path_to_theme_conf="${1}"
  variable_desired="${2}"

  value=""

  while read line
  do
      if echo $line | grep -F = &>/dev/null
      then
          if [ "${variable_desired}" = $(echo "$line" | cut -d '=' -f 1) ]
          then
              value=$(echo "$line" | cut -d '=' -f 2-)
          fi
      fi
  done < "${full_path_to_theme_conf}"

  echo "${value}"
}

exportEnvVars() {
  theme_name=$(getSavedSetting ${CONFIG_DIR}/current_theme)
  exitIfFileDoesNotExist "${theme_name}"
  full_path_to_theme_conf=$(getFullPathToThemeFile "${theme_name}")
  bat_theme=$(getThemeVariable $full_path_to_theme_conf "BAT_THEME")
  echo "export BAT_THEME=${bat_theme}"
}


setup() {
  # First time setup
  # If chit is invoked and the setup has not been run,
  # We will set up manually
  mkdir -p "${CONFIG_DIR}"
  touch "${CONFIG_DIR}"/current_theme
  setSavedSetting "${CONFIG_DIR}"/current_theme "dark"

  mkdir -p "${CONFIG_THEME_DIR}"
  cp ${SHARE_DIR}/example_theme_definitions/* ${CONFIG_THEME_DIR}

  # TODO fix this up
  # local kitty_theme_folder="${CONFIG_DIR}"/kitty_themes
  # mkdir -p "${kitty_theme_folder}"
  # cp -r ./kitty_themes/* "${kitty_theme_folder}"

  # TMUX
  # touch ${CONFIG_DIR}/tmux_theme.conf
  # setSavedSetting "${CONFIG_DIR}"/tmux_theme.conf ""
}

shellInit() {
  # To be run on shell start (.bash_profile .zshrc etc.)
  # With the line: eval "$(chit shell-init)"

  # Because this function is called every time the shell starts,
  # We need to have chit setup, and if there is an issue, fail loud and early
  if [ ! -d "${CONFIG_DIR}" ] || [ ! -f "${CONFIG_DIR}/current_theme" ]; then
      echo "echo chit running first-time setup"
      setup
  fi 

  theme_name=$(getSavedSetting ${CONFIG_DIR}/current_theme)
  if [ -z "$theme_name" ]; then
    echo "echo chit error: No current theme set!"
    exit 1
  fi

  exitIfFileDoesNotExist "${theme_name}"

  full_path_to_theme_conf=$(getFullPathToThemeFile "${theme_name}")

  exportEnvVars

  getiTermEscapeSequence ${full_path_to_theme_conf}
}


listThemes() {
  # List all the themes
  # Each defined in a .conf file

  # The one-time setup process copies example theme files to the .conf dir,
  # If that hasn't run yet, do it now
  if [ ! -d "${CONFIG_DIR}" ]; then
    setup
  fi

  theme_definitions=($(ls ${CONFIG_DIR}/theme_definitions/*.conf 2> /dev/null))
  for i in "${theme_definitions[@]}"
  do
    echo $(basename "${i}" | sed "s/.conf//g")
  done
}

writeTmuxLinesToFile() {
  IFS_ORG=IFS
  IFS=';' read -r -a tmux_lines <<< "$(getThemeVariable ${1} CHIT_TMUX_LINES)"
  if [[ -f "${TMUX_LINES_PATH}" ]]; then
    rm "${TMUX_LINES_PATH}"
  fi
  touch "${TMUX_LINES_PATH}"
  for line in "${tmux_lines[@]}"; do
    # To keep the syntax of the conf file reasonable,
    # single quotes should be around this line
    # So remove them
    # TODO: should probably replace this with something like TOML for conf files
    # echo "${line:1:-1}" >> "${TMUX_LINES_PATH}"
    echo "inside tmux"
  done
  IFS=IFS_ORG
}

setTheme() {
  theme_name="${1}"

  exitIfFileDoesNotExist "${theme_name}"
  full_path_to_theme_conf=$(getFullPathToThemeFile "${theme_name}")
  # Not calling exportEnvVars here,
  # because it would not affect the parent shell process
  setTerminalTheme "${full_path_to_theme_conf}"
  setSavedSetting "${CONFIG_DIR}"/current_theme "${theme_name}"
  # writeTmuxLinesToFile "${full_path_to_theme_conf}"
  echo "Theme set to: ${theme_name}"
}


helpStringFunction() {
  echo "chit usage:"
  echo "  h|help:
      Show this help message"
  echo "  u|setup:
      Setup the necessary files in ~/.config"
  echo "  i|shell-init:
      Function to be called on shell init (.zshrc, .bash_profile, etc.)"
  echo "  e|export-env-vars:
      Export variables set by the current theme.
      To be called with an 'eval' command."
  echo "  l|list:
      List available themes."
  echo "  s|set-theme theme_name:
      Set the current theme to theme_name."
  echo "  c|get-current-theme:
      Show the name of the current theme."
  echo "  v|version:
      Show the version of chit installed."
  echo "  g|get-theme-variable variable_name [theme_name]:
      Show value of variable_name in theme_name.
      If theme_name not supplied, use the current theme."
}

# Handle input to this script
case $1 in
  u|setup)
    setup
  ;;
  i|shell-init)
    shellInit
  ;;
  e|edit)
    $EDITOR "${CONFIG_THEME_DIR}/${2}.conf"
  ;;
  x|export-env-vars)
    exportEnvVars
  ;;
  l|list)
    listThemes
  ;;
  s|set-theme)
    setTheme $2
  ;;
  c|get-current-theme)
    getSavedSetting ${CONFIG_DIR}/current_theme
  ;;
  g|get-theme-variable)
    theme=$(getSavedSetting ${CONFIG_DIR}/current_theme)
    if [ $# -eq 3 ]; then
      theme="${3}"
    fi
    full_path_to_theme_conf=$(getFullPathToThemeFile "${theme}")
    getThemeVariable $full_path_to_theme_conf $2
  ;;
  v|version)
    echo ${VERSION}
  ;;
  h*|help)
    helpStringFunction
  ;;
  *)
    helpStringFunction
  ;;
esac
