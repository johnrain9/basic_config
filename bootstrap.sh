#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
timestamp="$(date +%Y%m%d-%H%M%S)"
backup_root="$HOME/.dotfiles-backups/$timestamp"
did_backup=0

link_item() {
  local source_path="$1"
  local target_path="$2"
  local backup_path

  mkdir -p "$(dirname "$target_path")"

  if [[ -L "$target_path" ]] && [[ "$(readlink "$target_path")" == "$source_path" ]]; then
    printf 'ok      %s\n' "$target_path"
    return 0
  fi

  if [[ -e "$target_path" || -L "$target_path" ]]; then
    backup_path="$backup_root${target_path#$HOME}"
    mkdir -p "$(dirname "$backup_path")"
    mv "$target_path" "$backup_path"
    did_backup=1
    printf 'backup  %s -> %s\n' "$target_path" "$backup_path"
  fi

  ln -s "$source_path" "$target_path"
  printf 'link    %s -> %s\n' "$target_path" "$source_path"
}

mkdir -p "$HOME/projects"
mkdir -p "$HOME/.local/bin"

link_item "$repo_root/zsh/.zshrc" "$HOME/.zshrc"
link_item "$repo_root/zsh/.zshrc.d" "$HOME/.zshrc.d"
link_item "$repo_root/git/.gitconfig" "$HOME/.gitconfig"
link_item "$repo_root/bin/.local/bin/ffmpeg_wrap.sh" "$HOME/.local/bin/ffmpeg_wrap.sh"

if [[ ! -e "$HOME/.zshrc.local" && ! -L "$HOME/.zshrc.local" ]]; then
  cp "$repo_root/zsh/.zshrc.local.example" "$HOME/.zshrc.local"
  printf 'create  %s\n' "$HOME/.zshrc.local"
fi

if [[ ! -e "$HOME/.gitconfig.local" && ! -L "$HOME/.gitconfig.local" ]]; then
  cp "$repo_root/git/.gitconfig.local.example" "$HOME/.gitconfig.local"
  printf 'create  %s\n' "$HOME/.gitconfig.local"
fi

if [[ "$did_backup" -eq 1 ]]; then
  printf 'backup-root %s\n' "$backup_root"
fi

printf 'done    bootstrap complete\n'
