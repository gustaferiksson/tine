# tine — zsh integration (no pty)
#
# Feeds the edit buffer to the tine app and drives the suggestion panel: arrow
# keys move the selection, Tab accepts. No pseudo-terminal wrapper — nothing can
# leak the way figterm/kiro-cli-term did.
#
# Enable from ~/.zshrc:  source /path/to/tine.zsh

# Fixed default so the app + input method (which don't see this env) agree.
: ${TINE_SOCK:="$HOME/.local/share/tine/tine.sock"}
export TINE_SOCK

_TINE_US=$'\x1f'
_TINE_ACTIVE=0
_TINE_REPLY=""

# Request/response with the app. Sends "<type><US><cursor><US><cwd><US><buffer>"
# and stores the reply line in _TINE_REPLY. Best-effort; never blocks the prompt.
_tine_req() {
  local type=$1
  [[ -n "$TINE_SOCK" ]] || return 1
  zmodload zsh/net/socket 2>/dev/null || return 1
  local fd
  zsocket "$TINE_SOCK" 2>/dev/null || return 1
  fd=$REPLY
  print -u "$fd" -r -- "${type}${_TINE_US}${CURSOR}${_TINE_US}${PWD}${_TINE_US}${BUFFER}"
  _TINE_REPLY=""
  IFS= read -r -u "$fd" _TINE_REPLY
  exec {fd}>&-
  return 0
}

# Fires on every buffer/cursor change: refresh suggestions, track whether the
# panel is showing (reply = suggestion count).
_tine_feed() { _tine_req update && _TINE_ACTIVE=${_TINE_REPLY:-0}; }
zle -N _tine_feed

# Hide the panel when the line is submitted/abandoned.
_tine_hide() { _tine_req dismiss; _TINE_ACTIVE=0; }
zle -N _tine_hide

# Arrow keys: move the selection while the panel is up, else normal history.
_tine_up()   { if [[ ${_TINE_ACTIVE:-0} -gt 0 ]]; then _tine_req up;   else zle up-line-or-history;   fi; }
_tine_down() { if [[ ${_TINE_ACTIVE:-0} -gt 0 ]]; then _tine_req down; else zle down-line-or-history; fi; }
zle -N _tine_up
zle -N _tine_down

# Accept the selected suggestion (reply = "<newCursor><US><newBuffer>").
# Returns 0 if accepted, 1 if the panel wasn't active.
_tine_do_accept() {
  [[ ${_TINE_ACTIVE:-0} -gt 0 ]] || return 1
  _tine_req accept || return 1
  [[ -n "$_TINE_REPLY" ]] || return 1
  _TINE_ACTIVE=0
  # Fig's auto-execute row: run the line as-is instead of inserting text.
  if [[ "$_TINE_REPLY" == "EXEC" ]]; then
    zle accept-line
    return 0
  fi
  BUFFER=${_TINE_REPLY#*${_TINE_US}}     # set buffer first
  CURSOR=${_TINE_REPLY%%${_TINE_US}*}    # then cursor within it
  zle redisplay
  return 0
}

# Insert the common prefix of the visible suggestions (keeps panel open).
_tine_do_prefix() {
  [[ ${_TINE_ACTIVE:-0} -gt 0 ]] || return 1
  _tine_req prefix || return 1
  [[ -n "$_TINE_REPLY" ]] || return 1
  BUFFER=${_TINE_REPLY#*${_TINE_US}}
  CURSOR=${_TINE_REPLY%%${_TINE_US}*}
  zle redisplay
  return 0
}

# Fig-exact keys:
#   Tab   -> insert common prefix (else normal completion)
#   Enter -> accept selected (else run the line)
#   Esc   -> dismiss the panel (else no-op)
# Tab: while the panel is up, insert the common prefix and consume the key
# (never fall through to zsh/oh-my-zsh completion). Only when the panel is down
# does Tab run normal shell completion.
_tine_tab() {
  if [[ ${_TINE_ACTIVE:-0} -gt 0 ]]; then
    _tine_do_prefix || zle redisplay
  else
    zle expand-or-complete
  fi
}
_tine_enter() { _tine_do_accept || zle accept-line; }
_tine_esc()   { if [[ ${_TINE_ACTIVE:-0} -gt 0 ]]; then _tine_req dismiss; _TINE_ACTIVE=0; zle redisplay; fi; }
# Ctrl+K: toggle the detail pane while the panel is up (else normal kill-line).
_tine_detail() { if [[ ${_TINE_ACTIVE:-0} -gt 0 ]]; then _tine_req toggleDetail; else zle kill-line; fi; }
zle -N _tine_tab
zle -N _tine_enter
zle -N _tine_esc
zle -N _tine_detail

# Send the shell's aliases to the app so the parser can expand them (pc -> plug-cli).
# Once per prompt: cheap, and survives an app restart.
_tine_send_aliases() {
  [[ -n "$TINE_SOCK" ]] || return
  zmodload zsh/net/socket 2>/dev/null || return
  local fd reply dump
  dump="$(alias | tr '\n' "$_TINE_US")"
  zsocket "$TINE_SOCK" 2>/dev/null || return
  fd=$REPLY
  print -u "$fd" -r -- "aliases${_TINE_US}0${_TINE_US}${PWD}${_TINE_US}${dump}"
  IFS= read -r -u "$fd" reply
  exec {fd}>&-
}
autoload -Uz add-zsh-hook 2>/dev/null
(( $+functions[add-zsh-hook] )) && add-zsh-hook precmd _tine_send_aliases

autoload -Uz add-zle-hook-widget 2>/dev/null
if (( $+functions[add-zle-hook-widget] )); then
  add-zle-hook-widget line-pre-redraw _tine_feed
  add-zle-hook-widget line-finish _tine_hide

  bindkey '^[[A' _tine_up;   bindkey '^[OA' _tine_up
  bindkey '^[[B' _tine_down; bindkey '^[OB' _tine_down
  bindkey '^[[Z' _tine_up    # shift+tab -> navigate up (Fig)
  bindkey '^I'   _tine_tab
  bindkey '^M'   _tine_enter
  bindkey '^['   _tine_esc
  bindkey '^K'   _tine_detail
fi
