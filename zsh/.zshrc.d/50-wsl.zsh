[[ "$MY_PLATFORM" == "wsl" ]] || return 0

# WSL-specific overrides belong here. Keep this file tracked for settings that
# should apply on every WSL machine, and keep one-off machine tweaks in
# ~/.zshrc.local instead.

# Distinctive prompt so it's obvious you're in WSL, not on the Mac.
set_prompt() {
  local branch
  branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
  if [[ -n "$branch" ]]; then
    PROMPT="%F{red}[WSL]%f %F{cyan}%~%f %F{yellow}(${branch})%f %# "
  else
    PROMPT="%F{red}[WSL]%f %F{cyan}%~%f %# "
  fi
}
