export HISTFILE="$HOME/.zsh_history"
export HISTSIZE=500000
export SAVEHIST=500000
export PROJECTS_DIR="${PROJECTS_DIR:-$HOME/projects}"

setopt AUTO_CD

setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_SAVE_NO_DUPS
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY
setopt EXTENDED_HISTORY

case "$(uname -s)" in
  Darwin)
    export MY_PLATFORM="macos"
    ;;
  Linux)
    if grep -qi microsoft /proc/version 2>/dev/null; then
      export MY_PLATFORM="wsl"
    else
      export MY_PLATFORM="linux"
    fi
    ;;
  *)
    export MY_PLATFORM="unknown"
    ;;
esac

dot_prepend_path() {
  local dir="$1"
  [[ -d "$dir" ]] || return 0
  case ":$PATH:" in
    *":$dir:"*) ;;
    *) export PATH="$dir:$PATH" ;;
  esac
}

dot_prepend_path "$HOME/.local/bin"

dot_repo_dir() {
  local name="$1"
  local candidate
  for candidate in "$PROJECTS_DIR/$name" "$HOME/$name"; do
    if [[ -d "$candidate" ]]; then
      print -r -- "$candidate"
      return 0
    fi
  done
  return 1
}

dot_open_url() {
  local url="$1"
  if command -v open >/dev/null 2>&1; then
    open "$url" >/dev/null 2>&1 &
  elif command -v wslview >/dev/null 2>&1; then
    wslview "$url" >/dev/null 2>&1 &
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$url" >/dev/null 2>&1 &
  elif command -v cmd.exe >/dev/null 2>&1; then
    cmd.exe /C start "" "$url" >/dev/null 2>&1 || true
  else
    echo "No URL opener found for: $url"
    return 127
  fi
}

dot_primary_ip() {
  local ip
  ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  if [[ -n "$ip" ]]; then
    print -r -- "$ip"
  else
    print -r -- "127.0.0.1"
  fi
}

autoload -Uz compinit
compinit

_git_branch() {
  git rev-parse --abbrev-ref HEAD 2>/dev/null
}

set_prompt() {
  local branch
  branch="$(_git_branch)"
  if [[ -n "$branch" ]]; then
    PROMPT="%F{cyan}%~%f %F{yellow}(${branch})%f %# "
  else
    PROMPT="%F{cyan}%~%f %# "
  fi
}

typeset -ga precmd_functions
if (( ${precmd_functions[(I)set_prompt]} == 0 )); then
  precmd_functions+=(set_prompt)
fi
set_prompt

autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey -e
bindkey "^[[A" up-line-or-beginning-search
bindkey "^[[B" down-line-or-beginning-search
bindkey "^[OA" up-line-or-beginning-search
bindkey "^[OB" down-line-or-beginning-search
bindkey "^P" up-line-or-beginning-search
bindkey "^N" down-line-or-beginning-search
