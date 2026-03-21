alias gs="git status -sb"
alias ga="git add"
alias ..="cd .."
alias ...="cd ../.."
alias ff="ffmpeg_wrap.sh"

aa() {
  local repo
  repo="$(dot_repo_dir stable-diffusion-webui)" || {
    echo "Repo not found: stable-diffusion-webui"
    return 1
  }
  cd "$repo" || return 1
}

webui() {
  local repo
  repo="$(dot_repo_dir stable-diffusion-webui)" || {
    echo "Repo not found: stable-diffusion-webui"
    return 1
  }
  (cd "$repo" && bash webui.sh "$@")
}

alias a1111="webui"

if command -v eza >/dev/null 2>&1; then
  alias ls="eza --group-directories-first --icons --git"
  alias ll="eza -la --group-directories-first --icons --git"
  alias lt="eza --tree --level=2 --icons"
  alias la="eza -a --group-directories-first --icons --git"
else
  alias ll="ls -lah"
  alias la="ls -A"
fi
